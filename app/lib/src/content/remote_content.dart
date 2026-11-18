import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../brand.dart';
import '../pack_loader.dart';

/// Contenido remoto (docs/34, paso B1): cuentos nuevos sin actualizar la app.
///
/// En el almacén (Cloudflare R2) vive, por idioma:
///
///     contenido/es/indice.json          ← lo único que la app pide cada día
///     contenido/es/paquetes/<id>.json   ← los paquetes (texto de los cuentos)
///     contenido/es/catalogo.json        ← el catálogo fijo
///     contenido/es/voz.json             ← el manifiesto de la voz grabada
///     voz/es/<huella>.m4a               ← el audio (lo baja CachedClipStore al abrir cada cuento)
///
/// `indice.json` (lo escribe `tools/content/publish.py`):
///
///     {"formato": 1, "version": 20261118153000, "motor": 1, "idioma": "es", "catalogo": "1.2",
///      "publicado": "2026-11-18T15:30:00Z",
///      "archivos": {"paquetes/medieval.json": {"sha256": "…", "bytes": 123}, "catalogo.json": {…}, "voz.json": {…}}}
///
/// - `version`: número que solo crece (la fecha y hora de la publicación). Se baja si es mayor que la guardada.
/// - `motor`: la versión de contenido que hace falta ([contentEngineVersion]). Si es mayor, no se baja nada.
/// - `catalogo`: la versión del catálogo publicado. Si es menor que la del catálogo que trae la app (una
///   actualización de la tienda ya trae algo más nuevo), no se baja y lo bajado antes deja de usarse.
///
/// Lo bajado se guarda en la carpeta de soporte de la app (`contenido/<idioma>/v<version>/…`) y `indice.json` local
/// se escribe al final, solo si todo bajó con su huella correcta y se pudo leer. Al arrancar, [RemoteContent.local]
/// comprueba otra vez las huellas: si algo no cuadra, la app usa lo que trae dentro, como siempre. Lo nuevo vale desde
/// el siguiente arranque (no se cambia «Explorar» mientras la familia lo mira).

/// Versión del formato de `indice.json` que entiende esta app.
const int contentIndexFormat = 1;

/// Rutas de los archivos que la app sabe usar (las demás del índice se ignoran). Sin `..` ni rutas absolutas.
final RegExp _knownPath =
    RegExp(r'^(paquetes/[a-z0-9_]+\.json|catalogo\.json|voz\.json)$');

/// Un archivo del índice: su huella sha256 (en hexadecimal) y su tamaño.
class ContentFile {
  const ContentFile({required this.sha256, required this.bytes});

  factory ContentFile.fromJson(Map<String, Object?> j) => ContentFile(
        sha256: (j['sha256']! as String).toLowerCase(),
        bytes: (j['bytes']! as num).toInt(),
      );

  final String sha256;
  final int bytes;

  Map<String, Object?> toJson() => {'sha256': sha256, 'bytes': bytes};
}

/// `indice.json`: qué versión del contenido hay y qué archivos la forman.
class ContentIndex {
  const ContentIndex({
    required this.version,
    required this.engine,
    required this.language,
    required this.catalogVersion,
    required this.files,
    this.format = contentIndexFormat,
    this.published,
  });

  /// Lee el índice. Lanza [FormatException] si le falta algo o trae una ruta que no se conoce.
  factory ContentIndex.fromJson(Map<String, Object?> j) {
    final raw = j['archivos'];
    if (raw is! Map<String, Object?>) {
      throw const FormatException('el índice no tiene «archivos»');
    }
    final files = <String, ContentFile>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (!_knownPath.hasMatch(key)) continue;
      files[key] = ContentFile.fromJson(value! as Map<String, Object?>);
    }
    return ContentIndex(
      format: (j['formato'] as num?)?.toInt() ?? 1,
      version: (j['version']! as num).toInt(),
      engine: (j['motor']! as num).toInt(),
      language: j['idioma']! as String,
      catalogVersion: j['catalogo'] as String? ?? '',
      published: j['publicado'] as String?,
      files: files,
    );
  }

  final int format;
  final int version;
  final int engine;
  final String language;
  final String catalogVersion;
  final String? published;

  /// Ruta relativa a `contenido/<idioma>/` → su huella.
  final Map<String, ContentFile> files;

  Map<String, Object?> toJson() => {
        'formato': format,
        'version': version,
        'motor': engine,
        'idioma': language,
        'catalogo': catalogVersion,
        if (published != null) 'publicado': published,
        'archivos': {
          for (final MapEntry(:key, :value) in files.entries)
            key: value.toJson(),
        },
      };
}

