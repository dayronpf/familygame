import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';

/// Uso: `dart run caldero_engine:validate_pack <ruta/pack.json>...`
///
/// Sale con código 1 si algún pack tiene problemas (para CI).
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run caldero_engine:validate_pack <pack.json>...');
    exit(64);
  }
  var failed = false;
  for (final path in args) {
    try {
      final json =
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      final report = validatePack(Pack.fromJson(json));
      stdout.writeln(
        '$path: ${report.rendersChecked} renders, ${report.problems.length} problemas',
      );
      for (final p in report.problems) {
        stdout.writeln(' - $p');
      }
      failed |= !report.isValid;
    } on PackFormatException catch (e) {
      stdout.writeln('$path: $e');
      failed = true;
    } on FormatException catch (e) {
      stdout.writeln('$path: JSON inválido: ${e.message}');
      failed = true;
    } on FileSystemException catch (e) {
      stdout.writeln('$path: no se puede leer: ${e.message}');
      failed = true;
    }
  }
  exit(failed ? 1 : 0);
}
