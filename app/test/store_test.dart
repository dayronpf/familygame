import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/catalog/catalog_widgets.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/store/access.dart';
import 'package:caldero_app/src/store/paywall_page.dart';
import 'package:caldero_app/src/store/purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

class _FakeApi implements StoreApi {
  Map<String, Object?> catalogBody = {
    'version': '2',
    'freeStories': ['medieval:campana'],
    'hiddenStories': ['mar:cofre_pesado'],
    'products': [],
  };
  final redeemed = <String>[];

  @override
  Future<({String etag, Map<String, Object?> body})?> catalog(
          String? etag) async =>
      (etag: '"v2"', body: catalogBody);

  @override
  Future<Entitlement?> entitlement(String installId) async => null;

  @override
  Future<StoreResult> redeem(String installId, String code) async {
    if (code != 'MINI-ABCD-1234') {
      return const StoreResult(StoreOutcome.invalid);
    }
    redeemed.add(code);
    return StoreResult(
        StoreOutcome.ok,
        Entitlement(
            premium: true,
            source: 'code',
            expiresAt: DateTime.now().add(const Duration(days: 30))));
  }

  @override
  Future<StoreResult> verify({
    required String installId,
    required String platform,
    required String productId,
    String? purchaseToken,
    String? transactionId,
  }) async =>
      StoreResult(
          StoreOutcome.ok,
          Entitlement(
              premium: true,
              source: 'google',
              trial: true,
              expiresAt: DateTime.now().add(const Duration(days: 7))));
}

class _FakePurchases extends PurchaseGateway {
  _FakePurchases(this.access);
  final AccessService access;
  PurchaseState _state = PurchaseState.idle;
  bool bought = false;

  @override
  String? get message => null;
  @override
  PurchaseState get state => _state;

  @override
  Future<List<PlanOption>> plans() async => const [
        PlanOption(id: 'anual', price: 'USD 9,99', yearly: true, trialDays: 7),
        PlanOption(id: 'mensual', price: 'USD 1,99', yearly: false),
      ];

  @override
  Future<void> buy(PlanOption plan) async {
    bought = true;
    await access.verifyPurchase(
        platform: 'android',
        productId: subscriptionProductId,
        purchaseToken: 't');
    _state = PurchaseState.done;
    notifyListeners();
  }

  @override
  Future<void> restore() async {}

  bool redeemed = false;

  @override
  Future<bool> redeemWithStore() async => redeemed = true;
}

