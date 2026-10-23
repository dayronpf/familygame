import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Un almacén cuyo contenido no se puede leer (datos de una versión antigua, disco lleno…).
class _BrokenStore extends MemoryFeedbackStore {
  bool broken = false;

  @override
  Future<bool> readEnabled() =>
      broken ? Future.error(StateError('ilegible')) : super.readEnabled();

  @override
  Future<List<Map<String, Object?>>> readQueue() =>
      broken ? Future.error(StateError('ilegible')) : super.readQueue();
}

void main() {
  testWidgets('los ajustes se abren aunque lo guardado no se pueda leer',
      (tester) async {
    final settings = AppSettings(MemorySettingsStore());
    await settings.completeWizard(age: '4-5');
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _BrokenStore();
    await tester.pumpWidget(CalderoApp(
      bundle: FileBundle(),
      feedback: FeedbackService(store: store),
      settings: settings,
      showWizard: false,
      animateArt: false,
    ));
    await tester.pumpAndSettle();
    store.broken = true; // a partir de aquí, lo guardado no se puede leer
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    final q = tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
    final m = RegExp(r'(\d) por (\d)').firstMatch(q)!;
    await tester.enterText(find.byKey(const Key('gate-answer')),
        '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
    await tester.tap(find.byKey(const Key('gate-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Cuentos y voz'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
