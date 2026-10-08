import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> demoJson() =>
    jsonDecode(File('../../content/packs/demo/pack.json').readAsStringSync())
        as Map<String, Object?>;

Pack withWeights(Map<String, double> weights) {
  final j = demoJson();
  for (final f in j['fragments']! as List<Object?>) {
    final m = f! as Map<String, Object?>;
    if (weights.containsKey(m['id'])) m['weight'] = weights[m['id']];
  }
  return Pack.fromJson(j);
}

void main() {
  group('receta del cuento', () {
    final pack = Pack.fromJson(demoJson());
    final story = StoryEngine(
      pack,
    ).generate(const StoryOptions(seed: 3, valueId: 'honestidad'));

    test('identifica el cuento sin llevar su texto', () {
      final r = story.recipe;
      expect(r.packId, 'demo');
      expect(r.packVersion, pack.version);
      expect(r.engineVersion, engineVersion);
      expect(r.seed, 3);
      expect(r.valueId, 'honestidad');
      expect(r.fragmentIds, story.scenes.map((s) => s.fragmentId).toList());
      expect(r.cast.keys, ['hero', 'helper', 'villain', 'place', 'place2']);
      expect(r.cast['hero'], story.cast['hero']!.id);
      final encoded = jsonEncode(r.toJson());
      // Nada de texto del cuento ni de nombres: solo identificadores.
      expect(encoded, isNot(contains('Había')));
      expect(encoded.length, lessThan(500));
    });

    test('viaja como JSON y vuelve igual', () {
      final back = StoryRecipe.fromJson(
        jsonDecode(jsonEncode(story.recipe.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), story.recipe.toJson());
    });

    test('la receta (con el pack) permite reproducir exactamente el cuento',
        () {
      final again = StoryEngine(pack).generate(
        StoryOptions(
          seed: story.recipe.seed,
          valueId: story.recipe.valueId,
        ),
      );
      expect(again.recipe.toJson(), story.recipe.toJson());
      expect(again.fullText, story.fullText);
    });
  });

  group('pesos de fragmentos', () {
    String firstOpening(Pack p, int seed) => StoryEngine(p)
        .generate(StoryOptions(seed: seed, valueId: 'valentia'))
        .recipe
        .fragmentIds
        .first;

    test('sin pesos, el resultado es el de siempre', () {
      final plain = Pack.fromJson(demoJson());
      final ones = withWeights({'op_1': 1, 'op_2': 1});
      for (var s = 0; s < 200; s++) {
        expect(firstOpening(ones, s), firstOpening(plain, s));
      }
    });

    test('peso 0 desactiva un fragmento', () {
      final p = withWeights({'op_2': 0});
      for (var s = 0; s < 300; s++) {
        expect(firstOpening(p, s), 'op_1');
      }
    });

    test('los pesos cambian la frecuencia en la proporción esperada', () {
      final p = withWeights({'op_1': 9, 'op_2': 1});
      var op1 = 0;
      const n = 4000;
      for (var s = 0; s < n; s++) {
        if (firstOpening(p, s) == 'op_1') op1++;
      }
      expect(op1 / n, closeTo(0.9, 0.03));
    });

    test('el mismo pack con pesos sigue siendo determinista', () {
      final p = withWeights({'op_1': 9, 'op_2': 1});
      final a = StoryEngine(p).generate(const StoryOptions(seed: 77));
      final b = StoryEngine(p).generate(const StoryOptions(seed: 77));
      expect(a.fullText, b.fullText);
    });

    test('un peso negativo se rechaza', () {
      expect(
        () => withWeights({'op_1': -1}),
        throwsA(isA<PackFormatException>()),
      );
    });

    test(
        'si se desactivan todas las opciones de una etapa, el validador lo detecta',
        () {
      final report = validatePack(withWeights({'op_1': 0, 'op_2': 0}));
      expect(report.problems.any((p) => p.startsWith('cobertura')), isTrue);
    });
  });
}