/// El contenido bajado que se puede usar: el índice y, por cada asset que reemplaza, el archivo del teléfono.
class LocalContent {
  const LocalContent({required this.index, required this.assets});

  final ContentIndex index;

  /// Asset de la app (`assets/packs/medieval/pack.json`…) → archivo bajado que lo reemplaza.
  final Map<String, String> assets;
}

/// Qué pasó al buscar contenido nuevo (para las pruebas y el registro).
enum ContentUpdate {
  /// Sin URL configurada.
  off,

  /// Ya se miró hoy.
  checkedToday,

  /// Sin red o el servidor no respondió bien.
  unreachable,

  /// La versión publicada es la que ya se tiene (o una anterior).
  same,

  /// Hay contenido nuevo pero no sirve (motor viejo, huella mala, JSON roto…): se sigue con lo anterior.
  rejected,

  /// Se bajó y se guardó: vale desde el siguiente arranque.
  updated,
}

/// Lee y guarda el contenido remoto de un idioma. Nunca lanza: si algo falla, todo sigue como estaba.
class RemoteContent {
  RemoteContent({
    this.baseUrl = contentBaseUrl,
    this.language = 'es',
    this.catalogAsset = fixedCatalogAsset,
    this.engine = contentEngineVersion,
    AssetBundle? bundle,
    http.Client? client,
    Future<Directory> Function()? supportDir,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  })  : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client(),
        _supportDir = supportDir ?? getApplicationSupportDirectory,
        _now = clock ?? DateTime.now;

  /// Raíz pública del almacén (`https://…/`, con la barra final). Vacía = apagado.
  final String baseUrl;
  final String language;

  /// El catálogo fijo que trae la app (el que reemplaza `catalogo.json`).
  final String catalogAsset;

  /// Versión de contenido que entiende este motor.
  final int engine;
  final Duration timeout;
  final AssetBundle _bundle;
  final http.Client _client;
  final Future<Directory> Function() _supportDir;
  final DateTime Function() _now;

  String get _remoteDir => '${baseUrl}contenido/$language/';

  Future<Directory> _root() async =>
      Directory('${(await _supportDir()).path}/contenido/$language');

  /// El asset de la app que reemplaza cada archivo del índice.
  String _assetFor(String path) {
    if (path == 'catalogo.json') return catalogAsset;
    if (path == 'voz.json') return 'assets/voz/$language/manifiesto.json';
    return packPath(path.substring('paquetes/'.length, path.length - 5));
  }

  /// Lo bajado antes, si existe y sigue valiendo (huellas correctas, motor que se entiende, y un catálogo que no es
  /// más viejo que el que trae la app). `null` = se usa lo que trae dentro.
  Future<LocalContent?> local() async {
    try {
      final root = await _root();
      final file = File('${root.path}/indice.json');
      if (!await file.exists()) return null;
      final j = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final index = ContentIndex.fromJson(j);
      final dir = Directory('${root.path}/${j['carpeta']! as String}');
      if (!_usable(index) || !await _notOlderThanBundled(index)) return null;
      final assets = <String, String>{};
      for (final MapEntry(:key, :value) in index.files.entries) {
        final f = File('${dir.path}/$key');
        if (!await _matches(await f.readAsBytes(), value)) {
          debugPrint('Contenido bajado con huella mala ($key): no se usa');
          return null;
        }
        assets[_assetFor(key)] = f.path;
      }
      return LocalContent(index: index, assets: assets);
    } catch (e) {
      debugPrint('Sin contenido bajado ($language): $e');
      return null;
    }
  }

