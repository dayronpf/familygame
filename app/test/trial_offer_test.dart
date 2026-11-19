import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/store/access.dart';
import 'package:caldero_app/src/store/purchases.dart';
import 'package:caldero_app/src/store/trial_offer_page.dart';
import 'package:caldero_app/src/ui/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Tienda de mentira: con planes (7 días gratis en el anual) o sin ninguno.
class _Store extends PurchaseGateway {
  _Store({this.withPlans = true});
  final bool withPlans;

  @override
  String? get message => null;
  @override
  PurchaseState get state => PurchaseState.idle;
  @override
  Future<List<PlanOption>> plans() async => withPlans
      ? const [
          PlanOption(
              id: 'anual', price: 'USD 14,99', yearly: true, trialDays: 7),
          PlanOption(
              id: 'mensual', price: 'USD 2,99', yearly: false, trialDays: 7),
        ]
      : const [];
  @override
  Future<void> buy(PlanOption plan) async {}
  @override
  Future<void> restore() async {}
  @override
  Future<bool> redeemWithStore() async => false;
}

class _Sound implements SplashSound {
  int plays = 0;
  @override
  Future<void> play() async => plays++;
}

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> finishWizard(WidgetTester tester, PurchaseGateway? store) async {
    phone(tester);
    await tester.pumpWidget(CalderoApp(
      bundle: FileBundle(),
      seedProvider: () => 3,
      feedback: FeedbackService(store: MemoryFeedbackStore()),
      settings: AppSettings(MemorySettingsStore()),
      access: AccessService(MemoryShelfStore(), devAvailable: false),
      purchases: store,
      showWizard: true,
      animateArt: false,
      catalogOnly: true,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard-next')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wizard-name')), 'Sofía');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard-start')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'al terminar el asistente se ofrece la prueba gratis, y «Ahora no» entra al inicio sin pagar',
      (tester) async {
    await finishWizard(tester, _Store());
    expect(find.byType(TrialOfferPage), findsOneWidget);
    expect(find.text('¡Listo! Su prueba de 7 días gratis los espera'),
        findsOneWidget);
    expect(find.text('Probar 7 días gratis'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('offer-skip')), 300);
    await tester.ensureVisible(find.byKey(const Key('offer-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(TrialOfferPage), findsNothing);
    expect(find.text('Contar un cuento'), findsOneWidget);
  });

  testWidgets('«Probar gratis» pide antes la pregunta para adultos',
      (tester) async {
    await finishWizard(tester, _Store());
    await tester.scrollUntilVisible(find.byKey(const Key('offer-try')), 300);
    await tester.ensureVisible(find.byKey(const Key('offer-try')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offer-try')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gate-question')), findsOneWidget);
  });

  testWidgets('si la tienda no tiene planes no se ofrece nada', (tester) async {
    await finishWizard(tester, _Store(withPlans: false));
    expect(find.byType(TrialOfferPage), findsNothing);
    expect(find.text('Contar un cuento'), findsOneWidget);
  });

  testWidgets(
      'sin tienda (pruebas, versión de desarrollo) va directo al inicio',
      (tester) async {
    await finishWizard(tester, null);
    expect(find.byType(TrialOfferPage), findsNothing);
    expect(find.text('Contar un cuento'), findsOneWidget);
  });

  testWidgets(
      'la bienvenida suena una vez; sin efectos o con «reducir movimiento», no',
      (tester) async {
    Future<_Sound> show({bool effects = true, bool reduce = false}) async {
      final sound = _Sound();
      final settings = AppSettings(MemorySettingsStore());
      await settings.setEffects(effects);
      await tester.pumpWidget(MaterialApp(
        home: SettingsScope(
          settings: settings,
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: SplashPage(
              onFinished: () {},
              sound: sound,
              minimum: const Duration(milliseconds: 100),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
      return sound;
    }

    expect((await show()).plays, 1);
    expect((await show(effects: false)).plays, 0);
    expect((await show(reduce: true)).plays, 0);
  });
}
