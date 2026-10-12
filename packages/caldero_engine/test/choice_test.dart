import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> packJson() => jsonDecode(
      File('../../content/packs/medieval/pack.json').readAsStringSync(),
    ) as Map<String, Object?>;

/// Un cuento de `linterna` (la premisa con pregunta) para la edad dada.
int linternaSeed(StoryEngine engine, {String age = '6-8'}) {
  for (var s = 1; s < 500; s++) {
    final st = engine.generate(
      StoryOptions(seed: s, valueId: 'valentia', age: age),
    );
    if (st.recipe.fragmentIds.first.startsWith('linterna.')) return s;
  }
  throw StateError('ninguna semilla da linterna');
}

Map<String, Object?> linterna(Map<String, Object?> j) =>
    ((j['premises']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((p) => p['id'] == 'linterna'));

Map<String, Object?> beat(Map<String, Object?> premise, String id) =>
    (premise['beats']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((b) => b['id'] == id);

List<String> problemsOf(Map<String, Object?> j) =>
    validatePack(Pack.fromJson(j), coverageSeeds: 20).problems;

void main() {
  final pack = Pack.fromJson(packJson());
  final engine = StoryEngine(pack);
  final seed = linternaSeed(engine);

  group('cuento con pregunta', () {
    test('begin se detiene en la pregunta y la última escena la lleva', () {
      final run = engine.begin(
        StoryOptions(seed: seed, valueId: 'valentia', age: '6-8'),
      );
      expect(run.isComplete, isFalse);
      final q = run.pending!;
      expect(q.id, 'camino');
      expect(q.options.map((o) => o.id), ['oido', 'tacto', 'luna']);
      expect(q.ask, contains('en la oscuridad'));
      expect(q.ask, isNot(contains('{')), reason: 'con los nombres puestos');
      expect(run.story.scenes.last.choice?.id, 'camino');
      expect(run.story.scenes.last.pickedOption, isNull);
      expect(
        run.story.scenes.last.fragmentId,
        startsWith('linterna.se_apaga.'),
      );
      expect(run.story.recipe.choices, isEmpty);
    });

    test('elegir sigue el cuento por ese camino hasta el final', () {
      for (final option in ['oido', 'tacto', 'luna']) {
        final run = engine
            .begin(StoryOptions(seed: seed, valueId: 'valentia', age: '6-8'))
            .choose(option);
        expect(run.isComplete, isTrue);
        final st = run.story;
        expect(st.choices.single.id, 'linterna.camino.$option');
        expect(st.choices.single.auto, isFalse);
        expect(st.recipe.choices.single.id, 'linterna.camino.$option');
        final branch = st.scenes.firstWhere(
          (s) => s.fragmentId.contains('en_la_oscuridad'),
        );
        expect(branch.fragmentId, contains('.${option}_'));
        // La frase de enlace y el eco salen de la opción elegida
        expect(st.scenes.map((s) => s.text).join(' '), isNot(contains('{')));
        expect(
          st.scenes.length,
          pack.premises.firstWhere((p) => p.id == 'linterna').beats.length,
        );
      }
    });

    test('las escenas anteriores a la pregunta no dependen de la respuesta',
        () {
      final o = StoryOptions(seed: seed, valueId: 'valentia', age: '6-8');
      final before = engine.begin(o).story.scenes.map((s) => s.text).toList();
      for (final option in ['oido', 'tacto', 'luna']) {
        final after = engine.begin(o).choose(option).story.scenes;
        expect(after.take(before.length).map((s) => s.text).toList(), before);
      }
    });

    test('mismo cuento + mismas elecciones ⇒ mismo texto (determinista)', () {
      final o = StoryOptions(
        seed: seed,
        valueId: 'valentia',
        age: '6-8',
        choices: const ['tacto'],
      );
      expect(engine.generate(o).fullText, engine.generate(o).fullText);
      final stepped = engine
          .begin(StoryOptions(seed: seed, valueId: 'valentia', age: '6-8'))
          .choose('tacto')
          .story;
      expect(engine.generate(o).fullText, stepped.fullText);
    });

    test('generate elige solo y la receta lo marca como auto', () {
      final st = engine.generate(
        StoryOptions(seed: seed, valueId: 'valentia', age: '6-8'),
      );
      expect(st.choices, hasLength(1));
      expect(st.choices.single.auto, isTrue);
      expect(st.recipe.toJson()['choices'], [
        {'id': st.choices.single.id, 'auto': true},
      ]);
    });

    test(
        'la elección automática no depende de cuántas veces se genere ni del '
        'resto del cuento, y reparte entre las tres', () {
      final seen = <String>{};
      for (var s = 1; s < 400; s++) {
        final a = engine.generate(
          StoryOptions(seed: s, valueId: 'valentia', age: '6-8'),
        );
        final b = engine.generate(
          StoryOptions(seed: s, valueId: 'valentia', age: '6-8'),
        );
        expect(a.fullText, b.fullText);
        for (final c in a.choices) {
          if (c.premiseId == 'linterna') seen.add(c.optionId);
        }
      }
      expect(seen, {'oido', 'tacto', 'luna'});
    });

    test('interactive:false no se detiene (cuento guardado, temporizador)', () {
      final run = engine.begin(
        StoryOptions(
          seed: seed,
          valueId: 'valentia',
          age: '6-8',
          interactive: false,
          choices: const ['luna'],
        ),
      );
      expect(run.isComplete, isTrue);
      expect(run.story.choices.single.optionId, 'luna');
      expect(run.story.choices.single.auto, isFalse);
    });

    test(
        'a los de 2–3 años (y en edades fuera de la pregunta) nunca se '
        'pregunta', () {
      for (final age in ['2-3', '4-5']) {
        final run = engine.begin(StoryOptions(seed: seed, age: age));
        expect(run.isComplete, isTrue, reason: age);
      }
    });

    test('elegir lo que no existe o sin pregunta pendiente falla', () {
      final run = engine.begin(
        StoryOptions(seed: seed, valueId: 'valentia', age: '6-8'),
      );
      expect(() => run.choose('volar'), throwsArgumentError);
      expect(() => run.choose('oido').choose('oido'), throwsStateError);
      expect(
        () => engine.generate(
          StoryOptions(
            seed: seed,
            valueId: 'valentia',
            age: '6-8',
            choices: const ['volar'],
          ),
        ),
        throwsA(isA<StoryGenerationException>()),
      );
    });

    test(
        'la receta con elecciones viaja como JSON y vuelve igual; sin '
        'elecciones no cambia', () {
      final st = engine.generate(
        StoryOptions(seed: seed, valueId: 'valentia', age: '6-8'),
      );
      final back = StoryRecipe.fromJson(
        jsonDecode(jsonEncode(st.recipe.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), st.recipe.toJson());
      expect(back.choices.single.id, startsWith('linterna.camino.'));
      final other =
          engine.generate(StoryOptions(seed: 3, valueId: 'honestidad'));
      expect(other.recipe.toJson().containsKey('choices'), isFalse);
      expect(
        jsonEncode(st.recipe.toJson()),
        isNot(contains('beee')),
        reason: 'solo ids, nunca texto',
      );
    });

    test('el nombre del niño sale en la pregunta y en las frases del camino',
        () {
      final run = engine.begin(
        StoryOptions(
          seed: seed,
          valueId: 'valentia',
          age: '6-8',
          heroName: 'Nicolás',
        ),
      );
      expect(run.pending!.ask, contains('Nicolás'));
      final text = run.choose('luna').story.fullText;
      expect(text, contains('Nicolás'));
    });
  });

  group('pack con preguntas', () {
    test('el pack real las valida (todas las rutas)', () {
      expect(problemsOf(packJson()), isEmpty);
    });

    test('un pack con preguntas debe declarar choice@1', () {
      final j = packJson();
      (j['pack']! as Map<String, Object?>).remove('features');
      expect(problemsOf(j).join('\n'), contains('choice@1'));
    });

    test('un motor no acepta capacidades que no conoce', () {
      final j = packJson();
      (j['pack']! as Map<String, Object?>)['features'] = ['choice@1', 'voz@9'];
      expect(() => Pack.fromJson(j), throwsA(isA<PackFormatException>()));
    });

    test(
        'si una rama olvida el «ancla» de la enseñanza, el clímax no tiene '
        'variante y se rechaza', () {
      final j = packJson();
      final b = beat(linterna(j), 'en_la_oscuridad');
      final variants =
          (b['variants']! as List<Object?>).cast<Map<String, Object?>>();
      for (final v
          in variants.where((v) => v['id'].toString().startsWith('luna'))) {
        v['adds'] = <String>[];
      }
      final text = problemsOf(j).join('\n');
      expect(text, contains('sin variante elegible'));
      expect(text, contains('luna'));
    });

    test('una opción que nadie usa no cambia nada y se rechaza', () {
      final j = packJson();
      final q =
          beat(linterna(j), 'se_apaga')['choice']! as Map<String, Object?>;
      (q['options']! as List<Object?>).add({
        'id': 'gritar',
        'label': 'Gritar muy fuerte',
        'icon': {'glyph': 'volume_up'},
        'says': {'llegada': 'Llegó.', 'recuerdo': 'un eco'},
      });
      expect(problemsOf(j).join('\n'), contains('no cambia nada'));
    });

    test('reglas de la pregunta: etiqueta, icono, opciones y claves de says',
        () {
      final j = packJson();
      final q =
          beat(linterna(j), 'se_apaga')['choice']! as Map<String, Object?>;
      final options =
          (q['options']! as List<Object?>).cast<Map<String, Object?>>();
      options[0]['label'] = '¡Seguir el beee!';
      (options[1]['icon']! as Map<String, Object?>)['glyph'] = 'rocket';
      (options[2]['says']! as Map<String, Object?>).remove('recuerdo');
      final text = problemsOf(j).join('\n');
      expect(text, contains('lleva puntuación'));
      expect(text, contains('fuera de la lista cerrada'));
      expect(text, contains('mismas claves'));
    });

    test('no se pregunta en la primera escena ni en las tres últimas', () {
      final j = packJson();
      final p = linterna(j);
      final q = beat(p, 'se_apaga').remove('choice');
      beat(p, 'la_luz')['choice'] = q;
      var text = problemsOf(j).join('\n');
      expect(text, contains('primera escena'));

      final j2 = packJson();
      final p2 = linterna(j2);
      final q2 = beat(p2, 'se_apaga').remove('choice');
      beat(p2, 'el_regreso')['choice'] = q2;
      text = problemsOf(j2).join('\n');
      expect(text, contains('tres escenas antes del final'));
    });

    test('una frase de la opción que no existe en todas se detecta', () {
      final j = packJson();
      final v = (beat(linterna(j), 'cierre')['variants']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .first;
      v['text'] = '${v['text']} {camino.nada}';
      expect(problemsOf(j).join('\n'), contains('«camino»'));
    });
  });
}
