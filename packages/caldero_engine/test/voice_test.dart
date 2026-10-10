import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

void main() {
  group('casos de la especificación', () {
    test('letras alargadas: «¡Fiuuu, fuuush!» → «¡Fiu, fush!»', () {
      expect(normalizeForVoice('¡Fiuuu, fuuush!'), '¡Fiu, fush!');
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
        normalizeForVoice('una chispa, otra chispa... ¡Flup!'),
        'una chispa, otra chispa. ¡Flup!',
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
    test('se dicen bien o se describen', () {
      expect(
        normalizeForVoice('«Aquí no hay nadie. Shhh», susurró.'),
        'Aquí no hay nadie. Chis, susurró.',
      );
      expect(normalizeForVoice('¡Grrr! Teo la oyó.'), '¡Gruñ! Teo la oyó.');
      expect(normalizeForVoice('¡Craaac!'), '¡Crac!');
      expect(normalizeForVoice('se oyó un «¡Beee!».'), 'se oyó un ¡Bee!');
      expect(normalizeForVoice('¡Fuuush!'), '¡Fush!');
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
    const dirty = '«¡NO!» Fiuuu... 3 faroles ★';
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
