import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart'
    show AssetSource, DeviceFileSource, Source;
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:caldero_app/src/narration/recorded_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Voz del teléfono de mentira: anota lo que dice.
class _Voice implements Narrator {
  final said = <String>[];
  @override
  Future<void> speak(String sentence) async {
    said.add(sentence);
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}

/// Audios en memoria: cada archivo es una fuente; los de [missing] no se consiguen (sin conexión).
class _Store implements ClipStore {
  final missing = <String>{};
  final prefetched = <String>[];

  @override
  Future<Source?> sourceFor(RecordedClip clip) async =>
      missing.contains(clip.file) ? null : AssetSource(clip.file);

  @override
  Future<void> prefetch(Iterable<RecordedClip> clips) async =>
      prefetched.addAll(clips.map((c) => c.file));
}

/// Reproductor de mentira: cada audio «suena» hasta que la prueba lo termina ([finish]) o hasta [stop]. Los de
/// [failing] no pueden sonar.
class _Player implements ClipPlayer {
  final played = <String>[];
  final failing = <String>{};
  int stops = 0;
  double? volume;
  bool disposed = false;
  bool autoFinish = true;
  Completer<bool>? _current;

  bool get playing => _current != null && !_current!.isCompleted;

  @override
  Future<bool> play(Source source) async {
    final file = (source as AssetSource).path;
    played.add(file);
    if (failing.contains(file)) return false;
    final c = _current = Completer<bool>();
    if (autoFinish) {
      Timer(const Duration(milliseconds: 5), () {
        if (!c.isCompleted) c.complete(true);
      });
    }
    return c.future;
  }

  void finish() {
    final c = _current;
    if (c != null && !c.isCompleted) c.complete(true);
  }

  @override
  Future<void> stop() async {
    stops++;
    finish();
  }

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Future<void> dispose() async => disposed = true;
}

RecordedClip _clip(String text, String file) =>
    RecordedClip(text: text, file: file, seconds: 2, bundled: true);

const _title = 'El farol';
const _s1 = 'Ana encendió el farol. Brilló mucho.';
const _s2 = 'Beto llegó corriendo.';
const _moral = 'La enseñanza de hoy: La luz se comparte.';

StoryClips _clips({bool withS2 = false}) => StoryClips({
      _title: _clip(_title, 'titulo.m4a'),
      _s1: _clip(_s1, 'e1.m4a'),
      if (withS2) _s2: _clip(_s2, 'e2.m4a'),
      _moral: _clip(_moral, 'ensenanza.m4a'),
    });

List<PlayScene> _scenes() => [
      PlayScene(text: _s1, setup: null),
      PlayScene(text: _s2, setup: null),
      PlayScene(text: _moral, setup: null, isMoral: true),
    ];

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 400 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('StoryPlayback con voz grabada', () {
    late _Voice voice;
    late _Store store;
    late _Player player;

    setUp(() {
      voice = _Voice();
      store = _Store();
      player = _Player();
    });

    StoryPlayback make({StoryClips? clips}) => StoryPlayback(
          scenes: _scenes(),
          narrator: voice,
          title: _title,
          gap: Duration.zero,
          recorded: clips ?? _clips(),
          clipStore: store,
          clipPlayer: player,
        );

    test(
        'el título y la escena que coincide suenan grabados; la otra, con la voz del teléfono',
        () async {
      final pb = make();
      expect(store.prefetched, containsAll(['titulo.m4a', 'e1.m4a']),
          reason: 'baja de antemano los audios del cuento');
      pb.play();
      await _until(() => pb.finished);
      expect(player.played, ['titulo.m4a', 'e1.m4a', 'ensenanza.m4a']);
      expect(voice.said, ['Beto llegó corriendo.'],
          reason: 'solo la escena sin audio la dice el teléfono');
      pb.dispose();
      expect(player.disposed, isTrue);
    });

    test('si el audio no suena, la escena la dice la voz del teléfono',
        () async {
      player.failing.addAll(['titulo.m4a', 'e1.m4a']);
      final pb = make();
      pb.play();
      await _until(() => pb.finished);
      expect(voice.said, [_title, ...splitSentences(_s1), _s2]);
      expect(player.played, contains('ensenanza.m4a'));
      pb.dispose();
    });

    test('sin conexión (el audio no se consigue) suena la voz del teléfono',
        () async {
      store.missing.add('e1.m4a');
      final pb = make();
      pb.play();
      await _until(() => pb.finished);
      expect(player.played, ['titulo.m4a', 'ensenanza.m4a']);
      expect(voice.said, [...splitSentences(_s1), _s2]);
      pb.dispose();
    });

    test('pausar detiene el audio y al seguir la escena vuelve a empezar',
        () async {
      player.autoFinish = false;
      final pb = make(clips: _clips(withS2: true));
      pb.play();
      await _until(() => player.played.length == 1);
      player.finish(); // termina el título
      await _until(() => player.played.length == 2);
      player.finish(); // termina la primera escena
      await _until(() => player.played.length == 3);
      expect(player.played.last, 'e2.m4a');
      expect(player.playing, isTrue);

      await pb.pause();
      expect(player.playing, isFalse);
      expect(player.stops, greaterThanOrEqualTo(1));
      expect(pb.scene, 1);
      expect(pb.sentence, 0, reason: 'un audio no se retoma a media frase');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(voice.said, isEmpty, reason: 'en pausa no habla nadie');
      expect(player.played, hasLength(3));

      pb.play();
      await _until(() => player.played.length == 4);
      expect(player.played.last, 'e2.m4a', reason: 'la escena vuelve a sonar');
      expect(voice.said, isEmpty);
      pb.dispose();
    });

    test('saltar de escena detiene el audio y suena el de la nueva', () async {
      player.autoFinish = false;
      final pb = make(clips: _clips(withS2: true));
      pb.play();
      await _until(() => player.played.length == 1);
      player.finish();
      await _until(() => player.played.length == 2);
      final stopsBefore = player.stops;

      await pb.next();
      expect(player.stops, greaterThan(stopsBefore));
      await _until(() => player.played.length == 3);
      expect(player.played.last, 'e2.m4a');
      expect(pb.scene, 1);
      expect(voice.said, isEmpty);
      pb.dispose();
    });

    test('el volumen del fundido también baja el audio grabado', () async {
      final pb = make();
      await pb.setVolume(0.25);
      expect(player.volume, 0.25);
      pb.dispose();
    });

    test(
        'sin voz grabada (cuento fuera del catálogo) no se toca el reproductor',
        () async {
      final pb = StoryPlayback(
        scenes: _scenes(),
        narrator: voice,
        title: _title,
        gap: Duration.zero,
        clipStore: store,
        clipPlayer: player,
      );
      pb.play();
      await _until(() => pb.finished);
      expect(player.played, isEmpty);
      expect(voice.said.first, _title);
      expect(voice.said, contains(_moral));
      pb.dispose();
    });
  });

