import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/feedback/feedback_transport.dart';
import 'package:caldero_app/src/feedback/rating_event.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeTransport implements FeedbackTransport {
  final List<List<Map<String, Object?>>> batches = [];
  SendOutcome outcome = SendOutcome.done;
  Completer<void>? gate;

  @override
  Future<SendOutcome> send(List<Map<String, Object?>> events) async {
    batches.add(events);
    await gate?.future;
    return outcome;
  }
}

StoryRecipe recipe(int seed, {String value = 'honestidad'}) => StoryRecipe(
      packId: 'demo',
      packVersion: '0.1.0',
      engineVersion: engineVersion,
      seed: seed,
      valueId: value,
      cast: const {'hero': 'nilo', 'villain': 'brisca'},
      fragmentIds: const ['op_1', 'tr_hon'],
    );

void main() {
  late DateTime clock;
  late MemoryFeedbackStore store;
  late FakeTransport transport;
  late FeedbackService service;
  var ids = 0;

  setUp(() {
    clock = DateTime.utc(2026, 10, 8, 3, 30);
    store = MemoryFeedbackStore();
    transport = FakeTransport();
    ids = 0;
    service = FeedbackService(
      store: store,
      transport: transport,
      now: () => clock,
      idGenerator: () => 'id-${++ids}',
    );
  });

  group('identificador y fecha', () {
    test('UUID v4 válido, determinista con semilla y sin repeticiones', () {
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(newEventId(Random(1)), matches(re));
      expect(newEventId(Random(1)), newEventId(Random(1)));
      final seen = {for (var i = 0; i < 2000; i++) newEventId()};
      expect(seen, hasLength(2000));
    });

    test('solo se envía el día en UTC, nunca la hora', () {
      expect(dayOf(DateTime.utc(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(dayOf(DateTime.parse('2026-01-05T23:59:00-05:00')), '2026-01-06');
    });

    test('la versión de la app coincide con el pubspec', () {
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      expect(line.split(':')[1].trim().split('+').first, appVersion);
    });
  });

  group('el evento (lo ÚNICO que viaja)', () {
    test('tiene exactamente los campos prometidos', () {
      final j =
          RatingEvent(id: 'x', recipe: recipe(1), rating: 4, day: '2026-10-08')
              .toJson();
      expect(j.keys,
          unorderedEquals(['id', 'schema', 'rating', 'day', 'app', 'recipe']));
      expect(
        (j['recipe']! as Map<String, Object?>).keys,
        unorderedEquals([
          'packId',
          'packVersion',
          'engine',
          'seed',
          'value',
          'cast',
          'fragments'
        ]),
      );
    });

    test('un cuento real: sin texto, sin nombres y muy pequeño', () {
      final pack = Pack.fromJson(
        jsonDecode(File('assets/packs/demo/pack.json').readAsStringSync())
            as Map<String, Object?>,
      );
      final story = StoryEngine(pack)
          .generate(const StoryOptions(seed: 3, valueId: 'honestidad'));
      final json = jsonEncode(RatingEvent(
              id: 'x', recipe: story.recipe, rating: 5, day: '2026-10-08')
          .toJson());
      for (final scene in story.scenes) {
        expect(json, isNot(contains(scene.text.substring(0, 20))));
      }
      for (final c in pack.characters) {
        expect(json, isNot(contains(c.given)),
            reason: 'el nombre propio no viaja');
      }
      expect(json.length, lessThan(600));
    });

    test(
        'es idéntico al ejemplo del contrato (docs/api/examples/rating-event.json)',
        () {
      final fixture = jsonDecode(
              File('../docs/api/examples/rating-event.json').readAsStringSync())
          as Map<String, Object?>;
      final built = RatingEvent(
        id: fixture['id']! as String,
        recipe:
            StoryRecipe.fromJson(fixture['recipe']! as Map<String, Object?>),
        rating: fixture['rating']! as int,
        day: fixture['day']! as String,
        app: fixture['app']! as String,
      );
      // Mismos campos, mismos nombres, mismos tipos y mismo orden.
      expect(jsonEncode(built.toJson()), jsonEncode(fixture));
    });

    test('solo acepta notas de 1 a 5', () {
      for (final bad in [0, 6, -1]) {
        expect(
            () =>
                RatingEvent(id: 'x', recipe: recipe(1), rating: bad, day: 'd'),
            throwsRangeError);
      }
    });

    test('ida y vuelta por JSON', () {
      final e =
          RatingEvent(id: 'x', recipe: recipe(9), rating: 3, day: '2026-10-08');
      expect(RatingEvent.fromJson(e.toJson()).toJson(), e.toJson());
    });
  });

  group('servicio', () {
    test('rate guarda un evento completo en la cola', () async {
      expect(await service.rate(recipe(7), 5), isTrue);
      final q = await store.readQueue();
      expect(q, hasLength(1));
      expect(q.single['id'], 'id-1');
      expect(q.single['rating'], 5);
      expect(q.single['day'], '2026-10-08');
      expect((q.single['recipe']! as Map<String, Object?>)['seed'], 7);
    });

    test('sin servidor configurado las valoraciones esperan en el teléfono',
        () async {
      final offline = FeedbackService(
          store: store, now: () => clock, idGenerator: () => 'a');
      await offline.rate(recipe(1), 4);
      expect(await offline.flush(), FlushResult.noServer);
      expect(await offline.queuedCount(), 1);
    });

    test('envío correcto: la cola se vacía y no se repite', () async {
      await service.rate(recipe(1), 5);
      await service.rate(recipe(2), 2);
      expect(await service.flush(), FlushResult.sent);
      expect(transport.batches.single.map((e) => e['id']), ['id-1', 'id-2']);
      expect(await service.queuedCount(), 0);
      expect(await service.flush(), FlushResult.empty);
      expect(transport.batches, hasLength(1));
    });

    test(
        'fallo: se conserva, espera con retroceso creciente y vuelve a intentar',
        () async {
      await service.rate(recipe(1), 5);
      transport.outcome = SendOutcome.retryLater;
      expect(await service.flush(), FlushResult.failed);
      expect(await service.queuedCount(), 1);

      // Aún no toca: no se vuelve a llamar al servidor.
      expect(await service.flush(), FlushResult.waiting);
      expect(transport.batches, hasLength(1));

      clock = clock.add(
          const Duration(minutes: 1, seconds: 1)); // 1.er fallo → espera 1 min
      expect(await service.flush(), FlushResult.failed);
      expect(transport.batches, hasLength(2));

      clock = clock.add(
          const Duration(minutes: 1, seconds: 1)); // 2.º fallo → espera 2 min
      expect(await service.flush(), FlushResult.waiting);
      clock = clock.add(const Duration(minutes: 1));
      transport.outcome = SendOutcome.done;
      expect(await service.flush(), FlushResult.sent);
      expect(await service.queuedCount(), 0);
      expect(await store.readFailures(), 0,
          reason: 'al tener éxito se reinicia el retroceso');
    });

    test('el retroceso nunca supera las 6 horas', () async {
      await service.rate(recipe(1), 5);
      transport.outcome = SendOutcome.retryLater;
      for (var i = 0; i < 30; i++) {
        await service.flush(force: true);
      }
      expect(await store.readRetryAt() - clock.millisecondsSinceEpoch,
          lessThanOrEqualTo(6 * 3600 * 1000));
    });

    test('envía por lotes de 50 y conserva lo que no se pudo enviar', () async {
      for (var i = 0; i < 120; i++) {
        await service.rate(recipe(i), 4);
      }
      expect(await service.flush(), FlushResult.sent);
      expect(transport.batches.map((b) => b.length), [50, 50, 20]);

      for (var i = 0; i < 120; i++) {
        await service.rate(recipe(i), 4);
      }
      var calls = 0;
      final flaky = _FlakyTransport(
          () => ++calls == 1 ? SendOutcome.done : SendOutcome.retryLater);
      final s2 =
          FeedbackService(store: store, transport: flaky, now: () => clock);
      expect(await s2.flush(force: true), FlushResult.failed);
      expect(await s2.queuedCount(), 70,
          reason: 'el primer lote (50) salió; el resto espera');
    });

    test('la cola tiene tope: se descartan las más antiguas', () async {
      for (var i = 0; i < 205; i++) {
        await service.rate(recipe(i), 4);
      }
      final q = await store.readQueue();
      expect(q, hasLength(FeedbackService.maxQueue));
      expect((q.first['recipe']! as Map<String, Object?>)['seed'], 5);
    });

    test('dos envíos a la vez no se pisan', () async {
      await service.rate(recipe(1), 5);
      transport.gate = Completer<void>();
      final first = service.flush();
      await Future<void>.delayed(Duration.zero);
      expect(await service.flush(), FlushResult.waiting);
      transport.gate!.complete();
      expect(await first, FlushResult.sent);
      expect(transport.batches, hasLength(1));
    });

    test('desactivar el envío borra lo pendiente y deja de recoger', () async {
      await service.rate(recipe(1), 5);
      await service.rememberPending(recipe(2), 'Cuento');
      await service.setEnabled(false);
      expect(await service.queuedCount(), 0);
      expect(await service.nextPending(), isNull);
      expect(await service.rate(recipe(3), 5), isFalse);
      expect(await service.flush(), FlushResult.disabled);
      expect(transport.batches, isEmpty);
      await service.rememberPending(recipe(4), 'Otro');
      expect(await store.readPending(), isEmpty);
    });
  });

  group('valoraciones pendientes (preguntar por la mañana)', () {
    test('se recuerdan, se reemplazan y se limitan a 3', () async {
      for (var i = 1; i <= 5; i++) {
        await service.rememberPending(recipe(i), 'Cuento $i');
      }
      final p = await store.readPending();
      expect(p.map((x) => x.recipe.seed), [3, 4, 5]);
      await service.rememberPending(recipe(4), 'Cuento 4 (otra vez)');
      expect((await store.readPending()).map((x) => x.recipe.seed), [3, 5, 4]);
    });

    test('devuelve el más reciente y caduca a los 3 días', () async {
      await service.rememberPending(recipe(1), 'A');
      clock = clock.add(const Duration(days: 1));
      await service.rememberPending(recipe(2), 'B');
      expect((await service.nextPending())!.label, 'B');
      clock = clock.add(const Duration(days: 3));
      expect((await service.nextPending())!.label, 'B',
          reason: 'con 3 días todavía vale');
      clock = clock.add(const Duration(days: 1));
      expect(await service.nextPending(), isNull,
          reason: 'con 4 días ya caducó');
      expect(await store.readPending(), isEmpty);
    });

    test('valorar o decir «ahora no» lo quita', () async {
      await service.rememberPending(recipe(1), 'A');
      await service.rememberPending(recipe(2), 'B');
      await service.rate(recipe(2), 5);
      expect((await service.nextPending())!.recipe.seed, 1);
      await service.dismissPending(recipe(1));
      expect(await service.nextPending(), isNull);
    });
  });

  group('transporte HTTP', () {
    final events = [
      RatingEvent(id: 'a', recipe: recipe(1), rating: 5, day: '2026-10-08')
          .toJson(),
    ];
    HttpFeedbackTransport make(http.Client c, {Duration? timeout}) =>
        HttpFeedbackTransport(
          Uri.parse('https://api.example/v1/feedback'),
          client: c,
          timeout: timeout ?? const Duration(seconds: 5),
        );

    test('envía solo el JSON de los eventos, sin cookies ni credenciales',
        () async {
      late http.Request seen;
      final t = make(MockClient((req) async {
        seen = req;
        return http.Response('{}', 202);
      }));
      expect(await t.send(events), SendOutcome.done);
      expect(seen.method, 'POST');
      expect(seen.url.path, '/v1/feedback');
      expect(jsonDecode(seen.body), {'events': events});
      final names = seen.headers.keys.map((k) => k.toLowerCase()).toSet();
      expect(names, isNot(contains('cookie')));
      expect(names, isNot(contains('authorization')));
      expect(names.difference({'content-type', 'content-length'}), isEmpty);
    });

    test('cada código de respuesta se trata como corresponde', () async {
      Future<SendOutcome> with_(int code) =>
          make(MockClient((_) async => http.Response('', code))).send(events);
      expect(await with_(200), SendOutcome.done);
      expect(await with_(202), SendOutcome.done);
      expect(await with_(400), SendOutcome.done,
          reason: 'inválido: reintentar no lo arregla');
      expect(await with_(429), SendOutcome.retryLater);
      expect(await with_(500), SendOutcome.retryLater);
      expect(await with_(503), SendOutcome.retryLater);
    });

    test('sin red o con tiempo agotado se reintenta más tarde', () async {
      final down =
          make(MockClient((_) async => throw http.ClientException('sin red')));
      expect(await down.send(events), SendOutcome.retryLater);
      final slow = make(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('', 200);
        }),
        timeout: const Duration(milliseconds: 30),
      );
      expect(await slow.send(events), SendOutcome.retryLater);
    });
  });
}

class _FlakyTransport implements FeedbackTransport {
  _FlakyTransport(this.next);
  final SendOutcome Function() next;

  @override
  Future<SendOutcome> send(List<Map<String, Object?>> events) async => next();
}
