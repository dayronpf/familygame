import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de intentar enviar un lote.
enum SendOutcome {
  /// El servidor lo recibió (o lo rechazó por inválido): se borra de la cola.
  done,

  /// Red caída, límite de tasa o fallo del servidor: se conserva y se reintenta más tarde.
  retryLater,
}

abstract class FeedbackTransport {
  Future<SendOutcome> send(List<Map<String, Object?>> events);
}

/// Dirección del servidor (`--dart-define=CALDERO_API=https://…`). Vacía = aún no hay backend:
/// las valoraciones se guardan en el teléfono y se enviarán cuando exista.
const String configuredApi = String.fromEnvironment('CALDERO_API');

/// Envía un lote por `POST /v1/feedback`. Solo el JSON de los eventos: sin cookies, sin
/// identificadores de dispositivo, sin cabeceras de usuario.
class HttpFeedbackTransport implements FeedbackTransport {
  HttpFeedbackTransport(this.endpoint,
      {http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final Uri endpoint;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<SendOutcome> send(List<Map<String, Object?>> events) async {
    try {
      final res = await _client
          .post(
            endpoint,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'events': events}),
          )
          .timeout(timeout);
      final code = res.statusCode;
      if (code >= 200 && code < 300) return SendOutcome.done;
      if (code == 429 || code >= 500) return SendOutcome.retryLater;
      return SendOutcome
          .done; // 4xx: el lote es inválido; reintentarlo no lo arreglaría
    } on TimeoutException {
      return SendOutcome.retryLater;
    } on http.ClientException {
      return SendOutcome.retryLater;
    }
  }
}
