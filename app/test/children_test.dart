import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/ui/children_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

final _bundle = FileBundle();

ShelfEntry _entry(int seed, {String? childId, String? name}) => ShelfEntry(
      seed: seed,
      option: null,
      title: 'Cuento $seed',
      moral: 'Honestidad',
      moralId: 'honestidad',
      hero: name ?? 'Aldo',
      packId: 'medieval',
      day: '2026-10-11',
      heroName: name,
      childId: childId,
    );

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('varios niños (modelo)', () {
    test('empieza con uno solo y añadir deja activo al nuevo', () async {
      final s = AppSettings(MemorySettingsStore());
      await s.updateChild(
          voice: const TtsVoice(name: 'v', locale: 'es-ES'), age: '6-8');
      expect(s.profiles, hasLength(1));
      final i = await s.addChild(name: 'lucía', heroGender: 'f');
      expect(i, 1);
      expect(s.activeIndex, 1);
      expect(s.child.heroName, 'Lucía');
      expect(s.child.heroGender, 'f');
      // hereda lo que es del teléfono (voz, idioma, velocidad) y, si no se dice, la edad
      expect(s.child.voice, const TtsVoice(name: 'v', locale: 'es-ES'));
      expect(s.child.age, '6-8');
      expect(s.profiles[0].id, isNot(s.profiles[1].id));
    });

    test('se elige, se edita cualquiera y se quita (siempre queda uno)',
        () async {
      final s = AppSettings(MemorySettingsStore());
      await s.updateChild(name: 'Ana');
      await s.addChild(name: 'Beto');
      await s.addChild(name: 'Cleo');
      expect(s.profiles.map((p) => p.heroName), ['Ana', 'Beto', 'Cleo']);
      await s.selectChild(0);
      expect(s.child.heroName, 'Ana');
      await s.updateProfile(2, age: '2-3');
      expect(s.profiles[2].age, '2-3');
      expect(s.child.age, isNot('2-3'), reason: 'solo cambió a Cleo');

      // quitar al de antes del activo mantiene al mismo niño activo
      await s.selectChild(2);
      final gone = await s.removeChild(0);
      expect(gone, isNotNull);
      expect(s.child.heroName, 'Cleo');
      expect(s.activeIndex, 1);
      // quitar al activo pasa al que queda en su lugar
      await s.removeChild(1);
      expect(s.profiles.map((p) => p.heroName), ['Beto']);
      expect(s.child.heroName, 'Beto');
      expect(await s.removeChild(0), isNull, reason: 'el último no se quita');
      expect(s.profiles, hasLength(1));
    });

    test('hay un máximo y los nombres vacíos se llaman «Niño n»', () async {
      final s = AppSettings(MemorySettingsStore());
      for (var i = 1; i < AppSettings.maxChildren; i++) {
        expect(await s.addChild(), isNotNull);
      }
      expect(await s.addChild(), isNull);
      expect(s.profiles, hasLength(AppSettings.maxChildren));
      expect(s.profiles[2].label(2), 'Niño 3');
    });

    test('la lista y el activo se guardan y se leen de nuevo', () async {
      final store = MemorySettingsStore();
      final a = AppSettings(store);
      await a.completeWizard(name: 'Ana', age: '4-5');
      await a.addChild(name: 'Beto', age: '6-8', heroGender: 'm');
      final b = AppSettings(store);
      await b.load();
      expect(b.profiles.map((p) => p.heroName), ['Ana', 'Beto']);
      expect(b.activeIndex, 1);
      expect(b.child.age, '6-8');
      expect(b.child.heroGender, 'm');
    });
  });

  group('el estante de cada niño', () {
    test('cada niño ve solo lo suyo; lo antiguo lo ven todos', () async {
      final shelf = StoryShelf(MemoryShelfStore());
      await shelf.addRecent(_entry(1, childId: 'a'));
      await shelf.addRecent(_entry(2, childId: 'b'));
      await shelf.addRecent(_entry(3)); // de antes de los perfiles
      await shelf.toggleFavorite(_entry(1, childId: 'a'));
      shelf.viewer = 'a';
      expect(shelf.recent.map((e) => e.seed), [3, 2, 1].where((s) => s != 2));
      expect(shelf.favorites.map((e) => e.seed), [1]);
      shelf.viewer = 'b';
      expect(shelf.recent.map((e) => e.seed), [3, 2]);
      expect(shelf.favorites, isEmpty);
      shelf.viewer = null;
      expect(shelf.recent, hasLength(3));
    });

    test('el mismo cuento guardado por dos niños no se pisa', () async {
      final shelf = StoryShelf(MemoryShelfStore());
      await shelf.toggleFavorite(_entry(5, childId: 'a'));
      expect(shelf.isFavorite(_entry(5, childId: 'b')), isFalse);
      await shelf.toggleFavorite(_entry(5, childId: 'b'));
      shelf.viewer = null;
      expect(shelf.favorites, hasLength(2));
    });

    test('al quitar a un niño se borra lo que guardó y se recuerda', () async {
      final store = MemoryShelfStore();
      final shelf = StoryShelf(store);
      await shelf.addRecent(_entry(1, childId: 'a'));
      await shelf.addRecent(_entry(2, childId: 'b'));
      await shelf.toggleFavorite(_entry(2, childId: 'b'));
      await shelf.removeChild('b');
      final again = StoryShelf(store);
      await again.load();
      expect(again.recent.map((e) => e.seed), [1]);
      expect(again.favorites, isEmpty);
    });

    test('un estante sin niño (de antes) se lee igual', () {
      final e = ShelfEntry.fromJson({
        'seed': 3,
        'option': null,
        'title': 'La campana',
        'moral': 'Honestidad',
        'day': '2026-10-01',
      });
      expect(e.childId, isNull);
    });
  });

  group('pantalla «Niños»', () {
    Future<(AppSettings, StoryShelf)> open(WidgetTester tester,
        {List<String> names = const ['Ana']}) async {
      phone(tester);
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(name: names.first);
      for (final n in names.skip(1)) {
        await settings.addChild(name: n);
      }
      final shelf = StoryShelf(MemoryShelfStore());
      await tester.pumpWidget(MaterialApp(
        home: ChildrenPage(settings: settings, shelf: shelf),
      ));
      await tester.pump();
      return (settings, shelf);
    }

    testWidgets('lista a los niños y toca para elegir a uno', (tester) async {
      final (settings, _) = await open(tester, names: ['Ana', 'Beto']);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(settings.child.heroName, 'Beto');
      await tester.tap(find.text('Ana'));
      await tester.pump();
      expect(settings.child.heroName, 'Ana');
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('añadir a un niño pide nombre, edad y protagonista',
        (tester) async {
      final (settings, _) = await open(tester);
      await tester.tap(find.byKey(const Key('child-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('child-name')), ' mateo 7 ');
      await tester.tap(find.byKey(const Key('child-age-2-3')));
      await tester.tap(find.byKey(const Key('child-gender-m')));
      await tester.tap(find.byKey(const Key('child-save')));
      await tester.pumpAndSettle();
      expect(settings.profiles, hasLength(2));
      expect(settings.child.heroName, 'Mateo');
      expect(settings.child.age, '2-3');
      expect(settings.child.heroGender, 'm');
      expect(find.text('Mateo'), findsOneWidget);
    });

    testWidgets('cancelar al añadir no cambia nada', (tester) async {
      final (settings, _) = await open(tester);
      await tester.tap(find.byKey(const Key('child-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child-cancel')));
      await tester.pumpAndSettle();
      expect(settings.profiles, hasLength(1));
    });

    testWidgets('se edita a un niño desde su menú', (tester) async {
      final (settings, _) = await open(tester, names: ['Ana', 'Beto']);
      await tester
          .tap(find.byKey(Key('child-menu-${settings.profiles[0].id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('child-name')), 'Anita');
      await tester.tap(find.byKey(const Key('child-gender-f')));
      await tester.tap(find.byKey(const Key('child-save')));
      await tester.pumpAndSettle();
      expect(settings.profiles[0].heroName, 'Anita');
      expect(settings.profiles[0].heroGender, 'f');
      expect(settings.profiles[1].heroName, 'Beto');
    });

    testWidgets('quitar pide confirmar y borra lo que guardó', (tester) async {
      final (settings, shelf) = await open(tester, names: ['Ana', 'Beto']);
      await shelf.addRecent(_entry(1, childId: settings.profiles[0].id));
      await shelf.addRecent(_entry(2, childId: settings.profiles[1].id));
      await tester
          .tap(find.byKey(Key('child-menu-${settings.profiles[0].id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      // primero se cancela
      await tester.tap(find.byKey(const Key('child-remove-cancel')));
      await tester.pumpAndSettle();
      expect(settings.profiles, hasLength(2));
      await tester
          .tap(find.byKey(Key('child-menu-${settings.profiles[0].id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('child-remove-ok')));
      await tester.pumpAndSettle();
      expect(settings.profiles.map((p) => p.heroName), ['Beto']);
      shelf.viewer = null;
      expect(shelf.recent.map((e) => e.seed), [2]);
    });

    testWidgets('el único niño no se puede quitar', (tester) async {
      final (settings, _) = await open(tester);
      await tester
          .tap(find.byKey(Key('child-menu-${settings.profiles[0].id}')));
      await tester.pumpAndSettle();
      expect(find.text('Quitar'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
    });
  });

  group('en el inicio', () {
    Future<AppSettings> openHome(WidgetTester tester,
        {List<String> names = const ['Ana']}) async {
      phone(tester);
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(name: names.first);
      for (final n in names.skip(1)) {
        await settings.addChild(name: n);
      }
      await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        seedProvider: () => 3,
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        settings: settings,
        showWizard: false,
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      return settings;
    }

    testWidgets('con un solo niño no hay selector y se le saluda por su nombre',
        (tester) async {
      await openHome(tester);
      expect(find.byKey(const Key('child-switch')), findsNothing);
      expect(find.textContaining('Ana'), findsWidgets);
    });

    testWidgets('con varios hay selector y cambiar de niño cambia el saludo',
        (tester) async {
      final settings = await openHome(tester, names: ['Ana', 'Beto']);
      expect(find.textContaining('Beto'), findsWidgets);
      await tester.tap(find.byKey(const Key('child-switch')));
      await tester.pumpAndSettle();
      expect(find.text('¿Para quién es el cuento?'), findsOneWidget);
      await tester.tap(find.byKey(Key('switch-${settings.profiles[0].id}')));
      await tester.pumpAndSettle();
      expect(settings.child.heroName, 'Ana');
      expect(find.textContaining('Hola, Ana'), findsOneWidget);
    });

    testWidgets(
        'el cuento se cuenta con el nombre del niño activo y se guarda a su nombre',
        (tester) async {
      final settings = await openHome(tester, names: ['Ana', 'Beto']);
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('Beto'), 300);
      expect(find.textContaining('Beto'), findsWidgets);
      expect(settings.child.heroName, 'Beto');
    });

    testWidgets(
        'Ajustes lleva a la pantalla «Niños» y el nombre sigue al activo',
        (tester) async {
      final settings = await openHome(tester, names: ['Ana', 'Beto']);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) × (\d)').firstMatch(q)!;
      await tester.enterText(find.byKey(const Key('gate-answer')),
          '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setting-children')), findsOneWidget);
      expect(find.textContaining('2 niños'), findsOneWidget);
      // el campo del nombre es el del niño activo
      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-name')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(
          tester
              .widget<TextField>(find.byKey(const Key('setting-name')))
              .controller!
              .text,
          'Beto');
      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-children')), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('setting-children')));
      await tester.pumpAndSettle();
      expect(find.text('Niños'), findsWidgets);
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(settings.child.heroName, 'Ana');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-name')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(
          tester
              .widget<TextField>(find.byKey(const Key('setting-name')))
              .controller!
              .text,
          'Ana');
    });
  });
}
