import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/services.dart';

/// Paquete que se abre la primera vez (el gratuito incluido en la app).
const String defaultPackId = 'medieval';

/// Ruta de un pack incluido en los assets de la app.
String packPath(String id) => 'assets/packs/$id/pack.json';

/// Ruta del pack gratuito incluido en la app.
final String bundledPackPath = packPath(defaultPackId);

/// Lee un pack desde los assets de la app.
Future<Pack> loadPack(AssetBundle bundle, {String? path}) async {
  final raw = await bundle.loadString(path ?? bundledPackPath);
  return Pack.fromJson(jsonDecode(raw) as Map<String, Object?>);
}
