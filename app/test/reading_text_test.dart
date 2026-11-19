import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/ui/reading_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mayúsculas y letra espaciada se aplican y se recuerdan',
      (tester) async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    late BuildContext ctx;
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    const base = TextStyle(fontSize: 20, height: 1.5);
    expect(ctx.readingText('Había una vez'), 'Había una vez');
    expect(ctx.readingStyle(base), base);

    await settings.setUpperCase(true);
    await settings.setSpacedText(true);
    expect(ctx.readingText('Había una vez'), 'HABÍA UNA VEZ');
    final spaced = ctx.readingStyle(base);
    expect(spaced.letterSpacing, greaterThan(0));
    expect(spaced.wordSpacing, greaterThan(0));
    expect(spaced.height, greaterThan(1.5));

    final again = AppSettings(store);
    await again.load();
    expect(again.upperCase, isTrue);
    expect(again.spacedText, isTrue);
  });
}
