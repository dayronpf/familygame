import 'dart:async';

import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/narration/playback.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tts.dart';

void main() {
  group('cancelar no es fallar (el bug de «la voz se pierde al adelantar»)',
      () {
    test('tras parar a media frase, la voz sigue sonando con la siguiente',
        () async {
      final tts = FakeTts();
      final n = narratorOver(tts);
      final first = n.speak('Primera frase del cuento.');
      await settle();
      await n.stop(); // pausa o salto: el speak() pendiente devuelve 0
      await first;
      final second = n.speak('Segunda frase del cuento.');
      await settle();
      expect(tts.spoken.last, 'Segunda frase del cuento.');
      var done = false;
      unawaited(second.then((_) => done = true));
      await settle();
      expect(done, isFalse, reason: 'tiene que esperar a que la voz termine');
      tts.finish();
      await settle();
      expect(done, isTrue);
    });

    test('adelantar muchas veces seguidas no deja la voz muda', () async {
      final tts = FakeTts();
      final n = narratorOver(tts);
      for (var i = 0; i < 8; i++) {
        unawaited(n.speak('frase $i con varias palabras'));
        await settle();
        await n.stop();
      }
      unawaited(n.speak('la que tiene que sonar'));
      await settle();
      expect(tts.spoken.last, 'la que tiene que sonar');
      // …y sonó con el motor, no «por tiempo»
      expect(tts.speaking, isTrue);
    });
  });

  group('fallos de verdad', () {
    test('un fallo se reintenta y no apaga la voz', () async {
      final tts = FakeTts()..failNext = 2;
      final n = narratorOver(tts);
      final f = n.speak('Una frase que falla dos veces.');
      await settle();
      expect(tts.spoken, hasLength(3));
      tts.finish();
      await f;
    });

    test('si no hay manera, esa frase sigue por tiempo y la voz vuelve después',
        () async {
      final tts = FakeTts()..failNext = 3;
      final n = narratorOver(tts);
      await n.speak('Frase sin voz.'); // 3 intentos fallidos → por tiempo
      expect(tts.spoken, hasLength(3));
      final next = n.speak('Frase con voz otra vez.');
      await settle();
      expect(tts.spoken.last, 'Frase con voz otra vez.');
      tts.finish();
      await next;
    });

    test(
        'tres frases seguidas sin voz la dejan descansar hasta la próxima pausa',
        () async {
      final tts = FakeTts()..failNext = 9;
      final n = narratorOver(tts);
      for (var i = 0; i < 3; i++) {
        await n.speak('frase $i');
      }
      final before = tts.spoken.length;
      await n.speak('otra más'); // ya no lo intenta
      expect(tts.spoken.length, before);
      await n.stop(); // al pausar se vuelve a intentar
      tts.failNext = 0;
      final f = n.speak('de nuevo');
      await settle();
      expect(tts.spoken.last, 'de nuevo');
      tts.finish();
      await f;
    });

    test('sin voz en español, el cuento sigue por tiempo', () async {
      final tts = FakeTts()..hasSpanish = false;
      final n = narratorOver(tts);
      await n.speak('Nadie la dice en voz alta.');
      expect(tts.spoken, isEmpty);
    });
  });

  group('configuración', () {
    test('la velocidad y la voz elegidas llegan al motor', () async {
      final tts = FakeTts();
      const v = TtsVoice(name: 'es-es-x-eea-local', locale: 'es-ES');
      final n = TtsNarrator(
        tts: tts,
        config: const VoiceConfig(voice: v, speed: 0.8),
        fallback: TimedNarrator(wordsPerSecond: 1000, minSeconds: 0.01),
      );
      final f = n.speak('Hola.');
      await settle();
      expect(tts.voice, v);
      expect(tts.rate, closeTo(0.4, 1e-9));
      tts.finish();
      await f;
      await n.configure(const VoiceConfig(speed: 1.0));
      expect(tts.rate, closeTo(0.5, 1e-9));
    });

    test('solo ofrece las voces en español', () async {
      final tts = FakeTts()
        ..installed = const [
          TtsVoice(name: 'a', locale: 'es-ES'),
          TtsVoice(name: 'b', locale: 'en-US'),
          TtsVoice(name: 'c', locale: 'es_MX'),
        ];
      final voices = await TtsNarrator(tts: tts).availableVoices();
      expect(voices.map((v) => v.name), ['a', 'c']);
    });
  });

  group('texto de voz', () {
    test('al motor le llega la frase normalizada; en pantalla queda igual',
        () async {
      final tts = FakeTts();
      final n = narratorOver(tts);
      const screen = '«¡Hola!» dijo el viento, con 3 faroles. ¡Fuuush!';
      final pb = StoryPlayback(
        scenes: [PlayScene(text: screen, setup: null)],
        narrator: n,
      );
      pb.play();
      await settle();
      // Los efectos de sonido no se dicen; lo demás, sí (cifras en palabras, sin comillas)
      expect(tts.spoken.first, '¡Hola! dijo el viento, con tres faroles.');
      expect(pb.current.text, screen);
      pb.dispose();
    });
  });

  group('regresión del reproductor', () {
    PlayScene scene(String text) => PlayScene(text: text, setup: null);

    const names = [
      'alfa',
      'beta',
      'gamma',
      'delta',
      'epsilon',
      'zeta',
      'eta',
      'theta'
    ];
    test(
        'reproducir, adelantar 5 veces rápido, retroceder 2, pausar y reanudar: '
        'la voz suena en la frase correcta en cada paso', () async {
      final tts = FakeTts();
      final n = narratorOver(tts);
      final pb = StoryPlayback(
        scenes: [
          for (final w in names)
            scene(
                'Escena $w frase uno con palabras. Escena $w frase dos con palabras.'),
        ],
        narrator: n,
        gap: const Duration(milliseconds: 5),
      );
      pb.play();
      await settle();
      expect(tts.spoken.last, startsWith('Escena alfa'));

      for (var i = 0; i < 5; i++) {
        unawaited(pb.next());
      }
      await settle();
      await settle();
      expect(pb.scene, 5);
      expect(tts.spoken.last, startsWith('Escena zeta frase uno'));
      expect(tts.speaking, isTrue, reason: 'está sonando, no en silencio');

      unawaited(pb.previous());
      unawaited(pb.previous());
      await settle();
      await settle();
      expect(pb.scene, 3);
      expect(tts.spoken.last, startsWith('Escena delta frase uno'));
      expect(tts.speaking, isTrue);

      await pb.pause();
      expect(pb.playing, isFalse);
      expect(tts.speaking, isFalse);
      pb.play();
      await settle();
      expect(tts.spoken.last, startsWith('Escena delta'));
      expect(tts.speaking, isTrue);

      // y sigue solo a la frase siguiente cuando termina la actual
      tts.finish();
      await settle();
      expect(tts.spoken.last, 'Escena delta frase dos con palabras.');
      pb.dispose();
    });
  });
}