void main() {
  group('acceso', () {
    test(
        'sin suscripción solo se leen los gratis; el modo desarrollador solo existe en pruebas',
        () async {
      final a = AccessService(MemoryShelfStore(), devAvailable: false);
      await a.load();
      expect(a.installId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(a.premium, isFalse);
      expect(a.canRead('medieval', 'sombras'), isTrue);
      expect(a.canRead('medieval', 'campana'), isFalse);
      await a.setDevUnlock(true);
      expect(a.premium, isFalse,
          reason: 'la compilación de la tienda no lo tiene');

      final dev = AccessService(MemoryShelfStore(), devAvailable: true);
      await dev.load();
      await dev.setDevUnlock(true);
      expect(dev.premium, isTrue);
      expect(dev.canRead('medieval', 'campana'), isTrue);
    });

    test('el derecho caduca con 3 días de margen sin conexión', () {
      final now = DateTime(2026, 11, 10);
      final e = Entitlement(
          premium: true, source: 'google', expiresAt: DateTime(2026, 11, 8));
      expect(e.activeAt(now), isTrue);
      expect(e.activeAt(now.add(const Duration(days: 2))), isFalse);
    });

    test(
        'el catálogo del servidor cambia los gratis y oculta los rechazados; se guarda',
        () async {
      final store = MemoryShelfStore();
      final a = AccessService(store, api: _FakeApi());
      await a.load();
      await a.refresh();
      expect(a.isFree('medieval', 'campana'), isTrue);
      expect(a.isFree('medieval', 'sombras'), isFalse);
      expect(a.isHidden('mar', 'cofre_pesado'), isTrue);
      final b = AccessService(store);
      await b.load();
      expect(b.isFree('medieval', 'campana'), isTrue);
      expect(b.installId, a.installId);
    });

    test('un código válido abre todo; uno inválido no', () async {
      final a = AccessService(MemoryShelfStore(), api: _FakeApi());
      await a.load();
      expect((await a.redeem('mini-zzzz')).outcome, StoreOutcome.invalid);
      expect(a.premium, isFalse);
      expect((await a.redeem(' mini-abcd-1234 ')).outcome, StoreOutcome.ok);
      expect(a.premium, isTrue);
      expect(a.entitlement.source, 'code');
    });

    test('sin servidor no se puede canjear ni verificar', () async {
      final a = AccessService(MemoryShelfStore());
      await a.load();
      expect((await a.redeem('MINI-ABCD-1234')).outcome, StoreOutcome.noServer);
      expect(
          (await a.verifyPurchase(platform: 'android', productId: 'x')).outcome,
          StoreOutcome.noServer);
    });
  });

  group('la app sin suscripción', () {
    Future<(StoryShelf, AccessService)> openApp(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final shelf = StoryShelf(MemoryShelfStore());
      final access = AccessService(MemoryShelfStore());
      await tester.pumpWidget(CalderoApp(
        bundle: FileBundle(),
        seedProvider: () => 3,
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        shelf: shelf,
        access: access,
        animateArt: false,
      ));
      await tester.pumpAndSettle();
      return (shelf, access);
    }

    testWidgets(
        '«Crear cuento» cuenta uno de los gratis y no ofrece otro de pago',
        (tester) async {
      final (shelf, access) = await openApp(tester);
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      final told = shelf.recent.first;
      expect(access.isFree(told.packId, told.premiseId!), isTrue);
      final more = find.byKey(const Key('more-stories'));
      await tester.scrollUntilVisible(more, 600,
          scrollable: find.byType(Scrollable).first);
      expect(more, findsOneWidget);
      expect(find.text('Contar otro cuento'), findsNothing);
    });

    testWidgets(
        'en Explorar los de pago llevan candado y su ficha ofrece desbloquear',
        (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-free')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('explore-search')), 'campana rota');
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('story-row-medieval:campana'));
      expect(
          find.descendant(of: row, matching: find.byType(LockBadgeFinder.type)),
          findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-unlock')), findsOneWidget);
      expect(find.byKey(const Key('detail-read')), findsNothing);
      expect(find.byKey(const Key('detail-synopsis')), findsOneWidget);
    });
  });

  group('muro de pago', () {
    testWidgets(
        'elige el anual con prueba, compra, se verifica y se cierra con todo abierto',
        (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 3400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final access = AccessService(MemoryShelfStore(), api: _FakeApi());
      await access.load();
      final purchases = _FakePurchases(access);
      bool? result;
      await tester.pumpWidget(MaterialApp(
        // Como en la app: el acceso y las compras van por encima del Navigator
        builder: (context, child) => AccessScope(
          access: access,
          child: PurchasesScope(
            purchases: purchases,
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
          ),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<bool>(
                    MaterialPageRoute(builder: (_) => const PaywallPage())),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _frames(tester);
      expect(find.text('Hoy: prueba gratis'), findsOneWidget);
      expect(find.text('Día 7: empieza la suscripción'), findsOneWidget);
      expect(find.byKey(const Key('plan-anual')), findsOneWidget);
      expect(find.text('Probar 7 días gratis'), findsOneWidget);
      expect(find.byKey(const Key('paywall-close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall-buy')));
      await _frames(tester);
      expect(purchases.bought, isTrue);
      expect(access.premium, isTrue);
      expect(result, isTrue);
    });

    testWidgets(
        'en la versión de las tiendas: términos y privacidad a la vista, y los códigos se canjean en la tienda',
        (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 3400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final access = AccessService(MemoryShelfStore(), devAvailable: false);
      await access.load();
      final purchases = _FakePurchases(access);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => AccessScope(
          access: access,
          child: PurchasesScope(
            purchases: purchases,
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
          ),
        ),
        home: const PaywallPage(),
      ));
      await _frames(tester);
      await tester.scrollUntilVisible(
          find.byKey(const Key('paywall-redeem')), 300,
          scrollable: find.byType(Scrollable).first);
      await _frames(tester);
      expect(find.byKey(const Key('paywall-terms')), findsOneWidget);
      expect(find.byKey(const Key('paywall-privacy')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall-redeem')));
      await _frames(tester);
      expect(purchases.redeemed, isTrue,
          reason: 'sin códigos propios: se abre el canje de la tienda');
      expect(find.byKey(const Key('redeem-field')), findsNothing);
    });

    testWidgets('sin tienda explica que aún no está publicada', (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 3400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final access = AccessService(MemoryShelfStore());
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: AccessScope(access: access, child: const PaywallPage()),
      ));
      await _frames(tester);
      expect(find.byKey(const Key('paywall-no-plans')), findsOneWidget);
      expect(find.byKey(const Key('paywall-redeem')), findsOneWidget);
    });
  });
}

/// Para buscar el candado sin exportar clases privadas.
abstract final class LockBadgeFinder {
  static const type = LockBadge;
}

/// El cielo del muro de pago se anima siempre: se avanza un rato en vez de esperar a que pare.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
