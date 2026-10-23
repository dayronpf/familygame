import 'dart:io';

import 'package:caldero_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recorre la app REAL (la de `main()`, con sus ajustes en el teléfono, el pack de verdad y los plugins de Android) como
/// lo haría una familia la primera vez: bienvenida → asistente → inicio → ajustes de adultos → un cuento. Es lo que
/// ningún test de widgets puede comprobar (plugins de audio y voz, datos guardados, assets empaquetados).
///
/// Con un dispositivo conectado, `flutter test integration_test/app_test.dart` (sin teléfono no hay dónde ejecutarla)
/// Lista de dispositivos: `flutter devices`; se elige uno con `-d ID_DEL_DISPOSITIVO`.
/// En GitHub: workflow «Android (emulador)».
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Avanza el reloj hasta que aparezca [finder] (las animaciones infinitas impiden `pumpAndSettle`).
  Future<void> waitFor(WidgetTester t, Finder finder,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('No apareció: $finder');
  }

  Future<void> shot(String name) async {
    try {
      await binding.takeScreenshot(name);
    } catch (_) {} // en `flutter test` sin dispositivo no hay capturas
  }

  testWidgets('primera vez: asistente, inicio, ajustes y un cuento',
      (tester) async {
    // Sin dispositivo real (flutter-tester) no hay plugin de preferencias: se usan unas en memoria.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      SharedPreferences.setMockInitialValues({});
    }
    await app.main();
    await waitFor(tester, find.byKey(const Key('wizard-skip')));
    await shot('01-asistente');

    // «Saltar» deja los valores por defecto y entra al inicio. La bienvenida animada puede tapar un rato el asistente:
    // se reintenta el toque hasta que aparece el inicio.
    final home = find.text('Crear cuento');
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (home.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      final skip = find.byKey(const Key('wizard-skip'));
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip, warnIfMissed: false);
      }
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    await waitFor(tester, home, timeout: const Duration(seconds: 5));
    await shot('02-inicio');

    // Ajustes de adultos: pregunta de multiplicar → pantalla de ajustes (no debe quedarse cargando)
    await tester.tap(find.byKey(const Key('open-settings')));
    await waitFor(tester, find.byKey(const Key('gate-question')));
    final q = tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
    final m = RegExp(r'(\d) por (\d)').firstMatch(q)!;
    await tester.enterText(find.byKey(const Key('gate-answer')),
        '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
    await tester.tap(find.byKey(const Key('gate-ok')));
    await waitFor(tester, find.text('Cuentos y voz'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await shot('03-ajustes');

    // Política de privacidad (assets de verdad)
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-privacy')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-privacy')));
    await waitFor(tester, find.textContaining('Política de privacidad'));
    await shot('04-privacidad');
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pageBack(); // de Ajustes al inicio
    await waitFor(tester, find.text('Crear cuento'));

    // Un cuento
    await tester.tap(find.text('Crear cuento'));
    await waitFor(tester, find.byIcon(Icons.movie_filter),
        timeout: const Duration(seconds: 90));
    await shot('05-cuento');
    expect(find.text('Enseñanza'),
        findsNothing); // aún no se ha leído hasta el final: no debe romper
  });
}
