import 'dart:convert';
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

/// El mismo arte y el mismo pack, pero sin los cuentos de una edad (para probar lo que pasa cuando un pack no los
/// tiene todavía).
class FileBundleWithoutAge extends FileBundle {
  FileBundleWithoutAge(this.age);

  final String age;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final text = await super.loadString(key, cache: cache);
    if (!key.endsWith('packs/medieval/pack.json')) return text;
    final json = jsonDecode(text) as Map<String, Object?>;
    (json['premises']! as List).removeWhere(
      (p) => ((p as Map)['ages'] as List).contains(age),
    );
    return jsonEncode(json);
  }
}
