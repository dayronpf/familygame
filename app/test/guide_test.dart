import 'dart:io';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/guide/holograma_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Sin animaciones (las estrellitas del fondo no dejan que `pumpAndSettle` termine).
Widget _still(Widget home) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: home),
    );

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('el PDF «Holograma en casa»', () {
    final bytes = File('assets/guides/holograma-en-casa.pdf').readAsBytesSync();
    final text = String.fromCharCodes(bytes);

    test('es un PDF y todas sus páginas son tamaño carta (612 × 792 pt)', () {
      expect(text.startsWith('%PDF-'), isTrue);
      final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
      expect(pages, 5);
      final boxes =
          RegExp(r'/MediaBox\s*\[\s*0\s+0\s+612(\.0+)?\s+792(\.0+)?\s*\]')
              .allMatches(text)
              .length;
      expect(boxes, greaterThanOrEqualTo(1));
      // ninguna página en otro tamaño (por ejemplo A4 = 595 × 842)
      expect(text.contains('595.27'), isFalse);
      expect(text.contains('841.89'), isFalse);
    });

    test('está declarado como asset de la app', () async {
      final data = await FileBundle().load(guideAsset);
      expect(data.lengthInBytes, bytes.length);
    });
  });

  group('pantalla', () {
    testWidgets('avisa que se hace con un adulto y ofrece el PDF',
        (tester) async {
      phone(tester);
      Uint8List? sent;
      await tester.pumpWidget(_still(HologramGuidePage(
        bundle: FileBundle(),
        sender: (pdf) async => sent = pdf,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guide-adult-warning')), findsOneWidget);
      expect(
          find.textContaining('Solo con un adulto presente'), findsOneWidget);
      expect(find.textContaining('tijeras'), findsWidgets);
      expect(find.textContaining('carta'), findsWidgets);

      await tester.tap(find.byKey(const Key('guide-download')));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      expect(String.fromCharCodes(sent!.take(5)), '%PDF-');
      expect(sent!.length,
          File('assets/guides/holograma-en-casa.pdf').lengthSync());
    });

    testWidgets('si no se puede compartir, lo dice', (tester) async {
      phone(tester);
      await tester.pumpWidget(_still(HologramGuidePage(
        bundle: FileBundle(),
        sender: (pdf) async => throw PlatformException(code: 'sin-menu'),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guide-download')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No pudimos abrir el PDF'), findsOneWidget);
    });
  });

  group('desde la app', () {
    Future<void> openApp(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(CalderoApp(
        bundle: FileBundle(),
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        animateArt: false,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('el inicio tiene la tarjeta que lleva a la guía',
        (tester) async {
      await openApp(tester);
      await tester.scrollUntilVisible(find.byKey(const Key('guide-card')), 200);
      await tester.tap(find.byKey(const Key('guide-card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guide-download')), findsOneWidget);
    });

    testWidgets('Ajustes de adultos también la ofrece', (tester) async {
      await openApp(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) × (\d)').firstMatch(q)!;
      await tester.enterText(find.byKey(const Key('gate-answer')),
          '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const Key('settings-guide')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('settings-guide')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-guide')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guide-download')), findsOneWidget);
    });
  });
}
