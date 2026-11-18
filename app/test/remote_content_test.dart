import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/catalog/story_catalog.dart';
import 'package:caldero_app/src/content/remote_content.dart';
import 'package:caldero_app/src/narration/recorded_voice.dart';
import 'package:caldero_app/src/pack_loader.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'file_bundle.dart';

const _base = 'https://almacen.test/';
const _catalogAsset = 'assets/catalogo/lanzamiento-es.json';
const _voiceAsset = 'assets/voz/es/manifiesto.json';

String _asset(String path) => File(path).readAsStringSync();

/// Un almacén de mentira: ruta (sin la raíz) → contenido. Anota lo que se pide; con [offline], no hay red.
class _Server {
  final files = <String, List<int>>{};
  final asked = <String>[];
  bool offline = false;

  late final client = MockClient((req) async {
    if (offline) throw const SocketException('sin red');
    final path = req.url.toString().substring(_base.length);
    asked.add(path);
    final body = files[path];
    return body == null
        ? http.Response('no existe', 404)
        : http.Response.bytes(body, 200);
  });

  /// Publica [content] (ruta relativa a `contenido/es/` → texto) con un índice como el de `publish.py`.
  /// [index] permite estropear o cambiar el índice antes de publicarlo.
  void publish(
    Map<String, String> content, {
    required int version,
    String catalog = '1.1',
    int engine = 1,
    void Function(Map<String, Object?> index)? index,
  }) {
    final archivos = <String, Object?>{};
    for (final MapEntry(:key, :value) in content.entries) {
      final bytes = utf8.encode(value);
      files['contenido/es/$key'] = bytes;
      archivos[key] = {
        'sha256': sha256.convert(bytes).toString(),
        'bytes': bytes.length
      };
    }
    final j = <String, Object?>{
      'formato': 1,
      'version': version,
      'motor': engine,
      'idioma': 'es',
      'catalogo': catalog,
      'archivos': archivos,
    };
    index?.call(j);
    files['contenido/es/indice.json'] = utf8.encode(jsonEncode(j));
  }
}

/// El paquete medieval con un cuento más («farol_nuevo», copia del primero) y el catálogo 1.2 que lo trae.
({String pack, String catalog}) _newStory() {
  final pack = jsonDecode(_asset('assets/packs/medieval/pack.json'))
      as Map<String, Object?>;
  final premises = pack['premises']! as List;
  final copy = jsonDecode(jsonEncode(premises.first)) as Map<String, Object?>;
  copy['id'] = 'farol_nuevo';
  copy['title'] = 'El farol nuevo';
  premises.add(copy);
  final catalog = jsonDecode(_asset(_catalogAsset)) as Map<String, Object?>;
  catalog['version'] = '1.2';
  (catalog['cuentos']! as List).add({
    'id': 'medieval:farol_nuevo',
    'titulo': 'El farol nuevo',
    'semilla': 1,
    'generoHeroe': 'f',
    'desde': '1.2',
  });
  return (pack: jsonEncode(pack), catalog: jsonEncode(catalog));
}

