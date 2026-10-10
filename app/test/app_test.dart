import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_app/src/pack_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';

import 'file_bundle.dart';

final _bundle = FileBundle();

/// Un bundle al que le falta todo el arte (para comprobar que el cuento se lee igual).
class _NoArtBundle extends FileBundle {
  @override
  Future<ByteData> load(String key) => key.startsWith('assets/art/')
      ? Future.error(FlutterError('sin arte'))
      : super.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      key.startsWith('assets/art/')
          ? Future.error(FlutterError('sin arte'))
          : super.loadString(key, cache: cache);
}

FeedbackService _feedback() => FeedbackService(store: MemoryFeedbackStore());

void main() {
  /// El cuento está en un ListView perezoso: hay que desplazarse para construir el final.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 300);

  Future<void> openApp(WidgetTester tester, {int seed = 3}) async {
    await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        seedProvider: () => seed,
        feedback: _feedback(),
        animateArt: false));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra las enseñanzas del pack', (tester) async {
    await openApp(tester);
    expect(find.text('Caldero de Cuentos'), findsOneWidget);
    for (final name in [
      'Sorpréndeme',
      'Honestidad',
      'Generosidad',
      'Valentía'
    ]) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('crea un cuento con la enseñanza elegida', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Honestidad'));
    await tester.pump();
    await tester.tap(find.text('Crear cuento'));
    await tester.pumpAndSettle();

    // El héroe del pack medieval es siempre Aldo o Mara.
    expect(find.textContaining(RegExp('Aldo|Mara')), findsWidgets);
    await scrollTo(tester, find.text('Enseñanza'));
    expect(find.text('Enseñanza'), findsOneWidget);
    expect(
      find.text(
          'Ser honesto nos hace sentir ligeros, aunque nadie nos esté mirando.'),
      findsOneWidget,
    );
  });

  testWidgets('cada escena del cuento lleva su dibujo animado', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Valentía'));
    await tester.pump();
    await tester.tap(find.text('Crear cuento'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryStage), findsWidgets);
    expect(
        find.bySemanticsLabel('Ilustración animada del cuento'), findsWidgets);
  });

  testWidgets('si el arte no carga, el cuento se lee igual (solo texto)',
      (tester) async {
    await tester.pumpWidget(CalderoApp(
        bundle: _NoArtBundle(),
        seedProvider: () => 3,
        feedback: _feedback(),
        animateArt: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Honestidad'));
    await tester.pump();
    await tester.tap(find.text('Crear cuento'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryStage), findsNothing);
    expect(find.textContaining(RegExp('Aldo|Mara')), findsWidgets);
  });

  testWidgets('«Contar otro cuento» cambia el cuento y conserva la enseñanza',
      (tester) async {
    var seed = 3;
    await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        seedProvider: () => seed++,
        feedback: _feedback(),
        animateArt: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valentía'));
    await tester.pump();
    await tester.tap(find.text('Crear cuento'));
    await tester.pumpAndSettle();

    String storyText() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    final first = storyText();

    final another = find.text('Contar otro cuento');
    await tester.scrollUntilVisible(another, 300);
    await tester.tap(another);
    await tester.pumpAndSettle();

    expect(storyText(), isNot(first));
    await scrollTo(tester, find.text('Enseñanza'));
    expect(
      find.text(
          'Ser valiente no es no tener miedo, sino dar el primer paso a pesar de él.'),
      findsOneWidget,
    );
  });

  testWidgets('«Sorpréndeme» también genera un cuento', (tester) async {
    await openApp(tester, seed: 11);
    await tester.tap(find.text('Crear cuento'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Enseñanza'));
    expect(find.text('Enseñanza'), findsOneWidget);
  });

  testWidgets('el pack gratuito está declarado como asset de la app',
      (tester) async {
    // rootBundle hace E/S real: se ejecuta fuera del reloj simulado.
    final pack = await tester.runAsync(() => loadPack(rootBundle));
    expect(pack!.id, 'medieval');
    expect(pack.morals, isNotEmpty);
  });

  testWidgets('el botón del taller abre la pantalla de personajes',
      (tester) async {
    await openApp(tester);
    final button = find.text('Taller de personajes (prueba)');
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pump(); // arranca la carga
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Taller de personajes'), findsOneWidget);
    // El taller anima sin parar: se sale antes de terminar para liberar el ticker.
    final NavigatorState nav = tester.state(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
  });
}
