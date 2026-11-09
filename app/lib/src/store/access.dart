import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../shelf/story_shelf.dart';

export '../brand.dart'
    show subscriptionProductId, iosSubscriptionProducts, iosTrialDays;

/// Compilación de prueba (`--dart-define=MININOCHES_DEV=true`): aparece el modo desarrollador, que abre todo sin pagar.
/// En la compilación de las tiendas no existe (nadie puede saltarse el pago).
const bool devBuild = bool.fromEnvironment('MININOCHES_DEV');

/// Los cuentos gratis si el servidor no dice otra cosa: uno por paquete y de edades distintas (docs/05).
const Set<String> defaultFreeStories = {
  'medieval:sombras',
  'mar:galletas_todos',
  'cosmos:chispa_perdida',
};

/// Días que se sigue respetando un derecho caducado sin poder preguntar al servidor (sin conexión).
const Duration offlineGrace = Duration(days: 3);

String storyRef(String packId, String premiseId) => '$packId:$premiseId';

/// Lo que el servidor dice que tiene esta instalación (docs/api/store.openapi.yaml).
class Entitlement {
  const Entitlement({
    required this.premium,
    required this.source,
    this.productId,
    this.expiresAt,
    this.trial = false,
    this.autoRenewing = false,
    this.issuedAt,
    this.signature = '',
  });

  factory Entitlement.fromJson(Map<String, Object?> j) => Entitlement(
        premium: j['premium'] == true,
        source: (j['source'] as String?) ?? 'none',
        productId: j['productId'] as String?,
        expiresAt: DateTime.tryParse((j['expiresAt'] as String?) ?? ''),
        trial: j['trial'] == true,
        autoRenewing: j['autoRenewing'] == true,
        issuedAt: DateTime.tryParse((j['issuedAt'] as String?) ?? ''),
        signature: (j['signature'] as String?) ?? '',
      );

  static const none = Entitlement(premium: false, source: 'none');

  final bool premium;

  /// `google`, `apple`, `code` o `none`.
  final String source;
  final String? productId;
  final DateTime? expiresAt;
  final bool trial;
  final bool autoRenewing;
  final DateTime? issuedAt;

  /// Firma Ed25519 del servidor (se guarda tal cual; ver docs/30).
  final String signature;

  bool activeAt(DateTime now) =>
      premium &&
      (expiresAt == null || expiresAt!.add(offlineGrace).isAfter(now));

  Map<String, Object?> toJson() => {
        'premium': premium,
        'source': source,
        if (productId != null) 'productId': productId,
        if (expiresAt != null)
          'expiresAt': expiresAt!.toUtc().toIso8601String(),
        'trial': trial,
        'autoRenewing': autoRenewing,
        if (issuedAt != null) 'issuedAt': issuedAt!.toUtc().toIso8601String(),
        'signature': signature,
      };
}

/// Qué devolvió el servidor al canjear o verificar.
enum StoreOutcome { ok, invalid, used, unavailable, noServer }

class StoreResult {
  const StoreResult(this.outcome, [this.entitlement]);
  final StoreOutcome outcome;
  final Entitlement? entitlement;
}

/// El servidor de la app (catálogo, compras y códigos).
abstract class StoreApi {
  Future<({String etag, Map<String, Object?> body})?> catalog(String? etag);
  Future<StoreResult> verify({
    required String installId,
    required String platform,
    required String productId,
    String? purchaseToken,
    String? transactionId,
  });
  Future<StoreResult> redeem(String installId, String code);
  Future<Entitlement?> entitlement(String installId);
}

