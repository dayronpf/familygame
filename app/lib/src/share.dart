import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Dónde se descarga la app. Mientras no esté en las tiendas es el enlace del APK de prueba; cuando se
/// publique, se cambia aquí por el de la tienda.
const String appDownloadUrl =
    'https://github.com/dayronpf/familygame/releases/download/apk-latest/caldero-de-cuentos.apk';

const String shareMessage =
    '🌙 ¡Te recomiendo Caldero de Cuentos! Cuentos para dormir con dibujos animados, voz y una enseñanza, '
    'pensados para niños. Descárgala aquí: $appDownloadUrl';

/// Abre el menú de compartir del teléfono (WhatsApp, mensajes, correo…). Si no se puede, copia el mensaje.
Future<void> shareApp(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await SharePlus.instance.share(
      ShareParams(text: shareMessage, subject: 'Caldero de Cuentos'),
    );
  } catch (_) {
    await Clipboard.setData(const ClipboardData(text: shareMessage));
    messenger?.showSnackBar(
      const SnackBar(
          content:
              Text('Copiamos el mensaje: pégalo donde quieras compartirlo')),
    );
  }
}
