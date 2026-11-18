import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

import 'premise_test.dart' show basePack;

void main() {
  group('CatalogEntry', () {
    final entry = CatalogEntry.fromJson({
      'id': 't:p',
      'titulo': 'El farol',
      'edad': '4-5',
      'valor': 'm1',
      'semilla': 7,
      'heroe': 'Ana',
      'generoHeroe': 'f',
      'caracteres': 120,
    });

    test('se lee del catálogo', () {
      expect(entry.id, 't:p');
      expect(entry.packId, 't');
      expect(entry.premiseId, 'p');
      expect(entry.seed, 7);
      expect(entry.heroName, 'Ana');
      expect(entry.heroGender, 'f');
      expect(entry.title, 'El farol');
    });

    test(
        'las opciones son las fijas: semilla, premisa y género; sin nombre, sin edad y sin preguntas',
        () {
      final o = entry.options();
      expect(o.seed, 7);
      expect(o.premiseId, 'p');
      expect(o.heroGender, 'f');
      expect(o.heroName, isNull);
      expect(o.age, isNull);
      expect(o.valueId, isNull);
      expect(o.interactive, isFalse);
      expect(o.choices, isEmpty);
    });

    test('un id sin «paquete:premisa» no se acepta', () {
      expect(
        () => CatalogEntry.fromJson({'id': 'sinpremisa', 'semilla': 1}),
        throwsFormatException,
      );
      expect(
        () => CatalogEntry.fromJson({'id': 'a:', 'semilla': 1}),
        throwsFormatException,
      );
    });

    test('el cuento sale siempre igual y lleva su clave', () {
      final engine = StoryEngine(Pack.fromJson(basePack()));
      final a = engine.generate(entry.options());
      final b = engine.generate(entry.options());
      expect(a.scenes.map((s) => s.text), b.scenes.map((s) => s.text));
      expect(a.title, b.title);
      expect(a.premiseId, 'p');
      expect(a.catalogId, 't:p');
      expect(CatalogEntry.heroOf(a), 'Ana');
      expect(engine.begin(entry.options()).isComplete, isTrue);
    });
  });

  group('FixedCatalog', () {
    test('se lee con su lista de gratis y se busca por id', () {
      final c = FixedCatalog.fromJson({
        'version': '1.0',
        'idioma': 'es',
        'gratis': ['a:x'],
        'cuentos': [
          {'id': 'a:x', 'semilla': 1},
          {'id': 'b:y', 'semilla': 2, 'generoHeroe': 'm'},
        ],
      });
      expect(c.version, '1.0');
      expect(c.language, 'es');
      expect(c.free, ['a:x']);
      expect(c.entries.map((e) => e.id), ['a:x', 'b:y']);
      expect(c.byId('b:y')!.heroGender, 'm');
      expect(c.entryFor('a', 'x')!.seed, 1);
      expect(c.contains('c:z'), isFalse);
      expect(FixedCatalog.empty.isEmpty, isTrue);
    });

    test('el catálogo del lanzamiento se lee y sus gratis están en él', () {
      final file = File('../../content/catalogo/lanzamiento-es.json');
      final c = FixedCatalog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
      );
      expect(c.entries.length, greaterThanOrEqualTo(50));
      expect(
        c.entries.map((e) => e.id).toSet().length,
        c.entries.length,
        reason: 'sin cuentos repetidos',
      );
      expect(c.free, hasLength(3));
      for (final f in c.free) {
        expect(c.contains(f), isTrue, reason: f);
      }
      for (final e in c.entries) {
        expect(e.heroGender, anyOf('m', 'f'), reason: e.id);
      }
    });
    test('los que entraron en la versión actual («desde») son los nuevos', () {
      final c = FixedCatalog.fromJson({
        'version': '1.2',
        'cuentos': [
          {'id': 'a:x', 'semilla': 1},
          {'id': 'a:y', 'semilla': 2, 'desde': '1.1'},
          {'id': 'b:z', 'semilla': 3, 'desde': '1.2'},
        ],
      });
      expect(c.newIds, ['b:z']);
      expect(c.byId('a:y')!.since, '1.1');
      expect(c.byId('a:y')!.isNew, isFalse);
      expect(c.byId('a:x')!.since, isNull);
    });

    test('las versiones se comparan por números, no como texto', () {
      expect(compareVersions('1.10', '1.9'), greaterThan(0));
      expect(compareVersions('1.1', '1.1.0'), 0);
      expect(compareVersions('1.1', '2'), lessThan(0));
      expect(compareVersions('', '1.0'), lessThan(0));
    });
  });
}
