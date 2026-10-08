import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> _demoJson() =>
    jsonDecode(File('../../content/packs/demo/pack.json').readAsStringSync())
        as Map<String, Object?>;

Pack _demo() => Pack.fromJson(_demoJson());

void main() {
  group('Mulberry32', () {
    test('es determinista', () {
      final a = Mulberry32(42);
      final b = Mulberry32(42);
      expect(
        List.generate(10, (_) => a.nextUint32()),
        List.generate(10, (_) => b.nextUint32()),
      );
    });

    test('semillas distintas dan secuencias distintas', () {
      expect(Mulberry32(1).nextUint32(), isNot(Mulberry32(2).nextUint32()));
    });

    test('nextInt queda en rango y cubre todos los valores', () {
      final rng = Mulberry32(7);
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        final v = rng.nextInt(5);
        expect(v, inInclusiveRange(0, 4));
        seen.add(v);
      }
      expect(seen, {0, 1, 2, 3, 4});
    });

    test('coincide con la implementación de referencia de mulberry32', () {
      // Valores obtenidos con la versión JS canónica (Math.imul). Si cambian,
      // cambian TODOS los cuentos que las familias hayan guardado por semilla.
      final one = Mulberry32(1);
      expect(
        [one.nextUint32(), one.nextUint32(), one.nextUint32()],
        [2693262067, 11749833, 2265367787],
      );
      final answer = Mulberry32(42);
      expect(
        [answer.nextUint32(), answer.nextUint32(), answer.nextUint32()],
        [2581720956, 1925393290, 3661312704],
      );
    });
  });

  group('gramática', () {
    const nilo = Character(
      id: 'nilo',
      noun: 'erizo',
      gender: Gender.m,
      given: 'Nilo',
      roles: ['hero'],
      alignment: 'positive',
      trait: {'m': 'curioso', 'f': 'curiosa'},
    );
    const luna = Character(
      id: 'luna',
      noun: 'tortuga',
      gender: Gender.f,
      given: 'Luna',
      roles: ['hero'],
      alignment: 'positive',
      trait: {'m': 'valiente', 'f': 'valiente'},
    );
    const bosque = Place(
      id: 'b',
      noun: 'bosque',
      gender: Gender.m,
      mood: 'calm',
    );
    const cueva = Place(id: 'c', noun: 'cueva', gender: Gender.f, mood: 'calm');

    test('masculino y femenino', () {
      const template = '{hero.El} {hero} es {hero.un} llamad{hero.o}.';
      expect(
        renderTemplate(template, {'hero': nilo}),
        'El erizo Nilo es un erizo llamado.',
      );
      expect(
        renderTemplate(template, {'hero': luna}),
        'La tortuga Luna es una tortuga llamada.',
      );
    });

    test('artículos, contracciones y lugares', () {
      final cast = <String, Entity>{
        'hero': luna,
        'place': bosque,
        'place2': cueva,
      };
      expect(
        renderTemplate('{hero.el}/{hero.un}/{hero.del}/{hero.al}', cast),
        'la tortuga/una tortuga/de la tortuga/a la tortuga',
      );
      expect(
        renderTemplate('{place.En}, {place.en}, {place.del}, {place.al}', cast),
        'En el bosque, en el bosque, del bosque, al bosque',
      );
      expect(
        renderTemplate('{place2.El} {place2.en}', cast),
        'La cueva en la cueva',
      );
    });

    test('concordancia del rasgo y del participio', () {
      expect(renderTemplate('{hero.trait}', {'hero': nilo}), 'curioso');
      expect(
        renderTemplate('{hero.trait} avergonzad{hero.o}', {'hero': luna}),
        'valiente avergonzada',
      );
    });

    test('token inexistente lanza TemplateException', () {
      expect(
        () => renderTemplate('{ghost}', {'hero': nilo}),
        throwsA(isA<TemplateException>()),
      );
      expect(
        () => renderTemplate('{hero.nope}', {'hero': nilo}),
        throwsA(isA<TemplateException>()),
      );
      expect(
        () => renderTemplate('{place.trait}', {'place': bosque}),
        throwsA(isA<TemplateException>()),
      );
    });
  });

  group('pack', () {
    test('el pack demo se lee', () {
      final pack = _demo();
      expect(pack.id, 'demo');
      expect(pack.characters, hasLength(5));
      expect(pack.morals.map((m) => m.id), [
        'honestidad',
        'generosidad',
        'valentia',
      ]);
    });

    test('esquema no soportado', () {
      final j = _demoJson();
      (j['pack']! as Map<String, Object?>)['schema'] = 99;
      expect(() => Pack.fromJson(j), throwsA(isA<PackFormatException>()));
    });

    test('etapa desconocida', () {
      final j = _demoJson();
      (j['fragments']! as List<Object?>).add({
        'id': 'x',
        'stage': 'epilogo',
        'values': ['*'],
        'text': 'Hola.',
      });
      expect(() => Pack.fromJson(j), throwsA(isA<PackFormatException>()));
    });
  });

  group('motor', () {
    final engine = StoryEngine(_demo());

    test('misma semilla ⇒ mismo cuento', () {
      final a = engine.generate(
        const StoryOptions(seed: 3, valueId: 'honestidad'),
      );
      final b = engine.generate(
        const StoryOptions(seed: 3, valueId: 'honestidad'),
      );
      expect(a.fullText, b.fullText);
    });

    test('golden: semilla 3 + honestidad', () {
      final story = engine.generate(
        const StoryOptions(seed: 3, valueId: 'honestidad'),
      );
      expect(story.scenes.map((s) => s.fragmentId), [
        'op_1',
        'tr_hon',
        'he_hon',
        'te_1',
        'cl_hon',
        're_hon',
        'cl_end',
      ]);
      expect(story.fullText, startsWith('Había una vez, en '));
      // Regresión: antes salía «a el erizo» por una plantilla sin contracción.
      expect(story.fullText, contains('se lo contó todo al erizo Nilo.'));
      expect(story.fullText, endsWith('Enseñanza: ${story.moral.text}'));
    });

    test('propiedades en 1000 semillas × todas las enseñanzas', () {
      for (final moral in engine.pack.morals) {
        for (var seed = 0; seed < 1000; seed++) {
          final story = engine.generate(
            StoryOptions(seed: seed, valueId: moral.id),
          );
          final ids = story.scenes.map((s) => s.fragmentId).toList();
          expect(
            ids.toSet(),
            hasLength(ids.length),
            reason: 'fragmento repetido',
          );
          expect(story.scenes, hasLength(storyStages.length));
          expect(story.fullText, isNot(contains('{')));
          expect(story.cast['place']!.id, isNot(story.cast['place2']!.id));
          expect(story.cast['helper']!.id, isNot(story.cast['hero']!.id));
        }
      }
    });

    test('sin enseñanza elegida, usa una del pack', () {
      final story = engine.generate(const StoryOptions(seed: 9));
      expect(engine.pack.morals.map((m) => m.id), contains(story.moral.id));
    });

    test('enseñanza desconocida', () {
      expect(
        () => engine.generate(const StoryOptions(seed: 1, valueId: 'envidia')),
        throwsA(isA<StoryGenerationException>()),
      );
    });

    test('hay variedad entre semillas', () {
      final texts = {
        for (var s = 0; s < 200; s++)
          engine.generate(StoryOptions(seed: s, valueId: 'valentia')).fullText,
      };
      expect(texts.length, greaterThan(20));
    });
  });

  group('validador', () {
    test('el pack demo es válido', () {
      final report = validatePack(_demo());
      expect(report.problems, isEmpty);
      expect(report.rendersChecked, greaterThan(1000));
    });

    Pack withFragment(Map<String, Object?> fragment) {
      final j = _demoJson();
      (j['fragments']! as List<Object?>).add(fragment);
      return Pack.fromJson(j);
    }

    test('detecta artículo en mayúscula a mitad de frase', () {
      final report = validatePack(
        withFragment({
          'id': 'bad_caps',
          'stage': 'opening',
          'values': ['*'],
          'text': 'Y entonces, {villain.El} {villain} se fue.',
        }),
      );
      expect(
        report.problems.where((p) => p.startsWith('bad_caps')),
        isNotEmpty,
      );
    });

    test('detecta contracción faltante (a el / de el)', () {
      final report = validatePack(
        withFragment({
          'id': 'bad_contraction',
          'stage': 'opening',
          'values': ['*'],
          'text': 'Se lo contó todo a {helper.el} {helper}.',
        }),
      );
      expect(
        report.problems.where((p) => p.startsWith('bad_contraction')),
        isNotEmpty,
      );
    });

    test('detecta forma inexistente', () {
      final report = validatePack(
        withFragment({
          'id': 'bad_form',
          'stage': 'opening',
          'values': ['*'],
          'text': 'Hola {hero.nada}.',
        }),
      );
      expect(report.problems.any((p) => p.contains('bad_form')), isTrue);
    });

    test('detecta frase sin cerrar', () {
      final report = validatePack(
        withFragment({
          'id': 'open_end',
          'stage': 'opening',
          'values': ['*'],
          'text': '{hero} camina sin parar',
        }),
      );
      expect(report.problems.any((p) => p.contains('open_end')), isTrue);
    });

    test('detecta enseñanza inexistente y requisito imposible', () {
      final report = validatePack(
        withFragment({
          'id': 'bad_refs',
          'stage': 'opening',
          'values': ['envidia'],
          'requires': ['nunca_existe'],
          'text': '{hero} camina.',
        }),
      );
      expect(
        report.problems,
        containsAll([
          'bad_refs: enseñanza inexistente "envidia"',
          'bad_refs: requiere "nunca_existe" pero ningún fragmento lo añade',
        ]),
      );
    });

    test('detecta falta de cobertura', () {
      final j = _demoJson();
      (j['fragments']! as List<Object?>).removeWhere(
        (f) => (f! as Map<String, Object?>)['id'] == 're_val',
      );
      final report = validatePack(Pack.fromJson(j));
      expect(
        report.problems.any((p) => p.startsWith('cobertura «valentia»')),
        isTrue,
      );
    });
  });
}
