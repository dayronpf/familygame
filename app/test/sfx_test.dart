import 'dart:io';

import 'package:caldero_app/src/audio/sfx.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apunta en orden lo que se dice y lo que suena.
class _Log {
  final events = <String>[];
}

class _Voice implements Narrator {
  _Voice(this.log);
  final _Log log;
  @override
  Future<void> speak(String sentence) async {
    log.events.add('voz: $sentence');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}

class _Sfx implements Sfx {
  _Sfx(this.log);
  final _Log log;
  final levels = <double>[];
  int stops = 0;
  @override
  Future<void> play(String id) async {
    log.events.add('sonido: $id');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> setLevel(double level) async => levels.add(level);
  @override
  Future<void> dispose() async {}
}

StoryPlayback _make(_Log log, _Sfx? sfx, String text) => StoryPlayback(
      scenes: [PlayScene(text: text, setup: null)],
      narrator: _Voice(log),
      sfx: sfx,
      gap: Duration.zero,
    );

Future<void> _finish(StoryPlayback pb) async {
  pb.play();
  for (var i = 0; i < 400 && !pb.finished; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('efectos de sonido en el reproductor', () {
    test('la voz dice lo de alrededor y el efecto suena en su sitio', () async {
      final log = _Log();
      final pb = _make(log, _Sfx(log),
          'El viento la levantó, ¡fiuuu!, y subió muy alto hacia el cielo.');
      await _finish(pb);
      expect(log.events, [
        'voz: El viento la levantó,',
        'sonido: wind',
        'voz: y subió muy alto hacia el cielo.',
      ]);
      pb.dispose();
    });

    test('un efecto al final de la frase suena después de lo que se dice',
        () async {
      final log = _Log();
      final pb = _make(log, _Sfx(log),
          'Se oyó un balido chiquitito: «¡beee!». Fin del cuento.');
      await _finish(pb);
      expect(log.events.first, 'voz: Se oyó un balido chiquitito.');
      expect(log.events[1], 'sonido: bleat');
      pb.dispose();
    });

    test('un efecto solo (sin voz) también suena', () async {
      final log = _Log();
      final pb =
          _make(log, _Sfx(log), '¡Plaf! La bota se mojó hasta el tobillo.');
      await _finish(pb);
      expect(log.events.first, 'sonido: splash');
      expect(log.events[1], 'voz: La bota se mojó hasta el tobillo.');
      pb.dispose();
    });

    test('sin efectos de sonido (apagados), la voz sigue sin decirlos',
        () async {
      final log = _Log();
      final pb =
          _make(log, null, 'El viento la levantó, ¡fiuuu!, y subió muy alto.');
      await _finish(pb);
      expect(
          log.events, ['voz: El viento la levantó,', 'voz: y subió muy alto.']);
      pb.dispose();
    });

    test(
        'el fundido del temporizador baja también los efectos y pausar los corta',
        () async {
      final log = _Log();
      final sfx = _Sfx(log);
      final pb = _make(log, sfx, 'Primera frase larga del cuento entero.');
      await pb.setVolume(0.25);
      expect(sfx.levels, [0.25]);
      pb.play();
      await pb.pause();
      expect(sfx.stops, greaterThan(0));
      pb.dispose();
    });
  });

  group('archivos y ajustes', () {
    test('todo sonido que pide el motor tiene su archivo en la app', () {
      for (final id in spanishVoiceRules.soundEffects.values.toSet()) {
        final f = File('assets/audio/sfx/$id.ogg');
        expect(f.existsSync(), isTrue, reason: id);
        expect(f.lengthSync(), greaterThan(1000), reason: id);
      }
    });

    test('los efectos están en el pubspec (carpeta sfx)', () {
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/audio/sfx/'));
    });

    test('«Efectos de sonido» se apaga y se guarda; lo normal no ocupa espacio',
        () async {
      final store = MemorySettingsStore();
      final s = AppSettings(store);
      await s.load();
      expect(s.effects, isTrue);
      expect(store.value ?? '', isNot(contains('efectos')));
      await s.setEffects(false);
      expect(s.effects, isFalse);
      final again = AppSettings(store);
      await again.load();
      expect(again.effects, isFalse);
    });
  });
}
