import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/catalog/story_catalog.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/home/news.dart';
import 'package:caldero_app/src/progress/reading_progress.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

Pack _pack(String id) => Pack.fromJson(
      jsonDecode(File('assets/packs/$id/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );

void main() {
  group('progreso', () {
    test(
        'suma cuentos, minutos, noches y enseñanzas; los premios se ganan una vez',
        () async {
      final store = MemoryShelfStore();
      final p = ReadingProgress(store);
      final first = await p.recordFinished(
          childId: 'a',
          moralId: 'amistad',
          packId: 'medieval',
          minutes: 7,
          now: DateTime(2026, 11, 2));
      expect(first.map((a) => a.id), ['semilla']);
      final again = await p.recordFinished(
          childId: 'a',
          moralId: 'amistad',
          packId: 'medieval',
          minutes: 5,
          now: DateTime(2026, 11, 2));
      expect(again, isEmpty);
      final c = p.of('a');
      expect(c.stories, 2);
      expect(c.minutes, 12);
      expect(c.days, ['2026-11-02'],
          reason: 'una noche aunque sean dos cuentos');
      expect(c.morals['amistad'], 2);
      // Otro niño empieza de cero
      expect(p.of('b').stories, 0);
      // Se guarda y se vuelve a leer igual
      final loaded = ReadingProgress(store);
      await loaded.load();
      expect(loaded.of('a').earned.keys, ['semilla']);
      expect(loaded.of('a').minutes, 12);
    });

    test('una semana con cuento son 3 noches de lunes a domingo', () async {
      final p = ReadingProgress(MemoryShelfStore());
      Future<List<Award>> night(DateTime d) => p.recordFinished(
          childId: null,
          moralId: 'valentia',
          packId: 'mar',
          minutes: 3,
          now: d);
      await night(DateTime(2026, 11, 2)); // lunes
      await night(DateTime(2026, 11, 4));
      expect(p.of(null).storyWeeks, 0);
      // El domingo es de la misma semana; el lunes siguiente, de otra
      final fresh = await night(DateTime(2026, 11, 8));
      expect(p.of(null).storyWeeks, 1);
      expect(fresh.map((a) => a.id), contains('semana_luna'));
      await night(DateTime(2026, 11, 9));
      expect(weekKey(DateTime(2026, 11, 9)), '2026-11-09');
      expect(p.of(null).storyWeeks, 1);
    });

    test('las 6 enseñanzas, 3 paquetes y 10 lecturas juntos dan sus premios',
        () async {
      final p = ReadingProgress(MemoryShelfStore());
      final morals = [
        'honestidad',
        'generosidad',
        'valentia',
        'humildad',
        'perseverancia',
        'amistad'
      ];
      final packs = ['medieval', 'mar', 'cosmos'];
      for (var i = 0; i < 10; i++) {
        await p.recordFinished(
            childId: 'x',
            moralId: morals[i % 6],
            packId: packs[i % 3],
            minutes: 7,
            together: true,
            now: DateTime(2026, 11, 1 + i));
      }
      final earned = p.of('x').earned.keys.toSet();
      expect(earned,
          containsAll(['corazon_sabio', 'viajero', 'farol', 'reloj', 'brote']));
      expect(earned, isNot(contains('arbolito')));
    });

    test('borrar un niño o todo borra su progreso', () async {
      final p = ReadingProgress(MemoryShelfStore());
      await p.recordFinished(
          childId: 'a', moralId: 'amistad', packId: 'mar', minutes: 2);
      await p.removeChild('a');
      expect(p.of('a').stories, 0);
      await p.recordFinished(
          childId: 'b', moralId: 'amistad', packId: 'mar', minutes: 2);
      await p.clearAll();
      expect(p.exportJson(), isEmpty);
    });
  });

  group('recomendación', () {
    final catalog = StoryCatalog.fromPacks({
      for (final id in ['medieval', 'mar', 'cosmos']) id: _pack(id)
    });

    test('es la misma todo el día, sirve a la edad y evita lo ya contado', () {
      final a =
          recommend(catalog, childAge: '4-5', childId: 'n', day: '2026-11-08');
      final b =
          recommend(catalog, childAge: '4-5', childId: 'n', day: '2026-11-08');
      expect(a.map((s) => s.key), b.map((s) => s.key));
      expect(a, hasLength(3));
      expect(a.every((s) => s.premise.fitsAge('4-5')), isTrue);
      final told = a.first;
      final after = recommend(catalog,
          childAge: '4-5',
          childId: 'n',
          day: '2026-11-08',
          recent: [
            (
              premiseId: told.premise.id,
              packId: told.pack.id,
              moralId: told.moral!.id
            )
          ]);
      expect(after.map((s) => s.key), isNot(contains(told.key)));
    });
  });

  group('ajustes nuevos', () {
    test('ilustraciones, celebración y avisos cerrados se guardan', () async {
      final store = MemorySettingsStore();
      final a = AppSettings(store);
      await a.load();
      expect(a.animatedArt, isTrue);
      expect(a.celebrateAwards, isTrue);
      await a.setAnimatedArt(false);
      await a.setCelebrateAwards(false);
      await a.dismissNews(newsItems.first.id);
      final b = AppSettings(store);
      await b.load();
      expect(b.animatedArt, isFalse);
      expect(b.celebrateAwards, isFalse);
      expect(b.dismissedNews, [newsItems.first.id]);
      await b.resetAll();
      expect(b.animatedArt, isTrue);
      expect(b.dismissedNews, isEmpty);
    });
  });

  group('en la app', () {
    Future<(StoryShelf, ReadingProgress, AppSettings)> openApp(
        WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final shelf = StoryShelf(MemoryShelfStore());
      final progress = ReadingProgress(MemoryShelfStore());
      final settings = AppSettings(MemorySettingsStore());
      await settings.load();
      await tester.pumpWidget(CalderoApp(
        bundle: FileBundle(),
        seedProvider: () => 3,
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        shelf: shelf,
        progress: progress,
        settings: settings,
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      return (shelf, progress, settings);
    }

    testWidgets(
        'leer hasta el final suma al progreso, da la primera semilla y se ve en Premios',
        (tester) async {
      final (shelf, progress, _) = await openApp(tester);
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      final end = find.byKey(const Key('award-celebration'));
      await tester.scrollUntilVisible(end, 600,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(end, findsOneWidget);
      expect(find.text('Primera semilla'), findsOneWidget);
      expect(
          progress
              .exportJson()
              .values
              .map((c) => (c! as Map<String, Object?>)['cuentos'])
              .single,
          1);
      expect(shelf.isFinished(shelf.recent.first), isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Premios'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stat-stories')), findsOneWidget);
      expect(find.textContaining('Premios (1 de'), findsOneWidget);
    });

    testWidgets('sin celebración el premio se guarda en silencio',
        (tester) async {
      final (_, progress, settings) = await openApp(tester);
      await settings.setCelebrateAwards(false);
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Contar otro cuento'), 600,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('award-celebration')), findsNothing);
      expect(progress.exportJson().values.single, isNotNull);
    });

    testWidgets('un aviso cerrado no vuelve', (tester) async {
      final (_, _, settings) = await openApp(tester);
      final first = newsItems.first;
      final close = find.byKey(Key('news-close-${first.id}'));
      // El carrusel está más abajo que las enseñanzas: se baja hasta que se arme
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(settings.dismissedNews, contains(first.id));
      expect(find.byKey(Key('news-${first.id}')), findsNothing);
    });
  });
}
