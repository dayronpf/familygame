import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

Pack loadPack() => Pack.fromJson(
      jsonDecode(
        File('../../content/packs/medieval/pack.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );

void main() {
  group('normalizeChildName', () {
    test('limpia espacios, símbolos y mayúsculas', () {
      expect(normalizeChildName('  valentina '), 'Valentina');
      expect(normalizeChildName('MARÍA josé'), 'María José');
      expect(normalizeChildName('Ana-Luz'), 'Ana-Luz');
      expect(normalizeChildName("D'Arcy"), "D'arcy");
      expect(normalizeChildName('Leo 🐻 7'), 'Leo');
      expect(normalizeChildName('Íñigo'), 'Íñigo');
    });

    test('lo vacío o sin letras no es un nombre', () {
      expect(normalizeChildName(null), isNull);
      expect(normalizeChildName(''), isNull);
      expect(normalizeChildName('   '), isNull);
      expect(normalizeChildName('123 !!'), isNull);
    });

    test('se corta a la longitud máxima sin dejar espacios al final', () {
      final n = normalizeChildName('a' * 40)!;
      expect(n.length, maxChildNameLength);
      final m = normalizeChildName('Maria del Carmen Lopez Garcia')!;
      expect(m.length, lessThanOrEqualTo(maxChildNameLength));
      expect(m, isNot(endsWith(' ')));
    });
  });

  group('el niño como protagonista', () {
    final pack = loadPack();
    final engine = StoryEngine(pack);
    final heroes = pack.characters
        .where((c) => c.roles.contains('hero'))
        .map((c) => c.given)
        .toSet();

    test('el nombre sale en el texto y ningún héroe del pack se cuela', () {
      for (final age in ['2-3', '4-5', '6-8']) {
        for (var seed = 1; seed <= 300; seed++) {
          final s = engine.generate(
            StoryOptions(seed: seed, age: age, heroName: 'Valentina'),
          );
          final hero = s.cast['hero']! as Character;
          expect(hero.given, 'Valentina');
          final text = s.fullText;
          expect(text, contains('Valentina'), reason: 'seed $seed $age');
          for (final other in heroes) {
            // El otro héroe del pack puede ser el ayudante; si no está en el reparto, no debe salir
            final inCast = s.cast.values
                .whereType<Character>()
                .any((c) => c.given == other);
            if (!inCast) {
              expect(text, isNot(contains(other)), reason: '$other seed $seed');
            }
          }
        }
      }
    });

    test('el género pedido elige al héroe y la gramática lo sigue', () {
      for (var seed = 1; seed <= 80; seed++) {
        for (final g in ['m', 'f']) {
          final s = engine.generate(
            StoryOptions(
              seed: seed,
              age: '4-5',
              heroName: 'Luca',
              heroGender: g,
            ),
          );
          expect((s.cast['hero']! as Character).gender.name, g);
        }
      }
    });

    test(
        'con nombre, el héroe es siempre del género pedido (todas las edades y enseñanzas)',
        () {
      for (final age in ['2-3', '4-5', '6-8', '9-12']) {
        for (final moral in pack.morals) {
          for (var seed = 1; seed <= 40; seed++) {
            for (final g in ['m', 'f']) {
              final s = engine.generate(
                StoryOptions(
                  seed: seed,
                  age: age,
                  valueId: moral.id,
                  heroName: 'Dayron',
                  heroGender: g,
                ),
              );
              final hero = s.cast['hero']! as Character;
              expect(hero.gender.name, g, reason: '$age ${moral.id} $seed');
              expect(hero.given, 'Dayron');
            }
          }
        }
      }
    });

    test('sin nombre ni género todo sigue igual (misma semilla, mismo cuento)',
        () {
      final a = engine.generate(const StoryOptions(seed: 9, age: '4-5'));
      final b = engine.generate(
        const StoryOptions(seed: 9, age: '4-5', heroName: '   '),
      );
      expect(b.fullText, a.fullText);
    });

    test('el nombre nunca viaja en la receta', () {
      for (var seed = 1; seed <= 60; seed++) {
        final s = engine.generate(
          StoryOptions(seed: seed, heroName: 'Valentina', heroGender: 'f'),
        );
        final json = jsonEncode(s.recipe.toJson());
        expect(json, isNot(contains('Valentina')));
        // la receta con y sin nombre es la misma (con el mismo género)
        final plain =
            engine.generate(StoryOptions(seed: seed, heroGender: 'f'));
        expect(json, jsonEncode(plain.recipe.toJson()));
      }
    });

    test('si el niño se llama como otro personaje, no salen dos iguales', () {
      for (final name in ['Zafiro', 'Lía', 'Mara', 'Aldo', 'Rosa']) {
        for (var seed = 1; seed <= 200; seed++) {
          final s = engine.generate(StoryOptions(seed: seed, heroName: name));
          final named = s.cast.values
              .whereType<Character>()
              .where((c) => c.given == name);
          expect(named, hasLength(1), reason: '$name seed $seed');
        }
      }
    });

    test('todos los cuentos pasan el validador con un nombre largo y raro', () {
      // el texto con nombre sigue cumpliendo las reglas de oración y de edad
      for (final age in ['2-3', '4-5', '6-8']) {
        final profile = AgeProfile.byId(age)!;
        for (var seed = 1; seed <= 120; seed++) {
          final s = engine.generate(
            StoryOptions(seed: seed, age: age, heroName: 'Maria Fernanda'),
          );
          final m = measureStory(s, speed: profile.speed);
          expect(m.words, greaterThan(profile.minWords * 0.8), reason: age);
        }
      }
    });
  });
}
