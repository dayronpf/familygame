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
        feedback: override ?? service,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> createStory(WidgetTester tester,
      {String moral = 'Honestidad'}) async {
    await tester.tap(find.text(moral));
    await tester.pump();
    await tester.tap(find.text('Crear cuento'));
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
    expect(recipe['packId'], 'demo');
    expect((recipe['fragments']! as List<Object?>), hasLength(7));
    expect(await service.queuedCount(), 0, reason: 'ya salió');
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
      await tester.tap(find.byKey(const Key('example-tile')));
      await tester.pumpAndSettle();
      final json = tester
          .widget<SelectableText>(find.byKey(const Key('example-json')))
          .data!;
      // Lo que se le muestra a la familia es EXACTAMENTE un evento del contrato.
      final shown = jsonDecode(json) as Map<String, Object?>;
      final fixture = jsonDecode(
              File('../docs/api/examples/rating-event.json').readAsStringSync())
          as Map<String, Object?>;
      expect(shown..remove('app'), fixture..remove('app'));
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