class HttpStoreApi implements StoreApi {
  HttpStoreApi(this.base,
      {http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final String base;
  final http.Client _client;
  final Duration timeout;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$base$path').replace(queryParameters: q);

  static const _json = {'Content-Type': 'application/json'};

  @override
  Future<({String etag, Map<String, Object?> body})?> catalog(
      String? etag) async {
    try {
      final r = await _client.get(_u('/v1/catalog'), headers: {
        if (etag != null) 'If-None-Match': etag,
      }).timeout(timeout);
      if (r.statusCode != 200) return null;
      return (
        etag: r.headers['etag'] ?? '',
        body: jsonDecode(r.body) as Map<String, Object?>,
      );
    } catch (_) {
      return null;
    }
  }

  StoreResult _result(http.Response r) {
    if (r.statusCode == 200) {
      return StoreResult(StoreOutcome.ok,
          Entitlement.fromJson(jsonDecode(r.body) as Map<String, Object?>));
    }
    if (r.statusCode == 402 || r.statusCode == 404) {
      return const StoreResult(StoreOutcome.invalid);
    }
    if (r.statusCode == 409) return const StoreResult(StoreOutcome.used);
    return const StoreResult(StoreOutcome.unavailable);
  }

  @override
  Future<StoreResult> verify({
    required String installId,
    required String platform,
    required String productId,
    String? purchaseToken,
    String? transactionId,
  }) async {
    try {
      final r = await _client
          .post(_u('/v1/purchases/verify'),
              headers: _json,
              body: jsonEncode({
                'installId': installId,
                'platform': platform,
                'productId': productId,
                if (purchaseToken != null) 'purchaseToken': purchaseToken,
                if (transactionId != null) 'transactionId': transactionId,
              }))
          .timeout(timeout);
      return _result(r);
    } catch (_) {
      return const StoreResult(StoreOutcome.unavailable);
    }
  }

  @override
  Future<StoreResult> redeem(String installId, String code) async {
    try {
      final r = await _client
          .post(_u('/v1/redeem'),
              headers: _json,
              body: jsonEncode({'installId': installId, 'code': code}))
          .timeout(timeout);
      return _result(r);
    } catch (_) {
      return const StoreResult(StoreOutcome.unavailable);
    }
  }

  @override
  Future<Entitlement?> entitlement(String installId) async {
    try {
      final r = await _client
          .get(_u('/v1/entitlements', {'installId': installId}))
          .timeout(timeout);
      if (r.statusCode != 200) return null;
      return Entitlement.fromJson(jsonDecode(r.body) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }
}

/// UUID v4 aleatorio: identifica la instalación ante el servidor, sin ligarla a una persona ni a un dispositivo.
String newInstallId([Random? rnd]) {
  final r = rnd ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final s = [for (var i = 0; i < 16; i++) h(i)].join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

/// Quién puede leer qué: los cuentos gratis para todos; el resto con la suscripción (o un código, o el modo
/// desarrollador en las compilaciones de prueba). Guarda el derecho en el teléfono para funcionar sin conexión.
class AccessService extends ChangeNotifier {
  AccessService(
    this._store, {
    this.api,
    this.devAvailable = devBuild,
    DateTime Function()? clock,
  })  : _open = false,
        _now = clock ?? DateTime.now;

  /// Todo abierto (las pruebas que no tratan de compras y el arranque sin ajustes).
  AccessService.open()
      : _store = MemoryShelfStore(),
        api = null,
        devAvailable = false,
        _open = true,
        _now = DateTime.now;

  final ShelfStore _store;
  final StoreApi? api;

  /// Si existe el modo desarrollador (solo compilaciones de prueba).
  final bool devAvailable;
  final bool _open;
  final DateTime Function() _now;

  String _installId = '';
  Entitlement _entitlement = Entitlement.none;
  bool _devUnlock = false;
  Set<String> _free = {...defaultFreeStories};
  Set<String> _hidden = {};
  String? _etag;
  String? _catalogDay;
  bool _loaded = false;

  String get installId => _installId;
  Entitlement get entitlement => _entitlement;
  bool get devUnlock => _devUnlock;
  Set<String> get freeStories => Set.unmodifiable(_free);
  Set<String> get hiddenStories => Set.unmodifiable(_hidden);

  /// Tiene todo abierto (suscripción vigente, código, modo desarrollador o pruebas).
  bool get premium =>
      _open || (devAvailable && _devUnlock) || _entitlement.activeAt(_now());

  bool isFree(String packId, String premiseId) =>
      _free.contains(storyRef(packId, premiseId));

  bool isHidden(String packId, String premiseId) =>
      _hidden.contains(storyRef(packId, premiseId));

  bool canRead(String packId, String premiseId) =>
      premium || isFree(packId, premiseId);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, Object?>;
        _installId = (j['installId'] as String?) ?? '';
        final e = j['derecho'];
        if (e is Map<String, Object?>) _entitlement = Entitlement.fromJson(e);
        _devUnlock = j['desarrollador'] == true;
        final free = j['gratis'];
        if (free is List && free.isNotEmpty) _free = {...free.cast<String>()};
        final hidden = j['ocultos'];
        if (hidden is List) _hidden = {...hidden.cast<String>()};
        _etag = j['etag'] as String?;
        _catalogDay = j['dia_catalogo'] as String?;
      }
    } catch (_) {
      // Datos ilegibles: se empieza de cero (lo comprado se recupera con «Restaurar»).
    }
    if (_installId.isEmpty) {
      _installId = newInstallId();
      await _save();
    }
    notifyListeners();
  }

  /// Al abrir la app: catálogo (una vez al día) y derecho vigente. Nunca bloquea ni falla.
  Future<void> refresh({bool force = false}) async {
    final a = api;
    if (a == null) return;
    await load();
    final today = _now().toIso8601String().substring(0, 10);
    if (force || _catalogDay != today) {
      final c = await a.catalog(_etag);
      if (c != null) {
        final free = (c.body['freeStories'] as List?)?.cast<String>();
        final hidden = (c.body['hiddenStories'] as List?)?.cast<String>();
        if (free != null) _free = {...free};
        if (hidden != null) _hidden = {...hidden};
        _etag = c.etag.isEmpty ? null : c.etag;
      }
      _catalogDay = today;
    }
    if (_entitlement.source != 'none') {
      final e = await a.entitlement(_installId);
      if (e != null) _entitlement = e;
    }
    notifyListeners();
    await _save();
  }

  /// Le pide al servidor que verifique una compra de la tienda.
  Future<StoreResult> verifyPurchase({
    required String platform,
    required String productId,
    String? purchaseToken,
    String? transactionId,
  }) async {
    final a = api;
    if (a == null) return const StoreResult(StoreOutcome.noServer);
    await load();
    final r = await a.verify(
      installId: _installId,
      platform: platform,
      productId: productId,
      purchaseToken: purchaseToken,
      transactionId: transactionId,
    );
    if (r.outcome == StoreOutcome.ok && r.entitlement != null) {
      _entitlement = r.entitlement!;
      notifyListeners();
      await _save();
    }
    return r;
  }

  /// Canjea un código de regalo.
  Future<StoreResult> redeem(String code) async {
    final a = api;
    if (a == null) return const StoreResult(StoreOutcome.noServer);
    await load();
    final clean = code.trim().toUpperCase().replaceAll(' ', '');
    final r = await a.redeem(_installId, clean);
    if (r.outcome == StoreOutcome.ok && r.entitlement != null) {
      _entitlement = r.entitlement!;
      notifyListeners();
      await _save();
    }
    return r;
  }

  /// Modo desarrollador: todo abierto sin pagar (solo si la compilación lo permite).
  Future<void> setDevUnlock(bool on) async {
    if (!devAvailable) return;
    _devUnlock = on;
    notifyListeners();
    await _save();
  }

  /// Lo que se guarda, tal cual (para «Ver mis datos»).
  Map<String, Object?> exportJson() => {
        'installId': _installId,
        'derecho': _entitlement.toJson(),
        if (_devUnlock) 'desarrollador': true,
        'gratis': _free.toList()..sort(),
        'ocultos': _hidden.toList()..sort(),
        if (_etag != null) 'etag': _etag,
        if (_catalogDay != null) 'dia_catalogo': _catalogDay,
      };

  /// Borrar los datos del teléfono: se olvida el derecho y se crea otro identificador (lo pagado vuelve con «Restaurar»).
  Future<void> clearAll() async {
    _entitlement = Entitlement.none;
    _devUnlock = false;
    _free = {...defaultFreeStories};
    _hidden = {};
    _etag = null;
    _catalogDay = null;
    _installId = newInstallId();
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _store.write(jsonEncode(exportJson()));
}

class PrefsAccessStore implements ShelfStore {
  PrefsAccessStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'access.v1';

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String json) => _prefs.setString(_key, json);
}

/// Pone el acceso al alcance de cualquier pantalla.
class AccessScope extends InheritedNotifier<AccessService> {
  const AccessScope(
      {super.key, required AccessService access, required super.child})
      : super(notifier: access);

  static AccessService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccessScope>()?.notifier ??
      _fallback;

  static AccessService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccessScope>()?.notifier ??
      _fallback;

  static final AccessService _fallback = AccessService.open();
}
