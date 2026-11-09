import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

Pack _pack(String id) => Pack.fromJson(
      jsonDecode(File('../../content/packs/$id/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );

void main() {
  group('StoryOptions.premiseId (cuento elegido en el catálogo)', () {
    for (final id in ['medieval', 'mar', 'cosmos']) {
      test('$id: cada premisa se puede contar a propósito', () {
        final pack = _pack(id);
        final engine = StoryEngine(pack);
        for (final p in pack.premises) {
          final story = engine.generate(
            StoryOptions(seed: 7, premiseId: p.id, interactive: false),
          );
          expect(story.recipe.fragmentIds.first, startsWith('${p.id}.'));
          if (p.value != anyValue) expect(story.moral.id, p.value);
        }
      });
    }

    test('misma semilla y premisa ⇒ mismo cuento', () {
      final engine = StoryEngine(_pack('medieval'));
      String text(int seed) => engine
          .generate(
            StoryOptions(
              seed: seed,
              premiseId: 'puente',
              heroName: 'Ana',
              heroGender: 'f',
            ),
          )
          .scenes
          .map((s) => s.text)
          .join('\n');
      expect(text(42), text(42));
      expect(text(42), contains('Ana'));
    });

    test('una premisa desconocida falla con un mensaje claro', () {
      final engine = StoryEngine(_pack('medieval'));
      expect(
        () => engine.generate(const StoryOptions(seed: 1, premiseId: 'nada')),
        throwsA(isA<StoryGenerationException>()),
      );
    });
  });
}
