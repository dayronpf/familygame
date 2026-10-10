import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/feedback/feedback_transport.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

class _Transport implements FeedbackTransport {
  final List<Map<String, Object?>> sent = [];

  @override
  Future<SendOutcome> send(List<Map<String, Object?>> events) async {
    sent.addAll(events);
    return SendOutcome.done;
  }
}

void main() {
  late MemoryFeedbackStore store;
  late _Transport transport;
  late FeedbackService service;
  var seed = 3;
  var n = 0;

  setUp(() {
    store = MemoryFeedbackStore();
    transport = _Transport();
    n = 0;
    seed = 3;
    service = FeedbackService(
      store: store,
      transport: transport,
      now: () => DateTime.utc(2026, 10, 8, 3),
      idGenerator: () => 'e${++n}',
    );
  });

  Future<void> openApp(WidgetTester tester, [FeedbackService? override]) async {
    await tester.pumpWidget(
      CalderoApp(
        bundle: FileBundle(),
        seedProvider: () => seed++,
        animateArt: false,
        feedback: override ?? service,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> createStory(WidgetTester tester,
      {String moral = 'Honestidad'}) async {
    // En pantallas estrechas el inicio es más alto que la pantalla: se desplaza hasta cada control.
    for (final label in [moral, 'Crear cuento']) {
      await tester.scrollUntilVisible(find.text(label), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> scrollToRating(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.byKey(const Key('rating-5')), 300);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'al final del cuento se pregunta y un toque guarda y envía la valoración',
      (tester) async {
    await openApp(tester);
    await createStory(tester);
    expect(find.byKey(const Key('rating-5')), findsNothing,
        reason: 'no se pregunta antes de leer');
    await scrollToRating(tester);
    expect(find.text('¿Cuánto les gustó este cuento?'), findsOneWidget);
    for (final label in ['Nada', 'Poco', 'Regular', 'Bien', '¡Me encantó!']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('rating-5')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rating-thanks')), findsOneWidget);
    expect(transport.sent, hasLength(1));
    final e = transport.sent.single;
    expect(e['rating'], 5);
    expect(e['day'], '2026-10-08');
    final recipe = e['recipe']! as Map<String, Object?>;
    expect(recipe['seed'], 3);
    expect(recipe['value'], 'honestidad');
    expect(recipe['packId'], 'medieval');
    expect((recipe['fragments']! as List<Object?>), hasLength(7));
    expect(await service.queuedCount(), 0, reason: 'ya salió');
  });

  group('pantallas estrechas y letra grande', () {
    Future<void> narrowPhone(WidgetTester tester,
        {double width = 320, double textScale = 1.3}) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(width * 3, 760 * 3);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
    }

    for (final width in [320.0, 351.0]) {
      testWidgets(
          'las 5 caritas caben dentro de la tarjeta a $width dp con letra 1.3×',
          (tester) async {
        await narrowPhone(tester, width: width);
        await openApp(tester);
        await createStory(tester);
        await scrollToRating(tester);
        final card = tester.getRect(
          find.ancestor(
              of: find.byKey(const Key('rating-1')),
              matching: find.byType(Card)),
        );
        var previousRight = card.left;
        for (var i = 1; i <= 5; i++) {
          final r = tester.getRect(find.byKey(Key('rating-$i')));
          expect(r.left, greaterThanOrEqualTo(card.left),
              reason: 'carita $i se sale por la izquierda');
          expect(r.right, lessThanOrEqualTo(card.right),
              reason: 'carita $i se sale por la derecha');
          expect(r.left, greaterThanOrEqualTo(previousRight - 0.01),
              reason: 'carita $i se solapa con la anterior');
          expect(r.width, greaterThanOrEqualTo(44),
              reason: 'objetivo táctil demasiado pequeño');
          previousRight = r.right;
        }
        // Se puede tocar la última (la que se salía) y el segundo paso tampoco se desborda.
        await tester.tap(find.byKey(const Key('rating-2')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('reasons-step')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reasons-step')), findsOneWidget);
      });
    }
  });

  group('motivo opcional con nota baja', () {
    Future<void> reachEnd(WidgetTester tester) async {
      await openApp(tester);
      await createStory(tester);
      await scrollToRating(tester);
    }

    Future<void> ensureReasons(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('reasons-step')));
      await tester.pumpAndSettle();
    }

    testWidgets('con 1, 2 o 3 aparecen los cinco motivos; con 4 o 5, no',
        (tester) async {
      for (final high in [4, 5]) {
        await reachEnd(tester);
        await tester.tap(find.byKey(Key('rating-$high')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reasons-step')), findsNothing,
            reason: 'nota $high');
        expect(find.byKey(const Key('rating-thanks')), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        store.pending.clear();
      }
      for (final low in [1, 2, 3]) {
        await reachEnd(tester);
        await tester.tap(find.byKey(Key('rating-$low')));
        await tester.pumpAndSettle();
        await ensureReasons(tester);
        expect(find.byKey(const Key('reasons-step')), findsOneWidget,
            reason: 'nota $low');
        for (final label in [
          'No tuvo sentido',
          'Se repitió',
          'Muy largo o muy corto',
          'Dio miedo',
          'No me gustó la enseñanza',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Omitir'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'elegir motivos y pulsar «Listo» los envía con la nota, en el orden de los botones',
        (tester) async {
      await reachEnd(tester);
      await tester.tap(find.byKey(const Key('rating-2')));
      await tester.pumpAndSettle();
      expect(transport.sent, isEmpty,
          reason: 'todavía no se envía: pueden añadir un motivo');
      expect(await service.queuedCount(), 1,
          reason: 'pero la nota ya está guardada');

      await ensureReasons(tester);
      await tester.tap(find.byKey(const Key('reason-repeated')));
      await tester.tap(find.byKey(const Key('reason-no_sense')));
      await tester.pump();
      expect(find.text('Listo'), findsOneWidget);
      expect(find.text('Omitir'), findsNothing);
      await tester.tap(find.byKey(const Key('reasons-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rating-thanks')), findsOneWidget);
      expect(find.byKey(const Key('reasons-step')), findsNothing);
      expect(transport.sent, hasLength(1));
      expect(transport.sent.single['rating'], 2);
      expect(transport.sent.single['reasons'], ['no_sense', 'repeated']);
    });

    testWidgets('se puede quitar un motivo elegido por error', (tester) async {
      await reachEnd(tester);
      await tester.tap(find.byKey(const Key('rating-1')));
      await tester.pumpAndSettle();
      await ensureReasons(tester);
      await tester.tap(find.byKey(const Key('reason-scary')));
      await tester.tap(find.byKey(const Key('reason-moral')));
      await tester.tap(find.byKey(const Key('reason-scary'))); // lo quita
      await tester.pump();
      await tester.tap(find.byKey(const Key('reasons-submit')));
      await tester.pumpAndSettle();
      expect(transport.sent.single['reasons'], ['moral']);
    });

    testWidgets('«Omitir» envía la nota sin motivos', (tester) async {
      await reachEnd(tester);
      await tester.tap(find.byKey(const Key('rating-3')));
      await tester.pumpAndSettle();
      await ensureReasons(tester);
      await tester.tap(find.byKey(const Key('reasons-submit')));
      await tester.pumpAndSettle();
      expect(transport.sent, hasLength(1));
      expect(transport.sent.single['rating'], 3);
      expect(transport.sent.single.containsKey('reasons'), isFalse);
    });

    testWidgets(
        'si se van a mitad del segundo paso, la nota igual se envía (sin motivo)',
        (tester) async {
      await reachEnd(tester);
      await tester.tap(find.byKey(const Key('rating-1')));
      await tester.pumpAndSettle();
      expect(transport.sent, isEmpty);
      await tester.pageBack(); // se van sin pulsar nada
      await tester.pumpAndSettle();
      expect(transport.sent, hasLength(1));
      expect(transport.sent.single['rating'], 1);
      expect(transport.sent.single.containsKey('reasons'), isFalse);
    });

    testWidgets('la tarjeta de la mañana también pregunta el motivo',
        (tester) async {
      await openApp(tester);
      await createStory(tester);
      await scrollToRating(tester);
      await tester.pageBack(); // leyeron hasta el final y se fueron
      await tester.pumpAndSettle();
      expect(
          find.textContaining('¿Cuánto les gustó «Honestidad'), findsOneWidget);

      await tester.tap(find.byKey(const Key('rating-2')));
      await tester.pumpAndSettle();
      await ensureReasons(tester);
      await tester.tap(find.byKey(const Key('reason-length')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('reasons-submit')));
      await tester.pumpAndSettle();
      expect(transport.sent, hasLength(1));
      expect(transport.sent.single['reasons'], ['length']);
      expect(store.pending, isEmpty);
    });

    testWidgets('con el envío desactivado no se pregunta ni el motivo',
        (tester) async {
      store.enabled = false;
      await openApp(tester);
      await createStory(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reasons-step')), findsNothing);
      expect(find.byKey(const Key('rating-1')), findsNothing);
    });
  });

  testWidgets('no se puede valorar dos veces el mismo cuento', (tester) async {
    await openApp(tester);
    await createStory(tester);
    await scrollToRating(tester);
    await tester.tap(find.byKey(const Key('rating-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-1')));
    await tester.pumpAndSettle();
    expect(transport.sent, hasLength(1));
    expect(transport.sent.single['rating'], 4);
  });

  testWidgets('«Ahora no» no envía nada ni deja pendiente', (tester) async {
    await openApp(tester);
    await createStory(tester);
    await scrollToRating(tester);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rating-5')), findsNothing);
    expect(transport.sent, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.pending, isEmpty);
  });

  testWidgets(
      '«Contar otro cuento» pregunta de nuevo y cada valoración lleva su cuento',
      (tester) async {
    await openApp(tester);
    await createStory(tester);
    await scrollToRating(tester);
    await tester.tap(find.byKey(const Key('rating-5')));
    await tester.pumpAndSettle();

    final another = find.text('Contar otro cuento');
    await tester.ensureVisible(another);
    await tester.tap(another);
    await tester.pumpAndSettle();
    await scrollToRating(tester);
    expect(find.byKey(const Key('rating-thanks')), findsNothing,
        reason: 'ficha nueva, sin responder');
    await tester.tap(find.byKey(const Key('rating-2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reasons-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reasons-submit'))); // Omitir
    await tester.pumpAndSettle();

    expect(transport.sent.map((e) => e['rating']), [5, 2]);
    final seeds = transport.sent
        .map((e) => (e['recipe']! as Map<String, Object?>)['seed'])
        .toSet();
    expect(seeds, hasLength(2), reason: 'dos cuentos distintos');
    expect(transport.sent.map((e) => e['id']).toSet(), hasLength(2));
  });

  testWidgets(
      'si leyeron hasta el final y se fueron, al volver se les pregunta con calma',
      (tester) async {
    await openApp(tester);
    await createStory(tester);
    await scrollToRating(tester); // llegó al final
    await tester.pageBack(); // se fue sin responder
    await tester.pumpAndSettle();

    expect(store.pending, hasLength(1));
    expect(
        find.textContaining('¿Cuánto les gustó «Honestidad'), findsOneWidget);
    expect(transport.sent, isEmpty,
        reason: 'no se envía nada sin que respondan');

    await tester.tap(find.byKey(const Key('rating-4')));
    await tester.pumpAndSettle();
    expect(transport.sent, hasLength(1));
    expect(transport.sent.single['rating'], 4);
    expect(store.pending, isEmpty);
  });

  testWidgets('si se fueron sin llegar al final no se les pregunta nada',
      (tester) async {
    await openApp(tester);
    await createStory(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.pending, isEmpty);
    expect(find.textContaining('¿Cuánto les gustó'), findsNothing);
  });

  testWidgets('con el envío desactivado no aparece ninguna pregunta',
      (tester) async {
    store.enabled = false;
    await openApp(tester);
    await createStory(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rating-5')), findsNothing);
    expect(find.text('Ahora no'), findsNothing);
    expect(transport.sent, isEmpty);
  });

  group('ajustes para adultos', () {
    Future<void> answerGate(WidgetTester tester,
        {required bool correct}) async {
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) × (\d)').firstMatch(q)!;
      final answer =
          int.parse(m.group(1)!) * int.parse(m.group(2)!) + (correct ? 0 : 1);
      await tester.enterText(find.byKey(const Key('gate-answer')), '$answer');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();
    }

    testWidgets('una respuesta incorrecta no deja entrar', (tester) async {
      await openApp(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Solo para adultos'), findsOneWidget);
      await answerGate(tester, correct: false);
      expect(find.text('Ajustes para adultos'), findsNothing);
      expect(find.text('Caldero de Cuentos'), findsOneWidget);
    });

    testWidgets('muestra con transparencia qué se envía y un ejemplo exacto',
        (tester) async {
      await openApp(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await answerGate(tester, correct: true);
      expect(find.text('Ajustes para adultos'), findsOneWidget);
      expect(find.text('Qué enviamos'), findsOneWidget);
      expect(find.text('Qué NO enviamos'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('example-tile')), 300);
      await tester.tap(find.byKey(const Key('example-tile')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const Key('example-json-reasons')), 300,
          scrollable: find.byType(Scrollable).first);
      final json = tester
          .widget<SelectableText>(find.byKey(const Key('example-json')))
          .data!;
      // Lo que se le muestra a la familia es EXACTAMENTE un evento del contrato.
      final shown = jsonDecode(json) as Map<String, Object?>;
      final fixture = jsonDecode(
              File('../docs/api/examples/rating-event.json').readAsStringSync())
          as Map<String, Object?>;
      expect(shown..remove('app'), fixture..remove('app'));
      final shownReasons = jsonDecode(
        tester
            .widget<SelectableText>(
                find.byKey(const Key('example-json-reasons')))
            .data!,
      ) as Map<String, Object?>;
      final fixtureReasons = jsonDecode(
        File('../docs/api/examples/rating-event-with-reasons.json')
            .readAsStringSync(),
      ) as Map<String, Object?>;
      expect(shownReasons..remove('app'), fixtureReasons..remove('app'));
      expect(
          find.textContaining('Nunca se envía texto escrito'), findsOneWidget);
      expect(json, contains('"rating": 5'));
      expect(json, contains('"fragments"'));
      expect(json, isNot(contains('Había')));
    });

    testWidgets(
        'desactivar borra lo que esperaba enviarse y apaga las preguntas',
        (tester) async {
      // Sin servidor: la valoración se queda esperando en el teléfono.
      final offline = FeedbackService(
        store: store,
        now: () => DateTime.utc(2026, 10, 8, 3),
        idGenerator: () => 'w1',
      );
      await offline.rate(_recipe, 5);
      expect(await offline.queuedCount(), 1);
      await openApp(tester, offline);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await answerGate(tester, correct: true);
      expect(find.textContaining('Esperando para enviarse: 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feedback-switch')));
      await tester.pumpAndSettle();
      expect(store.enabled, isFalse);
      expect(store.queue, isEmpty);
      expect(find.textContaining('Se borró'), findsOneWidget);
    });
  });
}

final StoryRecipe _recipe = StoryRecipe.fromJson(const {
  'packId': 'demo',
  'packVersion': '0.1.0',
  'engine': '0.1.0',
  'seed': 1,
  'value': 'honestidad',
  'cast': {'hero': 'nilo'},
  'fragments': ['op_1'],
});
