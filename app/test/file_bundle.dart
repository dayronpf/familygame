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

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async =>
      parser(await loadString(key));
}