void main() {
  late Directory tmp;
  late _Server server;
  var now = DateTime(2026, 11, 18, 9);

  RemoteContent remote({String baseUrl = _base}) => RemoteContent(
        baseUrl: baseUrl,
        bundle: FileBundle(),
        client: server.client,
        supportDir: () async => tmp,
        clock: () => now,
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('contenido_');
    server = _Server();
    now = DateTime(2026, 11, 18, 9);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('sin URL no pide nada y el arranque usa lo de dentro', () async {
    final r = remote(baseUrl: '');
    expect(await r.update(), ContentUpdate.off);
    expect(await r.local(), isNull);
    expect(server.asked, isEmpty);
  });

  test(
      'versión nueva: baja, comprueba y guarda; el arranque siguiente la usa con «Nuevo»',
      () async {
    final n = _newStory();
    server.publish({
      'paquetes/medieval.json': n.pack,
      'catalogo.json': n.catalog,
      'voz.json': _asset(_voiceAsset),
    }, version: 2, catalog: '1.2');
    final r = remote();
    expect(await r.local(), isNull, reason: 'todavía no hay nada bajado');
    expect(await r.update(), ContentUpdate.updated);

    final local = (await r.local())!;
    expect(local.index.version, 2);
    expect(local.assets.keys.toSet(), {
      'assets/packs/medieval/pack.json',
      _catalogAsset,
      _voiceAsset,
    });

    // El arranque: los loaders de siempre leen lo bajado; lo demás sale de la app
    final bundle = ContentBundle(FileBundle(), local.assets);
    final fixed = await loadFixedCatalog(bundle);
    expect(fixed.version, '1.2');
    expect(fixed.newIds, ['medieval:farol_nuevo']);
    final medieval = await loadPack(bundle, path: packPath('medieval'));
    expect(medieval.premiseById('farol_nuevo'), isNotNull);
    final mar = await loadPack(bundle, path: packPath('mar'));
    final catalog = StoryCatalog.fromPacks({'medieval': medieval, 'mar': mar},
        fixed: fixed);
    final nuevo =
        catalog.stories.firstWhere((s) => s.key == 'medieval:farol_nuevo');
    expect(nuevo.isNew, isTrue);
    expect(catalog.newest, contains(nuevo));
    expect(
        catalog.stories
            .where((s) => s.pack.id == 'medieval' && s != nuevo)
            .any((s) => s.isNew),
        isFalse,
        reason: 'solo lo que entró en la última versión');
  });

  test('índice igual: no baja nada más que el índice', () async {
    server.publish({'catalogo.json': _asset(_catalogAsset)}, version: 3);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    server.asked.clear();
    expect(await r.update(force: true), ContentUpdate.same);
    expect(server.asked, ['contenido/es/indice.json']);
  });

  test('versión nueva con un solo archivo cambiado: baja solo ese', () async {
    final n = _newStory();
    server.publish({
      'paquetes/medieval.json': n.pack,
      'catalogo.json': _asset(_catalogAsset),
    }, version: 4);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    server.asked.clear();
    server.publish({
      'paquetes/medieval.json': n.pack,
      'catalogo.json': n.catalog,
    }, version: 5, catalog: '1.2');
    expect(await r.update(force: true), ContentUpdate.updated);
    expect(server.asked,
        ['contenido/es/indice.json', 'contenido/es/catalogo.json']);
    expect((await r.local())!.index.version, 5);
    // Solo queda la carpeta de la versión en uso
    final dirs = tmp
        .listSync(recursive: true)
        .whereType<Directory>()
        .map((d) => d.path.split('/').last)
        .where((n) => n.startsWith('v'));
    expect(dirs, ['v5']);
  });

  test('como mucho una vez al día', () async {
    server.publish({'catalogo.json': _asset(_catalogAsset)}, version: 6);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    expect(await r.update(), ContentUpdate.checkedToday);
    expect(server.asked, hasLength(2), reason: 'el índice y el catálogo');
    now = now.add(const Duration(days: 1));
    expect(await r.update(), ContentUpdate.same);
  });

  test('huella mala: no se guarda nada y se sigue con lo anterior', () async {
    server.publish({'catalogo.json': _asset(_catalogAsset)}, version: 7);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    server.publish({'catalogo.json': _newStory().catalog},
        version: 8, catalog: '1.2', index: (j) {
      ((j['archivos']! as Map)['catalogo.json']! as Map)['sha256'] = 'ab' * 32;
    });
    expect(await r.update(force: true), ContentUpdate.rejected);
    final local = (await r.local())!;
    expect(local.index.version, 7);
    expect(tmp.listSync(recursive: true).map((e) => e.path),
        isNot(contains(endsWith('.parcial'))));
  });

  test('motor viejo: no baja los archivos', () async {
    server.publish({'catalogo.json': _asset(_catalogAsset)},
        version: 9, engine: contentEngineVersion + 1);
    final r = remote();
    expect(await r.update(), ContentUpdate.rejected);
    expect(server.asked, ['contenido/es/indice.json']);
    expect(await r.local(), isNull);
  });

  test('sin red: no pasa nada y se vuelve a intentar en el siguiente arranque',
      () async {
    server.offline = true;
    final r = remote();
    expect(await r.update(), ContentUpdate.unreachable);
    expect(await r.local(), isNull);
    server.offline = false;
    server.publish({'catalogo.json': _asset(_catalogAsset)}, version: 10);
    expect(await r.update(), ContentUpdate.updated,
        reason: 'sin red no cuenta como «ya se miró hoy»');
  });

  test('JSON roto o paquete ilegible: se rechaza aunque la huella cuadre',
      () async {
    final r = remote();
    server.files['contenido/es/indice.json'] = utf8.encode('{no es json');
    expect(await r.update(), ContentUpdate.rejected);
    server.publish({'paquetes/medieval.json': '{"pack": {"schema": 99}}'},
        version: 11);
    expect(await r.update(force: true), ContentUpdate.rejected);
    // Un catálogo con un cuento que no está en ningún paquete tampoco sirve
    final catalog = jsonDecode(_newStory().catalog);
    server.publish({'catalogo.json': jsonEncode(catalog)},
        version: 12, catalog: '1.2');
    expect(await r.update(force: true), ContentUpdate.rejected);
    expect(await r.local(), isNull);
  });

  test('si lo bajado se estropea en el teléfono, el arranque usa lo de dentro',
      () async {
    server.publish({'catalogo.json': _asset(_catalogAsset)}, version: 13);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    final local = (await r.local())!;
    File(local.assets[_catalogAsset]!).writeAsStringSync('{}');
    expect(await r.local(), isNull);
  });

  test('un catálogo más viejo que el de la app no se baja ni se usa', () async {
    server.publish({'catalogo.json': _asset(_catalogAsset)},
        version: 14, catalog: '1.0');
    final r = remote();
    expect(await r.update(), ContentUpdate.same);
    expect(await r.local(), isNull);
  });

  test('una ruta desconocida o peligrosa del índice se ignora', () async {
    server.publish({
      'catalogo.json': _asset(_catalogAsset),
      '../../fuera.json': '{}',
    }, version: 15);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    expect(server.asked, isNot(contains(contains('fuera'))));
    expect((await r.local())!.assets.keys, [_catalogAsset]);
  });

  test(
      'la voz bajada: los audios que no trae la app se descargan aunque digan «incluido»',
      () async {
    final voice = jsonDecode(_asset(_voiceAsset)) as Map<String, Object?>;
    final cuentos = voice['cuentos']! as Map<String, Object?>;
    final paid =
        cuentos.entries.firstWhere((e) => (e.value as Map)['incluido'] != true);
    final free =
        cuentos.entries.firstWhere((e) => (e.value as Map)['incluido'] == true);
    (paid.value as Map)['incluido'] = true;
    server.publish({'voz.json': jsonEncode(voice)}, version: 16);
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    final bundle = ContentBundle(FileBundle(), (await r.local())!.assets);
    final v =
        await RecordedVoice.load(bundle, baseUrl: voiceBaseUrl(content: _base));
    final paidClips = v.clipsFor(paid.key)!.byText.values;
    final freeClips = v.clipsFor(free.key)!.byText.values;
    expect(paidClips.every((c) => !c.bundled), isTrue);
    expect(freeClips.every((c) => c.bundled), isTrue);
  });

  test(
      'la URL del audio sale de la raíz del contenido si no se configuró aparte',
      () {
    expect(voiceBaseUrl(voice: '', content: ''), '');
    expect(voiceBaseUrl(voice: '', content: 'https://a.test/'),
        'https://a.test/voz/es/');
    expect(
        voiceBaseUrl(
            voice: 'https://b.test/voz/es/', content: 'https://a.test/'),
        'https://b.test/voz/es/');
  });

  // Lo que arma `python3 tools/content/publish.py --en-carpeta`: si existe, la app lo entiende tal cual.
  final published = Directory('../builds/publicar');
  test('entiende la carpeta que arma publish.py', () async {
    for (final f in published.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(published.path.length + 1);
      if (rel.startsWith('contenido/')) server.files[rel] = f.readAsBytesSync();
    }
    final r = remote();
    expect(await r.update(), ContentUpdate.updated);
    final local = (await r.local())!;
    final bundle = ContentBundle(FileBundle(), local.assets);
    final fixed = await loadFixedCatalog(bundle);
    expect(fixed.entries, isNotEmpty);
    for (final e in fixed.entries) {
      final pack = await loadPack(bundle, path: packPath(e.packId));
      expect(pack.premiseById(e.premiseId), isNotNull, reason: e.id);
    }
    final v = await RecordedVoice.load(bundle);
    expect(v.has(fixed.free.first), isTrue);
  },
      skip: published.existsSync()
          ? false
          : 'sin builds/publicar (python3 tools/content/publish.py)');
}
