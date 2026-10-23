import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/home_page.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

final _bundle = FileBundle();

FeedbackService _feedback() => FeedbackService(store: MemoryFeedbackStore());

void main() {
  test(
      'la app recuerda el paquete abierto (y vuelve al medieval al borrarlo todo)',
      () async {
    final store = MemorySettingsStore();
    final a = AppSettings(store);
    await a.load();
    expect(a.packId, 'medieval');
    expect(store.value, isNot(contains('paquete')),
        reason: 'el de siempre no hace falta guardarlo');
    await a.setPack('mar');
    final b = AppSettings(store);
    await b.load();
    expect(b.packId, 'mar');
    expect(b.exportJson()['paquete'], 'mar');
    await b.resetAll();
    expect(b.packId, 'medieval');
  });

  group('varios paquetes', () {
    Future<StoryShelf> openApp(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final shelf = StoryShelf(MemoryShelfStore());
      await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        seedProvider: () =>
            1, // con la 1 «Sorpréndeme» caía en una enseñanza sin cuentos
        feedback: _feedback(),
        shelf: shelf,
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      return shelf;
    }

    AppSettings settingsOf(WidgetTester tester) =>
        SettingsScope.maybeOf(tester.element(find.byType(HomePage)))!;

    Future<void> openPack(WidgetTester tester, String name) async {
      await tester.tap(find.text('Paquetes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'abrir el Mar de las Estrellas cuenta sus cuentos; uno guardado se vuelve a contar con su paquete',
        (tester) async {
      final shelf = await openApp(tester);
      await openPack(tester, 'Mar de las Estrellas');
      expect(settingsOf(tester).packId, 'mar');
      expect(find.text('¿Qué quieres aprender hoy?'), findsOneWidget);
      // Se elige una enseñanza del paquete y sale su cuento
      await tester.ensureVisible(find.text('Amistad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amistad'));
      await tester.pump();

      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      expect(find.text('La caracola de Nácar'), findsWidgets);
      expect(shelf.recent.first.packId, 'mar');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Con el medieval abierto, el cuento pirata guardado sigue siendo pirata
      await openPack(tester, 'Reino de la Luna');
      expect(settingsOf(tester).packId, 'medieval');
      await tester.tap(find.text('Mis cuentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('La caracola de Nácar').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Nácar'), findsWidgets);
      expect(shelf.recent.first.packId, 'mar');
    });

    testWidgets('en «Paquetes» el abierto lleva su marca', (tester) async {
      await openApp(tester);
      await openPack(tester, 'Mar de las Estrellas');
      await tester.tap(find.text('Paquetes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pack-open-mar')), findsOneWidget);
      expect(find.byKey(const Key('pack-open-medieval')), findsNothing);
    });
  });
}