  /// Mira si hay contenido nuevo (como mucho una vez al día, salvo con [force]) y, si lo hay y sirve, lo baja y lo
  /// guarda para el siguiente arranque.
  Future<ContentUpdate> update({bool force = false}) async {
    if (baseUrl.isEmpty) return ContentUpdate.off;
    try {
      final root = await _root();
      final today = _now().toIso8601String().substring(0, 10);
      final checked = File('${root.path}/revisado.txt');
      if (!force &&
          await checked.exists() &&
          (await checked.readAsString()).trim() == today) {
        return ContentUpdate.checkedToday;
      }
      final http.Response res;
      try {
        res = await _client
            .get(Uri.parse('${_remoteDir}indice.json'))
            .timeout(timeout);
      } catch (e) {
        debugPrint('Sin red para el contenido: $e');
        return ContentUpdate
            .unreachable; // se vuelve a intentar en el siguiente arranque
      }
      await root.create(recursive: true);
      await checked.writeAsString(today);
      if (res.statusCode != 200) return ContentUpdate.unreachable;
      final index = ContentIndex.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>);
      if (!_usable(index)) {
        debugPrint('Contenido ${index.version}: necesita el motor '
            '${index.engine} (este entiende $engine)');
        return ContentUpdate.rejected;
      }
      final current = await local();
      if (current != null && index.version <= current.index.version) {
        return ContentUpdate.same;
      }
      if (!await _notOlderThanBundled(index)) return ContentUpdate.same;
      return await _download(root, index, current);
    } catch (e) {
      debugPrint('Contenido remoto no válido: $e');
      return ContentUpdate.rejected;
    }
  }

  bool _usable(ContentIndex i) =>
      i.format <= contentIndexFormat &&
      i.engine <= engine &&
      i.language == language;

  /// Si el contenido trae catálogo, su versión no puede ser menor que la del que trae la app.
  Future<bool> _notOlderThanBundled(ContentIndex i) async {
    if (!i.files.containsKey('catalogo.json')) return true;
    final bundled = await loadFixedCatalog(_bundle, path: catalogAsset);
    return compareVersions(i.catalogVersion, bundled.version) >= 0;
  }

  static Future<bool> _matches(List<int> bytes, ContentFile f) async =>
      bytes.length == f.bytes && sha256.convert(bytes).toString() == f.sha256;

  Future<ContentUpdate> _download(
      Directory root, ContentIndex index, LocalContent? current) async {
    final folder = 'v${index.version}';
    final tmp = Directory('${root.path}/$folder.parcial');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    try {
      final got = <String, List<int>>{};
      for (final MapEntry(:key, :value) in index.files.entries) {
        // Lo que no cambió se copia de lo que ya se tenía; lo demás se baja
        final old = current?.index.files[key];
        final oldPath = current?.assets[_assetFor(key)];
        List<int>? bytes;
        if (old != null && old.sha256 == value.sha256 && oldPath != null) {
          bytes = await File(oldPath).readAsBytes();
        }
        if (bytes == null || !await _matches(bytes, value)) {
          final res =
              await _client.get(Uri.parse('$_remoteDir$key')).timeout(timeout);
          if (res.statusCode != 200) {
            throw HttpException('$key: ${res.statusCode}');
          }
          bytes = res.bodyBytes;
        }
        if (!await _matches(bytes, value)) {
          throw FormatException('$key: la huella no coincide');
        }
        got[key] = bytes;
      }
      await _check(got);
      for (final MapEntry(:key, :value) in got.entries) {
        final f = File('${tmp.path}/$key');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(value, flush: true);
      }
      final dir = Directory('${root.path}/$folder');
      if (await dir.exists()) await dir.delete(recursive: true);
      await tmp.rename(dir.path);
      // El índice local se escribe al final: hasta aquí, el arranque sigue usando lo anterior
      final idx = File('${root.path}/indice.json');
      final idxTmp = File('${idx.path}.parcial');
      await idxTmp.writeAsString(
          jsonEncode({...index.toJson(), 'carpeta': folder}),
          flush: true);
      await idxTmp.rename(idx.path);
      await _cleanOld(root, keep: folder);
      return ContentUpdate.updated;
    } catch (e) {
      debugPrint('Contenido ${index.version} rechazado: $e');
      if (await tmp.exists()) await tmp.delete(recursive: true);
      return ContentUpdate.rejected;
    }
  }

  /// Comprueba que lo bajado se puede usar: los paquetes los lee el motor, el catálogo y la voz son JSON válidos, y
  /// cada cuento del catálogo existe en su paquete (el bajado o el que trae la app).
  Future<void> _check(Map<String, List<int>> got) async {
    Map<String, Object?> json(String key) =>
        jsonDecode(utf8.decode(got[key]!)) as Map<String, Object?>;
    final packs = <String, Pack>{};
    for (final key in got.keys) {
      if (!key.startsWith('paquetes/')) continue;
      final pack = Pack.fromJson(json(key));
      final id = key.substring('paquetes/'.length, key.length - 5);
      if (pack.id != id) {
        throw FormatException('$key trae el paquete «${pack.id}»');
      }
      packs[id] = pack;
    }
    if (got.containsKey('voz.json') && json('voz.json')['cuentos'] is! Map) {
      throw const FormatException('voz.json sin «cuentos»');
    }
    if (!got.containsKey('catalogo.json')) return;
    final catalog = FixedCatalog.fromJson(json('catalogo.json'));
    if (catalog.language != language) {
      throw FormatException('catalogo.json es de «${catalog.language}»');
    }
    for (final e in catalog.entries) {
      final pack = packs[e.packId] ??=
          await loadPack(_bundle, path: packPath(e.packId)).catchError(
        (Object _) => throw FormatException('falta el paquete de ${e.id}'),
      );
      if (pack.premiseById(e.premiseId) == null) {
        throw FormatException('el catálogo trae ${e.id}, que no está en su '
            'paquete');
      }
    }
  }

  Future<void> _cleanOld(Directory root, {required String keep}) async {
    await for (final e in root.list()) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (e is Directory && name.startsWith('v') && name != keep) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}

