import 'dart:io';

import 'package:caldero_app/src/brand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el nombre del juego no está escrito a mano en el código', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('brand.dart')) continue;
      if (f.readAsStringSync().contains(appName)) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'usa appName (lib/src/brand.dart): ${offenders.join(', ')}');
  });

  test('Android e iOS enseñan el mismo nombre que la app', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll('&amp;', '&');
    expect(manifest, contains('android:label="$appName"'));
    final plist = File('ios/Runner/Info.plist')
        .readAsStringSync()
        .replaceAll('&amp;', '&');
    expect(
        plist,
        matches(RegExp(
            '<key>CFBundleDisplayName</key>\\s*<string>${RegExp.escape(appName)}</string>')));
  });

  test('el nombre y la frase tienen un largo razonable para un icono', () {
    expect(appName.length, inInclusiveRange(1, 30));
    expect(appTagline, isNotEmpty);
  });
}