  group('RecordedVoice.parse', () {
    final json = <String, Object?>{
      'version': '1.0',
      'idioma': 'es',
      'cuentos': {
        'medieval:sombras': {
          'incluido': true,
          'titulo': {
            'texto': 'Las sombras',
            'archivo': 'a.m4a',
            'segundos': 1.5
          },
          'ensenanza': {
            'texto': 'La enseñanza de hoy: Valor.',
            'archivo': 'b.m4a',
            'segundos': 3,
          },
          'escenas': [
            {'texto': 'Escena uno.', 'archivo': 'c.m4a', 'segundos': 9.25},
            {'texto': 'Sin archivo.'},
          ],
        },
        'mar:faro': {
          'incluido': false,
          'escenas': [
            {'texto': 'El faro.', 'archivo': 'd.m4a', 'segundos': 4},
          ],
        },
        'mar:vacio': {'incluido': false, 'escenas': <Object?>[]},
      },
    };

    test('cada cuento con sus audios por texto, incluidos o para descargar',
        () {
      final v = RecordedVoice.parse(json, language: 'es', store: _Store());
      expect(v.language, 'es');
      expect(v.has('medieval:sombras'), isTrue);
      expect(v.has('mar:vacio'), isFalse, reason: 'sin audios no cuenta');
      final s = v.clipsFor('medieval:sombras')!;
      expect(s.byText.keys, [
        'Las sombras',
        'La enseñanza de hoy: Valor.',
        'Escena uno.',
      ]);
      final c = s.clipFor('Escena uno.')!;
      expect(c.file, 'c.m4a');
      expect(c.seconds, 9.25);
      expect(c.bundled, isTrue);
      expect(s.clipFor('Sin archivo.'), isNull);
      expect(v.clipsFor('mar:faro')!.clipFor('El faro.')!.bundled, isFalse);
      expect(v.clipsFor('cosmos:otro'), isNull);
      expect(v.clipsFor(null), isNull);
    });

    test('sin manifiesto no hay voz grabada', () {
      expect(RecordedVoice.none.clipsFor('medieval:sombras'), isNull);
      final v = RecordedVoice.parse(const {}, language: 'es', store: _Store());
      expect(v.has('medieval:sombras'), isFalse);
    });

    test(
        'el manifiesto que lleva la app se lee y trae los cuentos gratis incluidos',
        () {
      final file = File('assets/voz/es/manifiesto.json');
      // Lo escribe tools/voice/export_app.py; va en la app desde el paso A6
      expect(file.existsSync(), isTrue);
      final v = RecordedVoice.parse(
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
        language: 'es',
        store: _Store(),
      );
      for (final id in [
        'medieval:sombras',
        'mar:galletas_todos',
        'cosmos:chispa_perdida'
      ]) {
        final clips = v.clipsFor(id);
        expect(clips, isNotNull, reason: id);
        for (final c in clips!.byText.values) {
          expect(c.bundled, isTrue, reason: '$id ${c.file}');
          expect(File('assets/voz/es/audio/${c.file}').existsSync(), isTrue,
              reason: '$id ${c.file}');
        }
      }
    });
  });