/// Los assets de la app, con algunos reemplazados por archivos bajados ([LocalContent.assets]). Los loaders de
/// siempre (`loadPack`, `loadFixedCatalog`, `RecordedVoice.load`) leen de aquí sin saber de dónde sale cada uno.
class ContentBundle extends AssetBundle {
  ContentBundle(this.base, this.files);

  /// Los assets que trae la app.
  final AssetBundle base;

  /// Asset → archivo del teléfono que lo reemplaza.
  final Map<String, String> files;

  bool replaces(String key) => files.containsKey(key);

  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) return base.load(key);
    return ByteData.sublistView(await File(f).readAsBytes());
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    if (!replaces(key)) return base.loadBuffer(key);
    return ImmutableBuffer.fromUint8List(await File(files[key]!).readAsBytes());
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    final f = files[key];
    if (f == null) return base.loadString(key, cache: cache);
    return File(f).readAsString();
  }

  @override
  Future<T> loadStructuredData<T>(
      String key, Future<T> Function(String value) parser) async {
    if (!replaces(key)) return base.loadStructuredData(key, parser);
    return parser(await loadString(key));
  }

  @override
  void evict(String key) => base.evict(key);

  @override
  void clear() => base.clear();
}

/// Carpeta pública del audio grabado: [recordedVoiceBaseUrl] si se configuró; si no, `voz/<idioma>/` en la raíz del
/// contenido ([contentBaseUrl]). Vacía = solo suena el audio que trae la app.
String voiceBaseUrl({
  String language = 'es',
  String voice = recordedVoiceBaseUrl,
  String content = contentBaseUrl,
}) {
  if (voice.isNotEmpty) return voice;
  if (content.isEmpty) return '';
  return '${content}voz/$language/';
}
