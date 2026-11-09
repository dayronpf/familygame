import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/catalog/story_catalog.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

Pack _pack(String id) => Pack.fromJson(
      jsonDecode(File('assets/packs/$id/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );

StoryCatalog _catalog() => StoryCatalog.fromPacks(
      {
        for (final id in ['medieval', 'mar', 'cosmos']) id: _pack(id)
      },
    );

void main() {
  group('catálogo', () {
    test('cada premisa de los paquetes abiertos es un cuento', () {
      final c = _catalog();
      final expected = ['medieval', 'mar', 'cosmos']
          .map((id) => _pack(id).premises.length)
          .reduce((a, b) => a + b);
      expect(c.stories.length, expected);
      expect(c.stories.map((s) => s.key).toSet().length, expected);
      for (final s in c.stories) {
        expect(s.minutes, inInclusiveRange(2, 20), reason: s.key);
        expect(s.title.contains('{'), isFalse, reason: s.key);
      }
    });

    test('la búsqueda no distingue tildes ni mayúsculas', () {
      final c = _catalog();
      final a = c.search('VALENTIA');
      final b = c.search('valentía');
      expect(a, isNotEmpty);
      expect(a.map((s) => s.key), b.map((s) => s.key));
      expect(
          a.every((s) =>
              s.moral?.id == 'valentia' || s.searchText.contains('valentia')),
          isTrue);
      expect(c.search('   '), isEmpty);
      expect(c.search('zzzz'), isEmpty);
    });

    test(
        'categorías: por edad, cortos, por enseñanza y por paquete; ninguna vacía',
        () {
      final cats = _catalog().categories;
      final ids = cats.map((c) => c.id).toSet();
      expect(ids, containsAll(['age:2-3', 'age:4-5', 'age:6-8', 'short']));
      expect(ids, containsAll(['moral:amistad', 'pack:medieval', 'pack:mar']));
      for (final c in cats) {
        expect(c.stories, isNotEmpty, reason: c.id);
      }
      final short = cats.firstWhere((c) => c.id == 'short');
      expect(short.stories.every((s) => s.minutes <= StoryCatalog.shortMinutes),
          isTrue);
    });

    test('novedades: los cuentos del paquete nuevo', () {
      final c = _catalog();
      expect(c.newest, isNotEmpty);
      expect(c.newest.every((s) => s.info.isNew), isTrue);
    });

    test('la vista previa de la ficha es el mismo cuento que se lee', () {
      final s =
          _catalog().stories.firstWhere((s) => s.premise.ages.contains('4-5'));
      final engine = StoryEngine(s.pack);
      final a = engine.generate(
          s.options(childAge: '4-5', heroName: 'Ana', heroGender: 'f'));
      final b = engine.generate(
          s.options(childAge: '4-5', heroName: 'Ana', heroGender: 'f'));
      expect(a.scenes.first.text, b.scenes.first.text);
      expect(a.recipe.fragmentIds.first, startsWith('${s.premise.id}.'));
    });

    test(
        'con nombre y género, solo los cuentos cuyo héroe puede ser de ese género',
        () {
      final c = _catalog();
      final girl = c.forChild(heroName: 'Ana', heroGender: 'f');
      for (final s in girl.stories) {
        expect(heroCanBe(s.pack, s.premise, 'f'), isTrue, reason: s.key);
      }
      expect(c.forChild().stories.length, c.stories.length);
    });
  });

  group('estante', () {
    test('guarda la premisa y lo leído hasta el final', () async {
      final store = MemoryShelfStore();
      final shelf = StoryShelf(store);
      await shelf.load();
      const a = ShelfEntry(
        seed: 1,
        option: 'amistad',
        title: 'T',
        moral: 'Amistad',
        moralId: 'amistad',
        hero: 'Lía',
        packId: 'medieval',
        day: '2026-11-08',
        premiseId: 'cinta_de_lia',
      );
      await shelf.addRecent(a);
      expect(shelf.isFinished(a), isFalse);
      await shelf.markFinished(a);
      final again = StoryShelf(store);
      await again.load();
      expect(again.recent.single.premiseId, 'cinta_de_lia');
      expect(again.isFinished(again.recent.single), isTrue);
      // Sin premisa es otro cuento (el caldero eligió)
      final b = ShelfEntry.fromJson({...a.toJson()}..remove('premise'));
      expect(b.key, isNot(a.key));
      expect(again.isFinished(b), isFalse);
    });
  });

  group('Explorar', () {
    testWidgets(
        'categoría → ficha → Leer abre el cuento elegido y queda «sin terminar»',
        (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final shelf = StoryShelf(MemoryShelfStore());
      await tester.pumpWidget(CalderoApp(
        bundle: FileBundle(),
        seedProvider: () => 3,
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        shelf: shelf,
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      expect(find.text('Novedades'), findsOneWidget);
      expect(find.text('Categorías'), findsOneWidget);

      final cat = find.byKey(const Key('category-pack:medieval'));
      await tester.scrollUntilVisible(cat, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(cat);
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('story-row-medieval:campana'));
      await tester.scrollUntilVisible(row, 300,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('La campana rota'), findsWidgets);
      expect(find.byKey(const Key('detail-read')), findsOneWidget);
      expect(find.byKey(const Key('detail-listen')), findsOneWidget);
      expect(find.byKey(const Key('detail-synopsis')), findsOneWidget);

      await tester.tap(find.byKey(const Key('detail-read')));
      await tester.pumpAndSettle();
      expect(shelf.recent.first.premiseId, 'campana');
      expect(shelf.recent.first.title, 'La campana rota');
      expect(shelf.isFinished(shelf.recent.first), isFalse);
    });

    testWidgets('buscar encuentra cuentos y dice cuando no hay',
        (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CalderoApp(
        bundle: FileBundle(),
        seedProvider: () => 3,
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        shelf: StoryShelf(MemoryShelfStore()),
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('explore-search')), 'campana');
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('story-row-medieval:campana')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('explore-search')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No encontramos'), findsOneWidget);
    });
  });
}
