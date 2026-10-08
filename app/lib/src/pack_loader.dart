import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/services.dart';

/// Ruta del pack gratuito incluido en la app.
const String bundledPackPath = 'assets/packs/demo/pack.json';

/// Lee un pack desde los assets de la app.
Future<Pack> loadPack(AssetBundle bundle,
    {String path = bundledPackPath}) async {
  final raw = await bundle.loadString(path);
  return Pack.fromJson(jsonDecode(raw) as Map<String, Object?>);
}
