import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

final _bundle = FileBundle();

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<(AppSettings, StoryShelf, FeedbackService)> openApp(
    WidgetTester tester,
    AppSettings settings, {
    StoryShelf? shelf,
  }) async {
    phone(tester);
    final s = shelf ?? StoryShelf(MemoryShelfStore());
    final feedback = FeedbackService(store: MemoryFeedbackStore());
    await tester.pumpWidget(CalderoApp(
      bundle: _bundle,
      seedProvider: () => 5,
      feedback: feedback,
      settings: settings,
      shelf: s,
      showWizard: false,
      animateArt: false,
    ));
    await tester.pumpAndSettle();
    return (settings, s, feedback);
  }

  group('el nombre del niño en el cuento', () {
    testWidgets('el cuento lo nombra, se guarda con él y se cuenta igual',
        (tester) async {
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(
        age: '4-5',
        name: ' valentina ',
        heroGender: 'f',
      );
      final (_, shelf, _) = await openApp(tester, settings);

      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Valentina'),
        300,
      );
      expect(find.textContaining('Valentina'), findsWidgets);
      // los héroes del pack no se cuelan
      expect(find.textContaining('Aldo'), findsNothing);

      final entry = shelf.recent.first;
      expect(entry.heroName, 'Valentina');
      expect(entry.heroGender, 'f');
      expect(entry.age, '4-5');
      expect(entry.hero, 'Valentina');

      // y se vuelve a contar igual desde «Mis cuentos»
      await tester.pageBack();
      await tester.pumpAndSettle();
      // el niño cambia de nombre: el cuento guardado conserva el suyo
      await settings.updateChild(name: 'Mateo', heroGender: 'm');
      await tester.tap(find.text('Mis cuentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.title).first);
      await tester.pumpAndSettle();
      expect(shelf.recent.first.key, entry.key);
      expect(shelf.recent.first.heroName, 'Valentina');
    });

    testWidgets('sin nombre se cuenta como siempre, con Aldo o Mara',
        (tester) async {
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(age: '6-8');
      final (_, shelf, _) = await openApp(tester, settings);
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      expect(shelf.recent.first.heroName, isNull);
      expect(shelf.recent.first.hero, anyOf('Aldo', 'Mara'));
    });

    test('el estante guarda con qué se contó cada cuento y lee los antiguos',
        () {
      final e = ShelfEntry(
        seed: 1,
        option: null,
        title: 't',
        moral: 'm',
        moralId: 'honestidad',
        hero: 'Valentina',
        packId: 'medieval',
        day: '2026-10-11',
        age: '4-5',
        heroName: 'Valentina',
        heroGender: 'f',
      );
      // se guarda y se lee con todo; claves distintas para distintos protagonistas
      final back = ShelfEntry.fromJson(e.toJson());
      expect(back.heroName, 'Valentina');
      expect(back.key, e.key);
      final other = ShelfEntry.fromJson({...e.toJson(), 'heroName': 'Mateo'});
      expect(other.key, isNot(e.key));
      // los estantes antiguos (sin edad ni nombre) se siguen leyendo
      final old = ShelfEntry.fromJson({
        'seed': 3,
        'option': null,
        'title': 'La campana',
        'moral': 'Honestidad',
        'day': '2026-10-01',
      });
      expect(old.age, isNull);
      expect(old.heroName, isNull);
    });
  });

  group('ajustes: protagonista', () {
    testWidgets('el nombre y el género se editan y se guardan', (tester) async {
      final store = MemorySettingsStore();
      final settings = AppSettings(store);
      await settings.completeWizard();
      await openApp(tester, settings);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) por (\d)').firstMatch(q)!;
      await tester.enterText(find.byKey(const Key('gate-answer')),
          '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('setting-name')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('setting-name')), 'Lucía');
      await tester.ensureVisible(find.byKey(const Key('setting-gender')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byKey(const Key('setting-gender')),
        matching: find.text('Niña'),
      ));
      await tester.pumpAndSettle();
      expect(settings.child.name, 'Lucía');
      expect(settings.child.heroGender, 'f');

      // se lee de nuevo desde el almacén
      final again = AppSettings(store);
      await again.load();
      expect(again.child.heroName, 'Lucía');
      expect(again.child.heroGender, 'f');

      // Con nombre no hay «Al azar»: el cuento no puede decidir si Lucía es niño o niña
      expect(
        find.descendant(
          of: find.byKey(const Key('setting-gender')),
          matching: find.text('Al azar'),
        ),
        findsNothing,
      );

      // Sin nombre, «Al azar» vuelve a dejar que decida el cuento
      await tester.enterText(find.byKey(const Key('setting-name')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byKey(const Key('setting-gender')),
        matching: find.text('Al azar'),
      ));
      await tester.pumpAndSettle();
      expect(settings.child.heroGender, isNull);
    });

    testWidgets('«Preguntas en el cuento» se apaga y se guarda por niño',
        (tester) async {
      final store = MemorySettingsStore();
      final settings = AppSettings(store);
      await settings.completeWizard();
      await settings.updateChild(age: '6-8');
      await openApp(tester, settings);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) por (\d)').firstMatch(q)!;
      await tester.enterText(find.byKey(const Key('gate-answer')),
          '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('setting-questions')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(settings.child.asksQuestions, isTrue);
      await tester.tap(find.byKey(const Key('setting-questions')));
      await tester.pumpAndSettle();
      expect(settings.child.asksQuestions, isFalse);
      expect(find.textContaining('la app elige el camino'), findsOneWidget);

      final again = AppSettings(store);
      await again.load();
      expect(again.child.asksQuestions, isFalse);
    });

    test('el perfil sin nombre ni género sigue igual y lee ajustes antiguos',
        () {
      expect(const ChildProfile().heroName, isNull);
      expect(const ChildProfile(name: '  ').heroName, isNull);
      final old =
          ChildProfile.fromJson(const {'id': 'principal', 'edad': '4-5'});
      expect(old.name, '');
      expect(old.heroGender, isNull);
      final p =
          const ChildProfile().copyWith(heroGender: 'm').copyWith(name: 'Leo');
      expect(p.heroGender, 'm');
      expect(p.copyWith(heroGender: null).heroGender, isNull);
    });
  });
}
