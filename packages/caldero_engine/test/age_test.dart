import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> packJson() => jsonDecode(
      File('../../content/packs/medieval/pack.json').readAsStringSync(),
    ) as Map<String, Object?>;

void main() {
  group('perfiles', () {
    test('son cuatro y cubren de 2 a 12 años sin huecos', () {
      expect(AgeProfile.all.map((p) => p.id), ['2-3', '4-5', '6-8', '9-12']);
      for (var age = 2; age <= 12; age++) {
        expect(AgeProfile.all.where((p) => p.coversAge(age)), hasLength(1));
      }
      expect(AgeProfile.forAge(7).id, '6-8');
      expect(AgeProfile.forAge(2).id, '2-3');
      expect(AgeProfile.forAge(14).id, '9-12');
    });

    test('cifras de la especificación: palabras, minutos, oración y velocidad',
        () {
      final p = AgeProfile.byId('6-8')!;
      expect([p.minWords, p.maxWords], [600, 1200]);
      expect([p.minMinutes, p.maxMinutes], [6, 10]);
      expect([p.minSentence, p.maxSentence], [8, 14]);
      expect(p.speed, 0.90);
      expect(AgeProfile.all.map((p) => p.speed), [0.80, 0.85, 0.90, 1.00]);
      // a más edad, cuentos más largos y voz más rápida
      for (var i = 1; i < AgeProfile.all.length; i++) {
        expect(AgeProfile.all[i].minWords, AgeProfile.all[i - 1].maxWords);
        expect(
          AgeProfile.all[i].speed,
          greaterThan(AgeProfile.all[i - 1].speed),
        );
      }
      expect(AgeProfile.byId('nada'), isNull);
    });
  });

  group('medición', () {
    test('cuenta palabras y oraciones', () {
      final m = measureText(['Una frase de cinco palabras. Otra más corta.']);
      expect(m.words, 8);
      expect(m.sentences, 2);
      expect(m.avgSentence, 4);
      expect(m.maxSentence, 5);
      expect(m.minutes, closeTo(8 / 110, 1e-9));
    });

    test('un texto de cuatro palabras no sirve a 6–8 ni a 9–12', () {
      final m = measureText(['Hola. Adiós. Sí. No.']);
      expect(m.fits(AgeProfile.byId('6-8')!), isFalse);
      expect(m.fits(AgeProfile.byId('9-12')!), isFalse);
    });
  });

  group('cuentos del pack medieval', () {
    final pack = Pack.fromJson(packJson());
    final engine = StoryEngine(pack);

    test('todos los cuentos posibles encajan en el perfil que declaran', () {
      final seen = <String>{};
      final bad = <String>[];
      for (final age in ['2-3', '4-5', '6-8', '9-12']) {
        final profile = AgeProfile.byId(age)!;
        for (var seed = 1; seed <= 1500; seed++) {
          final s = engine.generate(StoryOptions(seed: seed, age: age));
          final id = s.scenes.first.fragmentId.split('.').first;
          final premise = pack.premises.firstWhere((p) => p.id == id);
          expect(premise.ages, contains(age), reason: '$id para $age');
          seen.add(id);
          final m = measureStory(s, speed: profile.speed);
          if (!m.fits(profile)) {
            bad.add(
              '$id seed $seed ($age): ${m.words} palabras, media ${m.avgSentence.toStringAsFixed(1)}',
            );
          }
        }
      }
      expect(seen, pack.premises.map((p) => p.id).toSet());
      expect(bad, isEmpty, reason: bad.take(5).join('\n'));
    });

    test('hay cuentos para las cuatro edades, cada una con las seis enseñanzas',
        () {
      expect(pack.agesWithStories, {'2-3', '4-5', '6-8', '9-12'});
      expect(pack.morals, hasLength(6));
      for (final age in ['2-3', '4-5', '6-8', '9-12']) {
        for (final m in pack.morals) {
          expect(
            pack.premises
                .where((p) => p.ages.contains(age) && p.fitsValue(m.id)),
            isNotEmpty,
            reason: '$age ${m.id}',
          );
        }
      }
    });

    test(
        'los cuentos pequeños no llevan villano y la enseñanza se dice sencilla',
        () {
      for (final p in pack.premises
          .where((p) => p.ages.contains('2-3') || p.ages.contains('4-5'))) {
        expect(p.ages, hasLength(1), reason: p.id);
        for (final c in p.cast.values) {
          expect(c.roles, isNot(contains('villain')), reason: p.id);
        }
      }
      for (final age in ['2-3', '4-5']) {
        final s = engine.generate(StoryOptions(seed: 3, age: age));
        expect(s.moralLine, s.moral.simple[age], reason: age);
        expect(s.moralLine, isNot(s.moral.text));
        expect(s.fullText, endsWith(s.moralLine));
      }
      final older = engine.generate(StoryOptions(seed: 3, age: '6-8'));
      expect(older.moralLine, older.moral.text);
    });

    test('con la edad pedida solo salen cuentos de esa edad', () {
      for (var seed = 1; seed <= 120; seed++) {
        for (final age in ['2-3', '4-5', '6-8', '9-12']) {
          final s = engine.generate(StoryOptions(seed: seed, age: age));
          final id = s.scenes.first.fragmentId.split('.').first;
          expect(pack.premises.firstWhere((p) => p.id == id).ages, [age]);
        }
      }
    });

    test('la edad sin cuentos usa el perfil más cercano', () {
      expect(pack.resolveAge('6-8'), '6-8');
      expect(pack.resolveAge('2-3'), '2-3');
      expect(pack.resolveAge('4-5'), '4-5');
      expect(pack.resolveAge('9-12'), '9-12');
      // un pack sin cuentos de 9–12 usa el perfil más cercano
      final j = packJson();
      (j['premises']! as List)
          .removeWhere((p) => (p as Map)['ages'].toString().contains('9-12'));
      expect(Pack.fromJson(j).resolveAge('9-12'), '6-8');
      expect(pack.resolveAge(null), isNull);
      expect(pack.resolveAge('raro'), isNull);
    });

    test('pedir cualquier edad sigue dando un cuento', () {
      for (final age in ['2-3', '4-5', '6-8', '9-12', null]) {
        expect(
          () => engine.generate(StoryOptions(seed: 4, age: age)),
          returnsNormally,
          reason: '$age',
        );
      }
    });
  });

  group('filtro por edad', () {
    // Un pack donde «olla» sirve a 4–5 y el resto a 6–8
    Pack mixed() {
      final j = packJson();
      for (final p in (j['premises']! as List).cast<Map<String, Object?>>()) {
        p['ages'] = p['id'] == 'olla' ? ['4-5'] : ['6-8'];
      }
      return Pack.fromJson(j);
    }

    test('con la edad pedida solo salen cuentos de ese perfil', () {
      final pack = mixed();
      final engine = StoryEngine(pack);
      final ollaValue = pack.premises.firstWhere((p) => p.id == 'olla').value;
      for (var seed = 1; seed <= 60; seed++) {
        final young = engine
            .generate(StoryOptions(seed: seed, valueId: ollaValue, age: '4-5'));
        expect(young.scenes.first.fragmentId, startsWith('olla.'));
        final older = engine
            .generate(StoryOptions(seed: seed, valueId: ollaValue, age: '6-8'));
        expect(older.scenes.first.fragmentId, isNot(startsWith('olla.')));
      }
    });

    test('la edad más cercana con cuentos sustituye a la que no tiene', () {
      final pack = mixed();
      expect(pack.agesWithStories, {'4-5', '6-8'});
      expect(pack.resolveAge('2-3'), '4-5');
      expect(pack.resolveAge('9-12'), '6-8');
    });

    test('misma semilla y misma edad, mismo cuento', () {
      final engine = StoryEngine(mixed());
      final a = engine.generate(const StoryOptions(seed: 9, age: '4-5'));
      final b = engine.generate(const StoryOptions(seed: 9, age: '4-5'));
      expect(a.scenes.map((s) => s.text), b.scenes.map((s) => s.text));
    });

    test('una edad desconocida en el pack se rechaza', () {
      final j = packJson();
      ((j['premises']! as List).first as Map<String, Object?>)['ages'] = [
        '3-4',
      ];
      expect(() => Pack.fromJson(j), throwsA(isA<PackFormatException>()));
    });
  });
}