  group('CachedClipStore', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('voz_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    RecordedClip remote(String file) =>
        RecordedClip(text: 't', file: file, seconds: 1, bundled: false);

    test('los incluidos salen de los assets, sin descargar nada', () async {
      var calls = 0;
      final store = CachedClipStore(
        language: 'es',
        baseUrl: 'https://cdn.test/voz/es/',
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        cacheDir: () async => tmp,
      );
      final src = await store.sourceFor(const RecordedClip(
          text: 't', file: 'a.m4a', seconds: 1, bundled: true));
      expect((src! as AssetSource).path, 'voz/es/audio/a.m4a');
      expect(calls, 0);
    });

    test('los demás se descargan una vez y quedan guardados', () async {
      final urls = <String>[];
      final store = CachedClipStore(
        language: 'es',
        baseUrl: 'https://cdn.test/voz/es/',
        client: MockClient((req) async {
          urls.add(req.url.toString());
          return http.Response.bytes([1, 2, 3], 200);
        }),
        cacheDir: () async => tmp,
      );
      final a = await store.sourceFor(remote('b.m4a'));
      final path = (a! as DeviceFileSource).path;
      expect(path, '${tmp.path}/es/b.m4a');
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
      final again = await store.sourceFor(remote('b.m4a'));
      expect((again! as DeviceFileSource).path, path);
      expect(urls, ['https://cdn.test/voz/es/b.m4a'], reason: 'una sola vez');
      expect(
          tmp.listSync(recursive: true).where((f) => f.path.endsWith('.part')),
          isEmpty);
    });

    test(
        'dos pedidos a la vez comparten la descarga; prefetch salta los incluidos',
        () async {
      var calls = 0;
      final store = CachedClipStore(
        language: 'es',
        baseUrl: 'https://cdn.test/voz/es/',
        client: MockClient((req) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response.bytes([7], 200);
        }),
        cacheDir: () async => tmp,
      );
      await Future.wait([
        store.sourceFor(remote('c.m4a')),
        store.sourceFor(remote('c.m4a')),
      ]);
      expect(calls, 1);
      await store.prefetch([
        remote('d.m4a'),
        const RecordedClip(text: 't', file: 'e.m4a', seconds: 1, bundled: true),
      ]);
      expect(calls, 2);
      expect(File('${tmp.path}/es/d.m4a').existsSync(), isTrue);
      expect(File('${tmp.path}/es/e.m4a').existsSync(), isFalse);
    });

    test('si falla la descarga no queda nada y se usa la voz del teléfono',
        () async {
      final store = CachedClipStore(
        language: 'es',
        baseUrl: 'https://cdn.test/voz/es/',
        client: MockClient((_) async => http.Response('no', 404)),
        cacheDir: () async => tmp,
      );
      expect(await store.sourceFor(remote('f.m4a')), isNull);
      final offline = CachedClipStore(
        language: 'es',
        baseUrl: 'https://cdn.test/voz/es/',
        client: MockClient((_) async => throw http.ClientException('sin red')),
        cacheDir: () async => tmp,
      );
      expect(await offline.sourceFor(remote('f.m4a')), isNull);
      expect(File('${tmp.path}/es/f.m4a').existsSync(), isFalse);
    });

    test('sin servidor (URL vacía) no se pide nada', () async {
      var calls = 0;
      final store = CachedClipStore(
        language: 'es',
        baseUrl: '',
        client: MockClient((_) async {
          calls++;
          return http.Response.bytes([1], 200);
        }),
        cacheDir: () async => tmp,
      );
      expect(await store.sourceFor(remote('g.m4a')), isNull);
      expect(calls, 0);
    });
  });
}
