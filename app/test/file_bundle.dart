import 'dart:io';

import 'package:flutter/services.dart';

/// Bundle en memoria: lee los assets del disco de forma síncrona, así los tests
/// no dependen de E/S real dentro del reloj simulado.
class FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) {
    final bytes = File(key).readAsBytesSync();
    return Future.value(ByteData.sublistView(Uint8List.fromList(bytes)));
  }

  /// Los textos de más de 50 KB se decodifican en otro hilo (`compute`), que el reloj simulado de los
  /// tests no completa nunca: aquí se leen siempre de forma síncrona.
  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      Future.value(File(key).readAsStringSync());

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async =>
      parser(await loadString(key));
}
