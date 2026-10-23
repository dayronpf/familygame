import 'dart:convert';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/brand.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/legal/legal_page.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/ui/wizard_page.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

final _bundle = FileBundle();

ShelfEntry _entry() => const ShelfEntry(
      seed: 7,
      option: null,
      title: 'La linterna apagada',
      moral: 'Valentía',
      moralId: 'valentia',
      hero: 'Aldo',
      packId: 'medieval',
      day: '2026-10-12',
      heroName: 'Nicolás',
      choices: ['oido'],
    );

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 2200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('textos legales', () {
    test('los marcadores se sustituyen y no queda ninguno', () async {
      for (final name in [
        'politica-de-privacidad.es.md',
        'terminos-de-uso.es.md',
      ]) {
        final raw = await _bundle.loadString('assets/legal/$name');
        final text = fillLegal(raw);
        expect(text, isNot(contains('{{')), reason: name);
        expect(text, contains(appName), reason: name);
        expect(text, contains(contactEmail), reason: name);
      }
    });

    test('la política dice lo que de verdad hace la app', () async {
      final text = fillLegal(
        await _bundle.loadString('assets/legal/politica-de-privacidad.es.md'),
      );
      // Sin anuncios ni cuentas; nada de datos de niños; el envío es opcional y anónimo
      expect(text, contains('sin cuenta, sin anuncios'));
      expect(text, contains('Ayudar a mejorar los cuentos'));
      expect(text, contains('Nunca se envía el nombre ni la edad'));
      expect(text, contains('Borrar los datos de este teléfono'));
      expect(text, contains('Hoy la app todavía no tiene servidor'),
          reason: 'mientras no haya servidor, nada sale del teléfono');
    });

    testWidgets('la pantalla enseña el texto y avisa de que es de prueba',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: LegalPage(
          title: 'Política de privacidad',
          asset: 'assets/legal/politica-de-privacidad.es.md',
          bundle: _bundle,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Política de privacidad de $appName'), findsOneWidget);
      expect(find.byKey(const Key('legal-pending')), findsOneWidget);
      expect(find.textContaining('En pocas palabras'), findsOneWidget);
    });
  });

  group('en Ajustes', () {
    Future<(AppSettings, StoryShelf, FeedbackService, MemoryFeedbackStore)>
        openSettings(WidgetTester tester) async {
      phone(tester);
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(age: '6-8', name: 'Nicolás');
      final shelf = StoryShelf(MemoryShelfStore());
      await shelf.addRecent(_entry());
      await shelf.toggleFavorite(_entry());
      final store = MemoryFeedbackStore();
      final feedback = FeedbackService(store: store);
      store.queue.add({'id': 'x', 'rating': 4});
      await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        seedProvider: () => 5,
        feedback: feedback,
        settings: settings,
        shelf: shelf,
        showWizard: true,
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) por (\d)').firstMatch(q)!;
      await tester.enterText(find.byKey(const Key('gate-answer')),
          '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();
      return (settings, shelf, feedback, store);
    }

    Future<void> scrollTo(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('la política y los términos se abren desde Ajustes',
        (tester) async {
      await openSettings(tester);
      await scrollTo(tester, 'settings-privacy');
      await tester.tap(find.byKey(const Key('settings-privacy')));
      await tester.pumpAndSettle();
      expect(find.text('Política de privacidad de $appName'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await scrollTo(tester, 'settings-terms');
      await tester.tap(find.byKey(const Key('settings-terms')));
      await tester.pumpAndSettle();
      expect(find.text('Términos de uso de $appName'), findsOneWidget);
    });

    testWidgets('«Ver mis datos» enseña lo guardado, tal cual', (tester) async {
      await openSettings(tester);
      await scrollTo(tester, 'settings-my-data');
      await tester.tap(find.byKey(const Key('settings-my-data')));
      await tester.pumpAndSettle();
      final json = tester
          .widget<SelectableText>(find.byKey(const Key('my-data-json')))
          .data!;
      final data = jsonDecode(json) as Map<String, Object?>;
      expect(
          data.keys, containsAll(['ajustes', 'mis_cuentos', 'valoraciones']));
      expect(json, contains('Nicolás'));
      expect(json, contains('La linterna apagada'));
      expect(
        ((data['valoraciones']! as Map)['valoraciones_pendientes'] as List),
        hasLength(1),
      );
    });

    testWidgets(
        '«Borrar los datos» pide confirmar y deja todo como la primera '
        'vez', (tester) async {
      final (settings, shelf, _, store) = await openSettings(tester);
      await scrollTo(tester, 'settings-delete-data');
      await tester.tap(find.byKey(const Key('settings-delete-data')));
      await tester.pumpAndSettle();
      // Cancelar no borra nada
      await tester.tap(find.byKey(const Key('delete-cancel')));
      await tester.pumpAndSettle();
      expect(shelf.recent, isNotEmpty);
      expect(settings.child.heroName, 'Nicolás');

      await tester.tap(find.byKey(const Key('settings-delete-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();

      expect(settings.child.heroName, isNull);
      expect(settings.wizardDone, isFalse);
      expect(settings.profiles, hasLength(1));
      expect(shelf.recent, isEmpty);
      expect(shelf.favorites, isEmpty);
      expect(store.queue, isEmpty);
      expect(find.byType(WizardPage), findsOneWidget,
          reason: 'vuelve al asistente de bienvenida');
    });

    test('lo borrado también se borra de lo guardado', () async {
      final store = MemorySettingsStore();
      final settings = AppSettings(store);
      await settings.completeWizard(age: '6-8', name: 'Nicolás');
      expect(store.value, contains('Nicolás'));
      await settings.resetAll();
      expect(store.value, isNot(contains('Nicolás')));
      final again = AppSettings(store);
      await again.load();
      expect(again.wizardDone, isFalse);
      expect(again.child.heroName, isNull);
    });
  });

  test('el motor y la app usan el mismo texto de lo que se envía', () {
    // La receta puede llevar los caminos elegidos y la política los menciona
    final r = StoryRecipe(
      packId: 'medieval',
      packVersion: '0.15.2',
      engineVersion: engineVersion,
      seed: 1,
      valueId: 'valentia',
      cast: const {'hero': 'aldo'},
      fragmentIds: const ['linterna.la_luz.a'],
      choices: const [RecipeChoice('linterna.camino.oido', auto: false)],
    );
    expect(jsonEncode(r.toJson()), isNot(contains('Nicolás')));
  });
}
