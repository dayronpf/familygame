import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:url_launcher/url_launcher.dart';

import 'access.dart';

/// Un plan que se ofrece en el muro de pago (con el precio que da la tienda, en la moneda del país).
class PlanOption {
  const PlanOption({
    required this.id,
    required this.price,
    required this.yearly,
    this.trialDays = 0,
    this.monthlyEquivalent,
    this.details,
    this.offerToken,
  });

  /// `anual` o `mensual` (el plan base de Google Play).
  final String id;
  final String price;
  final bool yearly;
  final int trialDays;

  /// El anual partido en meses («USD 0,83 / mes»), si la tienda da el importe.
  final String? monthlyEquivalent;
  final ProductDetails? details;
  final String? offerToken;
}

/// Lo que pasa con una compra, para enseñarlo en el muro de pago.
enum PurchaseState {
  idle,
  loading,
  buying,
  verifying,
  done,
  cancelled,
  error,
  noServer
}

/// Compras con Google Play (y App Store más adelante): carga los planes, compra, restaura y manda cada compra al
/// servidor para verificarla. Lo comprado nunca se da por bueno sin el servidor.
abstract class PurchaseGateway extends ChangeNotifier {
  PurchaseState get state;
  String? get message;
  Future<List<PlanOption>> plans();
  Future<void> buy(PlanOption plan);
  Future<void> restore();

  /// Canjear un código **de la tienda** (las tiendas no permiten códigos propios que abran contenido de pago):
  /// en iPhone, la hoja de canje de Apple; en Android, la página de canje de Google Play. Lo canjeado llega como una
  /// compra más (y se verifica en el servidor). `false` si esta plataforma no tiene canje.
  Future<bool> redeemWithStore() async => false;
}

class StorePurchases extends PurchaseGateway {
  StorePurchases(this.access, {InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {
      _set(PurchaseState.error, 'La tienda no respondió. Inténtalo de nuevo.');
    });
  }

  final AccessService access;
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  PurchaseState _state = PurchaseState.idle;
  String? _message;

  @override
  PurchaseState get state => _state;
  @override
  String? get message => _message;

  void _set(PurchaseState s, [String? m]) {
    _state = s;
    _message = m;
    notifyListeners();
  }

  @override
  Future<List<PlanOption>> plans() async {
    if (!await _iap.isAvailable()) return const [];
    if (defaultTargetPlatform == TargetPlatform.iOS) return _iosPlans();
    final r = await _iap.queryProductDetails({subscriptionProductId});
    final out = <PlanOption>[];
    for (final d in r.productDetails) {
      if (d is GooglePlayProductDetails && d.subscriptionIndex != null) {
        final offer =
            d.productDetails.subscriptionOfferDetails![d.subscriptionIndex!];
        // Solo la oferta con prueba gratis o el plan base sin oferta (Google da ambas: nos quedamos con la mejor)
        final phases = offer.pricingPhases;
        final paid = phases.lastWhere((p) => p.priceAmountMicros > 0,
            orElse: () => phases.last);
        final free = phases.where((p) => p.priceAmountMicros == 0);
        final trialDays = free.isEmpty ? 0 : _days(free.first.billingPeriod);
        final yearly = paid.billingPeriod == 'P1Y';
        final existing = out.indexWhere((o) => o.id == offer.basePlanId);
        final option = PlanOption(
          id: offer.basePlanId,
          price: paid.formattedPrice,
          yearly: yearly,
          trialDays: trialDays,
          monthlyEquivalent: yearly
              ? _perMonth(paid.priceAmountMicros, paid.priceCurrencyCode)
              : null,
          details: d,
          offerToken: offer.offerIdToken,
        );
        if (existing < 0) {
          out.add(option);
        } else if (trialDays > out[existing].trialDays) {
          out[existing] = option;
        }
      }
    }
    out.sort((a, b) => a.yearly == b.yearly ? 0 : (a.yearly ? -1 : 1));
    return out;
  }

