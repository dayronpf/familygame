import 'dart:io';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/pack_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bundle en memoria: lee los assets del disco de forma síncrona, así los tests
/// no dependen de E/S real dentro del reloj simulado.
class _FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) {
    final bytes = File(key).readAsBytesSync();
    return Future.value(ByteData.sublistView(Uint8List.fromList(bytes)));
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async =>
      parser(await loadString(key));
}

final _bundle = _FileBundle();

void main() {
  /// El cuento está en un ListView perezoso: hay que desplazarse para construir el final.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 300);

  Future<void> openApp(WidgetTester tester, {int seed = 3}) async {
    await tester
        .pumpWidget(CalderoApp(bundle: _bundle, seedProvider: () => seed));
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

    expect(find.textContaining('Había una vez'), findsOneWidget);
    await scrollTo(tester, find.text('Enseñanza'));
    expect(find.text('Enseñanza'), findsOneWidget);
    expect(
      find.text(
          'Ser honesto nos hace sentir ligeros, aunque nadie nos esté mirando.'),
      findsOneWidget,
    );
  });

  testWidgets('«Contar otro cuento» cambia el cuento y conserva la enseñanza',
      (tester) async {
    var seed = 3;
    await tester
        .pumpWidget(CalderoApp(bundle: _bundle, seedProvider: () => seed++));
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
    expect(pack!.id, 'demo');
    expect(pack.morals, isNotEmpty);
  });
}
