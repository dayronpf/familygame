import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

void main() {
  group('casos de la especificación', () {
    test(
        'letras alargadas: «¡Fiuuu, fuuush!» no se dice; «Fiuuu» suelto → «Fiu»',
        () {
      expect(normalizeForVoice('¡Fiuuu, fuuush!'), '');
      expect(normalizeForVoice('Hizo fiuuu y se fue'), 'Hizo fiu y se fue');
    });

    test('comillas angulares: se quitan y el signo pegado se arregla', () {
      expect(
        normalizeForVoice('«¡Lía no ha vuelto!» Los mayores salieron.'),
        '¡Lía no ha vuelto! Los mayores salieron.',
      );
      expect(
        normalizeForVoice(
          'Gritó «¡Lía no ha vuelto!». Los mayores salieron.',
        ),
        'Gritó ¡Lía no ha vuelto! Los mayores salieron.',
      );
      expect(normalizeForVoice('—dijo «sí», y se fue'), '—dijo sí, y se fue');
      expect(normalizeForVoice('“hola” y "adiós"'), 'hola y adiós');
    });

    test('números a palabras', () {
      expect(normalizeForVoice('3 faroles'), 'tres faroles');
      expect(
        normalizeForVoice('Tenía 21 años y 100 ovejas.'),
        'Tenía veintiuno años y cien ovejas.',
      );
      expect(
        normalizeForVoice('en 1250 pasos'),
        'en mil doscientos cincuenta pasos',
      );
      expect(normalizeForVoice('pesa 3,5 kilos'), 'pesa tres coma cinco kilos');
      expect(normalizeForVoice('2000 y 15'), 'dos mil y quince');
    });

    test('símbolos y emojis se quitan o se dicen', () {
      expect(normalizeForVoice('Hola ★ amigo ♪ 😊'), 'Hola amigo');
      expect(normalizeForVoice('pan & queso'), 'pan y queso');
      expect(normalizeForVoice('50% más'), 'cincuenta por ciento más');
    });

    test('abreviaturas', () {
      expect(
        normalizeForVoice('Sr. Gil, Dra. Paz, etc.'),
        'señor Gil, doctora Paz, etcétera',
      );
    });

    test('mayúsculas de énfasis: «¡NO!» → «¡No!»', () {
      expect(normalizeForVoice('¡NO! Dijo CLANG.'), '¡No! Dijo Clang.');
    });

    test('puntos suspensivos: queda un solo punto', () {
      expect(normalizeForVoice('Esperó……'), 'Esperó.');
      expect(
        normalizeForVoice('una chispa, otra chispa... ¡Hola!'),
        'una chispa, otra chispa. ¡Hola!',
      );
      expect(
        normalizeForVoice('otro, otro… «¡Es muy poco!».'),
        'otro, otro. ¡Es muy poco!',
      );
      expect(normalizeForVoice('y entonces… llegó'), 'y entonces, llegó');
    });

    test(
        'frases largas: se parten con un punto por la coma más cercana a la mitad',
        () {
      const long =
          'El viejo farolero subió despacio la escalera de caracol de la torre, con la linterna apagada en una mano y el pedernal en la otra, mientras el viento silbaba afuera.';
      final out = normalizeForVoice(long);
      expect(out.split(RegExp(r'(?<=[.!?])\s+')).length, 2);
      expect(voiceIssues(out), isEmpty);
      // en pantalla (el texto original) no cambia nada: solo se normaliza la copia para la voz
      expect(long, contains(', con la linterna'));
    });

    test('una frase larga sin comas se deja y se avisa', () {
      final s = List.filled(25, 'palabra').join(' ');
      expect(voiceIssues(normalizeForVoice('$s.')), isNotEmpty);
    });
  });

  group('onomatopeyas del pack', () {
    test('un «shhh» que dice un personaje sí se dice (como «chis»)', () {
      expect(
        normalizeForVoice('«Aquí no hay nadie. Shhh», susurró.'),
        'Aquí no hay nadie. Chis, susurró.',
      );
    });

    test('los efectos de sonido entre ¡! no se dicen: se ven en pantalla', () {
      expect(normalizeForVoice('¡Craaac!'), '');
      expect(normalizeForVoice('«¡Beee, beee!»'), '');
      expect(normalizeForVoice('¡Grrr! Teo la oyó.'), 'Teo la oyó.');
      expect(
        normalizeForVoice(
          'De pronto llegó una ráfaga: ¡fuuu! La lucecita se apagó.',
        ),
        'De pronto llegó una ráfaga. La lucecita se apagó.',
      );
      expect(
        normalizeForVoice('Se oyó un balido chiquitito: «¡beee!».'),
        'Se oyó un balido chiquitito.',
      );
      expect(
        normalizeForVoice('El viento la levantó, ¡fiuuu!, y subió.'),
        'El viento la levantó, y subió.',
      );
      expect(
        normalizeForVoice(
          'La cabrita baló, «¡beee!», y le sonó la barriguita.',
        ),
        'La cabrita baló, y le sonó la barriguita.',
      );
      expect(
        normalizeForVoice('en el suelo: ¡clong! «Y le di la bolsa.»'),
        'en el suelo. Y le di la bolsa.',
      );
      expect(
        normalizeForVoice('«¡Beee!», dijo la cabrita.'),
        'Dijo la cabrita.',
      );
    });

    test('speechParts separa lo que se dice de los sonidos, en orden', () {
      List<String> show(String t) => [
            for (final p in speechParts(t))
              switch (p) {
                SpokenText(:final text) => text,
                SoundEffect(:final sound) => '<$sound>',
              },
          ];
      expect(
        show('El viento la levantó, ¡fiuuu!, y subió.'),
        ['El viento la levantó,', '<wind>', 'y subió.'],
      );
      expect(
        show('Se oyó un balido: «¡beee!».'),
        ['Se oyó un balido.', '<bleat>'],
      );
      expect(
        show('¡Cric, cric! Crujió la rama.'),
        ['<creak>', 'Crujió la rama.'],
      );
      expect(
        show('Saltó: ¡hop! Saltó otra vez: ¡hop!'),
        ['Saltó.', '<hop>', 'Saltó otra vez.', '<hop>'],
      );
      expect(
        show('Sin ningún sonido, 3 faroles.'),
        ['Sin ningún sonido, tres faroles.'],
      );
      expect(show('«¡Ay!», gritó Aldo.'), ['¡Ay! gritó Aldo.']);
      expect(show('¡Plaf!'), ['<splash>']);
    });

    test('todos los sonidos de la lista tienen archivo', () {
      final ids = spanishVoiceRules.soundEffects.values.toSet();
      final files = Directory('../../app/assets/audio/sfx')
          .listSync()
          .map((f) => f.uri.pathSegments.last.replaceAll('.ogg', ''))
          .toSet();
      expect(
        files.containsAll(ids),
        isTrue,
        reason: '${ids.difference(files)}',
      );
    });

    test('lo que dice un personaje no es un efecto de sonido', () {
      expect(normalizeForVoice('«¡Ay!», gritó Aldo.'), '¡Ay! gritó Aldo.');
      expect(
        normalizeForVoice('Se rio, ¡ja!, y siguió.'),
        'Se rio, ¡ja! y siguió.',
      );
      expect(
        normalizeForVoice('«¡Atrás!», gruñó una voz.'),
        '¡Atrás! gruñó una voz.',
      );
      expect(
        normalizeForVoice('¡Cric, cuidado!'),
        '¡Cric, cuidado!',
        reason: 'mezclado con palabras: es una frase',
      );
    });

    test('voiceIssues avisa si al quitar el sonido la frase queda cortada', () {
      expect(
        voiceIssues(
          normalizeForVoice(
            'El agua hacía ¡shhh!, y el puente hacía ¡cric!',
          ),
        ),
        contains('frase cortada (¿un efecto de sonido sin verbo?)'),
      );
      expect(
        voiceIssues(
          normalizeForVoice(
            'El agua susurraba ¡shhh!, y el puente crujía ¡cric!',
          ),
        ),
        isEmpty,
      );
    });

    test('palabras normales con dos letras iguales no se tocan', () {
      expect(
        normalizeForVoice('El pasillo, la llave y el aire'),
        'El pasillo, la llave y el aire',
      );
    });
  });

  test('el texto limpio no cambia y la salida limpia es estable', () {
    const clean = 'La campana rodó escalera abajo. Aldo no dijo nada.';
    expect(normalizeForVoice(clean), clean);
    expect(voiceIssues(clean), isEmpty);
    const dirty = '«¡NO!» Fiuuu... 3 faroles ★ ¡Cric!';
    final once = normalizeForVoice(dirty);
    expect(normalizeForVoice(once), once);
  });

  test('un texto sin nada que decir queda vacío', () {
    expect(normalizeForVoice(' ★ 😊 '), '');
  });

  test('voiceIssues encuentra cada problema', () {
    expect(voiceIssues('¡Fiuuu!'), contains('letras repetidas 3 o más veces'));
    expect(voiceIssues('«Hola»'), contains('comillas'));
    expect(voiceIssues('3 faroles'), contains('cifras'));
    expect(voiceIssues('¡NO!'), contains('mayúsculas de énfasis'));
    expect(voiceIssues('Esperó...'), contains('puntos suspensivos'));
    expect(voiceIssues('Hola ★'), contains('símbolos o emojis'));
  });

  group(
      'criterio de aceptación: ningún cuento posible lleva problemas en texto_voz',
      () {
    test('todas las variantes de los cuentos del pack medieval', () {
      final pack = Pack.fromJson(
        jsonDecode(
          File('../../content/packs/medieval/pack.json').readAsStringSync(),
        ) as Map<String, Object?>,
      );
      final engine = StoryEngine(pack);
      final seen = <String>{};
      final bad = <String, List<String>>{};
      for (var seed = 1; seed <= 4000; seed++) {
        final story = engine.generate(StoryOptions(seed: seed));
        final texts = [
          if (story.title != null) story.title!,
          for (final s in story.scenes) s.text,
          'La enseñanza de hoy: ${story.moral.text}',
        ];
        for (final t in texts) {
          if (!seen.add(t)) continue;
          for (final sentence in t.split(RegExp(r'(?<=[.!?…]»?)\s+'))) {
            final v = normalizeForVoice(sentence);
            final issues = voiceIssues(v)
                .where(
                  (i) => !i.startsWith(
                    'frase de más',
                  ),
                ) // las largas sin coma se revisan aparte
                .toList();
            if (issues.isNotEmpty) bad[sentence] = issues;
          }
        }
      }
      expect(bad, isEmpty, reason: bad.entries.take(5).join('\n'));
      expect(seen.length, greaterThan(500));
    });
  });
}
