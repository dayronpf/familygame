import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/guide/holograma_guide.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/theme.dart';
import 'package:caldero_app/src/ui/splash_page.dart';
import 'package:caldero_app/src/ui/voice_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Herramienta de revisión, no una prueba: guarda capturas de las pantallas (splash, inicio, paquetes, mis cuentos,
/// cuento) en el tamaño de un teléfono, con letra real, para revisarlas a ojo. Se salta si no se pide.
///   UI_OUT=/tmp/ui flutter test test/ui_shots_manual_test.dart
/// `UI_SCALE=3` las saca a 1236×2676 px (tamaño de las fichas de las tiendas; por defecto 1×). Ver `tools/store/README.md`.
void main() {
  final out = Platform.environment['UI_OUT'];

  Future<void> loadFonts() async {
    const dir = '/opt/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
    Future<ByteData> bytes(String f) async => ByteData.sublistView(
        Uint8List.fromList(File('$dir/$f').readAsBytesSync()));
    final roboto = FontLoader('Roboto')
      ..addFont(bytes('Roboto-Regular.ttf'))
      ..addFont(bytes('Roboto-Medium.ttf'))
      ..addFont(bytes('Roboto-Bold.ttf'));
    await roboto.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(bytes('MaterialIcons-Regular.otf'));
    await icons.load();
  }

  testWidgets('capturas de la interfaz', (tester) async {
    await tester.runAsync(loadFonts);
    final w = double.tryParse(Platform.environment['UI_W'] ?? '') ?? 412;
    final h = double.tryParse(Platform.environment['UI_H'] ?? '') ?? 892;
    tester.view
      ..physicalSize = Size(w * 2, h * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Directory(out!).createSync(recursive: true);

    final boundary = GlobalKey();
    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final b = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await b.toImage(
          pixelRatio:
              double.tryParse(Platform.environment['UI_SCALE'] ?? '') ?? 1.0,
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    final shelf = StoryShelf(MemoryShelfStore());
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: CalderoApp(
        bundle: FileBundle(),
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        shelf: shelf,
        showSplash: true,
        seedProvider: () => 7,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await shot('01_splash_a');
    await tester.pump(const Duration(milliseconds: 1500));
    await shot('02_splash_b');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 500));
    await shot('03_home');

    await tester.tap(find.text('Valentía'));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('04_home_valentia');

    await tester.tap(find.text('Paquetes'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await shot('05_packs');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 600));
    await shot('06_packs_scroll');

    await tester.tap(find.text('Inicio'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Crear cuento'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1000));
    await shot('07_story');
    await tester.tap(find.byKey(const Key('favorite')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 600));
    await shot('08_home_after');
    await tester.tap(find.text('Mis cuentos'));
    await tester.pump(const Duration(milliseconds: 600));
    await shot('09_mis_cuentos');
  }, skip: out == null);

  testWidgets('capturas del wizard y de ajustes', (tester) async {
    await tester.runAsync(loadFonts);
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
        final image = await b.toImage(
          pixelRatio:
              double.tryParse(Platform.environment['UI_SCALE'] ?? '') ?? 1.0,
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: CalderoApp(
        bundle: FileBundle(),
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        settings: AppSettings(MemorySettingsStore()),
        voices: VoiceServices(
          listVoices: () async => const [
            TtsVoice(name: 'es-es-x-eea-local', locale: 'es-ES'),
            TtsVoice(name: 'es-us-x-sfb-local', locale: 'es-US'),
            TtsVoice(name: 'es-mx-x-bkr-local', locale: 'es-MX'),
          ],
        ),
        showWizard: true,
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 600));
    await shot('10_wizard_idioma');
    for (final n in ['11_wizard_voz', '12_wizard_edad', '13_wizard_resumen']) {
      await tester.tap(find.byKey(const Key('wizard-next')).evaluate().isEmpty
          ? find.byKey(const Key('wizard-start'))
          : find.byKey(const Key('wizard-next')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      if (n == '12_wizard_edad') {
        await tester.tap(find.byKey(const Key('age-2-3')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await shot(n);
    }
  }, skip: out == null);

  testWidgets('captura de la guía del holograma', (tester) async {
    await tester.runAsync(loadFonts);
    tester.view
      ..physicalSize = const Size(412 * 2, 892 * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Directory(out!).createSync(recursive: true);
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: nightTheme(),
          home: HologramGuidePage(bundle: FileBundle()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      final b =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await b.toImage(
        pixelRatio:
            double.tryParse(Platform.environment['UI_SCALE'] ?? '') ?? 1.0,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/14_guia.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }, skip: out == null);

  testWidgets('fotogramas del splash', (tester) async {
    await tester.runAsync(loadFonts);
    tester.view
      ..physicalSize = const Size(412 * 2, 892 * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Directory(out!).createSync(recursive: true);
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: nightTheme(),
        home: SplashPage(
          onFinished: () {},
          ready: Completer<void>().future,
          minimum: const Duration(milliseconds: 3600),
        ),
      ),
    ));
    var elapsed = 0;
    for (final ms in [400, 900, 1500, 2100, 2700, 3300, 3900]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await tester.runAsync(() async {
        final b = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 0.7);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/splash_$ms.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  }, skip: out == null);
}
