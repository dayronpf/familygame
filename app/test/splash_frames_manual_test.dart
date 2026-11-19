import 'dart:io';
import 'dart:ui' as ui;

import 'package:caldero_app/src/store/paywall_page.dart';
import 'package:caldero_app/src/store/access.dart';
import 'package:caldero_app/src/store/purchases.dart';
import 'package:caldero_app/src/store/trial_offer_page.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/theme.dart';
import 'package:caldero_app/src/ui/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Herramienta de revisión, no una prueba: fotogramas de la bienvenida y la pantalla de la prueba gratis.
///   UI_OUT=/tmp/ui FLUTTER_FONTS=… flutter test test/splash_frames_manual_test.dart
class _Store extends PurchaseGateway {
  @override
  String? get message => null;
  @override
  PurchaseState get state => PurchaseState.idle;
  @override
  Future<List<PlanOption>> plans() async => const [
        PlanOption(id: 'anual', price: 'USD 14,99', yearly: true, trialDays: 7),
      ];
  @override
  Future<void> buy(PlanOption plan) async {}
  @override
  Future<void> restore() async {}
  @override
  Future<bool> redeemWithStore() async => false;
}

void main() {
  final out = Platform.environment['UI_OUT'];

  testWidgets('fotogramas', (tester) async {
    await tester.runAsync(() async {
      final dir = Platform.environment['FLUTTER_FONTS']!;
      Future<ByteData> bytes(String f) async =>
          ByteData.sublistView(File('$dir/$f').readAsBytesSync());
      final roboto = FontLoader('Roboto')
        ..addFont(bytes('Roboto-Regular.ttf'))
        ..addFont(bytes('Roboto-Medium.ttf'))
        ..addFont(bytes('Roboto-Bold.ttf'));
      await roboto.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(bytes('MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view
      ..physicalSize = const Size(412 * 2, 892 * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Directory(out!).createSync(recursive: true);
    final boundary = GlobalKey();
    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final b = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: nightTheme(),
        home: SplashPage(onFinished: () {}),
      ),
    ));
    var ms = 0;
    for (final at in [300, 700, 1100, 1500, 2000, 2600, 3200, 4200]) {
      await tester.pump(Duration(milliseconds: at - ms));
      ms = at;
      await shot('splash_${at.toString().padLeft(4, '0')}');
    }

    final access = AccessService(MemoryShelfStore(), devAvailable: false);
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: nightTheme(),
        home: AccessScope(
          access: access,
          child: PurchasesScope(
            purchases: _Store(),
            child: TrialOfferPage(onClose: () {}),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1000));
    await shot('offer');
  }, skip: out == null);
}