  /// App Store: un producto por duración (`iosSubscriptionProducts`).
  Future<List<PlanOption>> _iosPlans() async {
    final r =
        await _iap.queryProductDetails(iosSubscriptionProducts.values.toSet());
    final out = <PlanOption>[];
    for (final e in iosSubscriptionProducts.entries) {
      final d = r.productDetails.where((p) => p.id == e.value).firstOrNull;
      if (d == null) continue;
      final yearly = e.key == 'anual';
      var trial = iosTrialDays;
      if (d is AppStoreProductDetails) {
        final intro = d.skProduct.introductoryPrice;
        trial = intro != null &&
                intro.paymentMode ==
                    SKProductDiscountPaymentMode
                        .freeTrail // («freeTrail»: así se llama en el plugin)
            ? _skDays(intro.subscriptionPeriod) * intro.numberOfPeriods
            : 0;
      }
      out.add(PlanOption(
        id: e.key,
        price: d.price,
        yearly: yearly,
        trialDays: trial,
        monthlyEquivalent: yearly
            ? _perMonth((d.rawPrice * 1e6).round(), d.currencyCode)
            : null,
        details: d,
      ));
    }
    return out;
  }

  static int _skDays(SKProductSubscriptionPeriodWrapper p) =>
      p.numberOfUnits *
      switch (p.unit) {
        SKSubscriptionPeriodUnit.day => 1,
        SKSubscriptionPeriodUnit.week => 7,
        SKSubscriptionPeriodUnit.month => 30,
        SKSubscriptionPeriodUnit.year => 365,
      };

  static int _days(String iso) {
    final m = RegExp(r'P(?:(\d+)W)?(?:(\d+)D)?').firstMatch(iso);
    if (m == null) return 0;
    return int.parse(m.group(1) ?? '0') * 7 + int.parse(m.group(2) ?? '0');
  }

  static String _perMonth(int micros, String currency) {
    final v = micros / 1e6 / 12;
    return '$currency ${v.toStringAsFixed(2).replaceAll('.', ',')} / mes';
  }

  @override
  Future<void> buy(PlanOption plan) async {
    final d = plan.details;
    if (d == null) return;
    _set(PurchaseState.buying);
    final param = defaultTargetPlatform == TargetPlatform.android
        ? GooglePlayPurchaseParam(
            productDetails: d, offerToken: plan.offerToken)
        : PurchaseParam(productDetails: d);
    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      _set(PurchaseState.error,
          'No se pudo abrir la compra. Inténtalo de nuevo.');
    }
  }

  @override
  Future<void> restore() async {
    _set(PurchaseState.loading);
    try {
      await _iap.restorePurchases();
      // Lo canjeado con códigos vive en el servidor: también se pregunta
      await access.refresh(force: true);
      if (_state == PurchaseState.loading) {
        _set(
            access.premium ? PurchaseState.done : PurchaseState.idle,
            access.premium
                ? null
                : 'No encontramos compras en esta cuenta de la tienda.');
      }
    } catch (_) {
      _set(PurchaseState.error, 'No se pudo restaurar. Revisa la conexión.');
    }
  }

  @override
  Future<bool> redeemWithStore() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _iap
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>()
            .presentCodeRedemptionSheet();
        return true;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Google Play no tiene hoja de canje dentro de la app: se abre su página de canje
        return await launchUrl(Uri.parse('https://play.google.com/redeem'),
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // sin tienda en este dispositivo
    }
    return false;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _set(PurchaseState.buying, 'Esperando a la tienda…');
        case PurchaseStatus.canceled:
          _set(PurchaseState.cancelled);
        case PurchaseStatus.error:
          _set(PurchaseState.error, 'La tienda no completó la compra.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _set(PurchaseState.verifying, 'Comprobando la compra…');
          final android = defaultTargetPlatform == TargetPlatform.android;
          final r = await access.verifyPurchase(
            platform: android ? 'android' : 'ios',
            productId: p.productID,
            purchaseToken:
                android ? p.verificationData.serverVerificationData : null,
            transactionId: android ? null : p.purchaseID,
          );
          switch (r.outcome) {
            case StoreOutcome.ok:
              // Solo se confirma a la tienda lo que el servidor verificó (si no, Google la reembolsa a los 3 días).
              if (p.pendingCompletePurchase) await _iap.completePurchase(p);
              _set(PurchaseState.done);
            case StoreOutcome.invalid:
            case StoreOutcome.used:
              if (p.pendingCompletePurchase) await _iap.completePurchase(p);
              _set(PurchaseState.error,
                  'La tienda dice que esta compra no está vigente.');
            case StoreOutcome.noServer:
              _set(PurchaseState.noServer,
                  'Esta versión no tiene servidor para verificar compras.');
            case StoreOutcome.unavailable:
              // Se reintenta solo: la tienda vuelve a mandar la compra al abrir la app
              _set(PurchaseState.error,
                  'No pudimos comprobar la compra ahora. Lo intentaremos de nuevo.');
          }
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
