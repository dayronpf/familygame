import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/feedback/rating_event.dart';
import 'package:caldero_app/src/packs/pack_catalog.dart';
import 'package:caldero_app/src/share.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/ui/sleep_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

final _bundle = FileBundle();

FeedbackService _feedback() => FeedbackService(store: MemoryFeedbackStore());

ShelfEntry _entry(int seed, {String? option, String title = 'La campana'}) =>
    ShelfEntry(
      seed: seed,
      option: option,
      title: title,
      moral: 'Honestidad',
      moralId: 'honestidad',
      hero: 'Aldo',
      packId: 'medieval',
      day: '2026-10-10',
    );

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<StoryShelf> openApp(WidgetTester tester,
      {int seed = 3, StoryShelf? shelf}) async {
    phone(tester);
    final s = shelf ?? StoryShelf(MemoryShelfStore());
    await tester.pumpWidget(CalderoApp(
      bundle: _bundle,
      seedProvider: () => seed,
      feedback: _feedback(),
      shelf: s,
      animateArt: false,
    ));
    await tester.pumpAndSettle();
    return s;
  }

  group('splash', () {
    testWidgets(
        'con «reducir movimiento» no se queda colgado: cae en cuanto carga',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        feedback: _feedback(),
        shelf: StoryShelf(MemoryShelfStore()),
        animateArt: false, // equivale a «reducir movimiento»
        showSplash: true,
      ));
      for (var i = 0;
          i < 40 && find.text('Crear cuento').evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('splash-version')), findsNothing);
      expect(find.text('Crear cuento'), findsOneWidget);
    });

    testWidgets(
        'con animación: nombre y versión chiquita, y espera lo mínimo antes de caer',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        feedback: _feedback(),
        shelf: StoryShelf(MemoryShelfStore()),
        showSplash: true,
        splashMinimum: const Duration(seconds: 3),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('splash-version')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('splash-version'))).data,
          'v$appVersion');
      expect(find.text('Caldero de Cuentos'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('splash-version')), findsNothing);
    });
  });

  group('inicio', () {
    testWidgets('tiene tres pestañas, compartir y ajustes a la vista',
        (tester) async {
      await openApp(tester);
      for (final t in ['Inicio', 'Paquetes', 'Mis cuentos']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.byKey(const Key('share-app')), findsOneWidget);
      expect(find.byKey(const Key('open-settings')), findsOneWidget);
      expect(find.text('¿Qué quieres aprender hoy?'), findsOneWidget);
      // Sin desplazarse: las cuatro tarjetas y el botón grande caben en un teléfono.
      expect(find.text('Crear cuento'), findsOneWidget);
    });

    testWidgets(
        'recomendar a un amigo copia el mensaje si no se puede compartir',
        (tester) async {
      await openApp(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      // El teléfono no tiene menú de compartir: falla la llamada
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async => throw PlatformException(code: 'sin-menu'),
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'), null);
      });
      await tester.tap(find.byKey(const Key('share-app')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied, shareMessage);
      expect(copied, contains(appDownloadUrl));
      expect(find.textContaining('Copiamos el mensaje'), findsOneWidget);
    });
  });

  group('paquetes', () {
    testWidgets(
        'el Reino de la Luna se abre; los demás están en gris y «Pronto»',
        (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Paquetes'));
      await tester.pumpAndSettle();
      expect(find.text('Reino de la Luna'), findsOneWidget);
      expect(find.text('Tuyo'), findsOneWidget);
      final soon = packCatalog.where((p) => !p.available).toList();
      expect(soon.length, greaterThanOrEqualTo(3));
      // Solo hay un paquete disponible
      expect(
          packCatalog.where((p) => p.available).map((p) => p.id), ['medieval']);
      // Cada paquete que llega más adelante se dibuja con el filtro de grises
      expect(find.byType(ColorFiltered), findsAtLeastNWidgets(3));
      expect(find.text('Pronto'), findsAtLeastNWidgets(2));
      expect(
          find.byKey(const Key('share-card')), findsNothing); // aún más abajo
      await tester.scrollUntilVisible(find.byKey(const Key('share-card')), 300);
      expect(find.byKey(const Key('share-card')), findsOneWidget);
    });

    testWidgets('tocar el paquete abierto vuelve al inicio', (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Paquetes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reino de la Luna'));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué quieres aprender hoy?'), findsOneWidget);
    });

    testWidgets('un paquete que llegará explica que será de pago',
        (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Paquetes'));
      await tester.pumpAndSettle();
      final first = packCatalog.firstWhere((p) => !p.available);
      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();
      expect(find.textContaining('Próximamente.'), findsOneWidget);
      expect(find.text(first.description), findsOneWidget);
    });
  });

  group('mis cuentos', () {
    testWidgets('empieza vacío y explica cómo guardar', (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Mis cuentos'));
      await tester.pumpAndSettle();
      expect(find.text('Aquí vivirán tus cuentos'), findsOneWidget);
    });

    testWidgets(
        'el cuento se anota, se guarda con el corazón y se vuelve a oír',
        (tester) async {
      final shelf = await openApp(tester, seed: 5);
      await tester.tap(find.text('Honestidad'));
      await tester.pump();
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      expect(shelf.recent, hasLength(1));
      expect(shelf.recent.first.option, 'honestidad');
      expect(shelf.favorites, isEmpty);

      await tester.tap(find.byKey(const Key('favorite')));
      await tester.pumpAndSettle();
      expect(shelf.favorites, hasLength(1));
      final saved = shelf.favorites.first;

      await tester.pageBack();
      await tester.pumpAndSettle();
      // En el inicio aparece «Oír otra vez» con ese cuento
      expect(find.text('Oír otra vez'), findsOneWidget);
      await tester.tap(find.text('Mis cuentos'));
      await tester.pumpAndSettle();
      expect(find.text('Mis favoritos'), findsOneWidget);
      expect(find.text(saved.title), findsWidgets);

      // Tocar un cuento lo cuenta otra vez, igual (misma semilla y misma enseñanza)
      await tester.tap(find.text(saved.title).first);
      await tester.pumpAndSettle();
      expect(find.text(saved.moral), findsWidgets);
      expect(shelf.recent.first.key, saved.key);
    });

    testWidgets('sin «Sorpréndeme» elegido, la enseñanza queda guardada',
        (tester) async {
      final shelf = await openApp(tester, seed: 9);
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      expect(shelf.recent.first.option, isNull);
    });
  });

  group('estante', () {
    test('favoritos y recientes se guardan y se leen de nuevo', () async {
      final store = MemoryShelfStore();
      final a = StoryShelf(store);
      await a.load();
      await a.addRecent(_entry(1));
      await a.addRecent(_entry(2, title: 'La linterna'));
      await a.addRecent(
          _entry(1)); // se repite: sube al primer lugar sin duplicarse
      expect(a.recent.map((e) => e.seed), [1, 2]);
      await a.toggleFavorite(_entry(2, title: 'La linterna'));
      expect(a.isFavorite(_entry(2)), isTrue);

      final b = StoryShelf(store);
      await b.load();
      expect(b.recent.map((e) => e.seed), [1, 2]);
      expect(b.favorites.single.title, 'La linterna');
      await b.toggleFavorite(_entry(2));
      expect(b.favorites, isEmpty);
    });

    test('la misma semilla con otra enseñanza es otro cuento', () {
      expect(_entry(1).key, isNot(_entry(1, option: 'valentia').key));
    });

    test('guarda como máximo los últimos 12 y se puede borrar', () async {
      final s = StoryShelf(MemoryShelfStore());
      for (var i = 0; i < 20; i++) {
        await s.addRecent(_entry(i));
      }
      expect(s.recent, hasLength(StoryShelf.maxRecent));
      expect(s.recent.first.seed, 19);
      await s.clearRecent();
      expect(s.recent, isEmpty);
    });

    test('un estante ilegible empieza de cero', () async {
      final store = MemoryShelfStore()..value = '{no es json';
      final s = StoryShelf(store);
      await s.load();
      expect(s.recent, isEmpty);
      expect(s.favorites, isEmpty);
    });
  });

  group('temporizador para dormir', () {
    testWidgets('al cumplirse detiene el cuento y desea dulces sueños',
        (tester) async {
      var expired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SleepTimerButton(onExpire: () => expired++),
        ),
      ));
      await tester.tap(find.byKey(const Key('sleep-timer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dormir en 10 minutos'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 9));
      expect(expired, 0);
      await tester.pump(const Duration(minutes: 2));
      expect(expired, 1);
      expect(find.textContaining('Dulces sueños'), findsOneWidget);
    });

    testWidgets('se puede quitar antes de que se cumpla', (tester) async {
      var expired = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SleepTimerButton(onExpire: () => expired++),
        ),
      ));
      await tester.tap(find.byKey(const Key('sleep-timer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dormir en 20 minutos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sleep-timer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar temporizador'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 30));
      expect(expired, 0);
    });
  });
}
