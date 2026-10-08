import 'dart:convert';

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter/services.dart';

/// Arte cargado: personajes, biblioteca de clips y escena.
class ArtLibrary {
  ArtLibrary({required this.rigs, required this.clips, required this.scene});

  final Map<String, Rig> rigs;
  final ClipLibrary clips;
  final Scene scene;
}

const String artRoot = 'assets/art/';

Future<Map<String, Object?>> _json(AssetBundle bundle, String path) async =>
    jsonDecode(await bundle.loadString(path)) as Map<String, Object?>;

/// Lee `assets/art/medieval/index.json` y todo lo que referencia.
Future<ArtLibrary> loadArtLibrary(
  AssetBundle bundle, {
  String pack = 'medieval',
}) async {
  final index = await _json(bundle, '$artRoot$pack/index.json');
  final rigs = <String, Rig>{};
  for (final path in (index['rigs']! as List<Object?>).cast<String>()) {
    final rig = Rig.fromJson(await _json(bundle, '$artRoot$path'));
    rigs[rig.id] = rig;
  }
  final scenePath = (index['scenes']! as List<Object?>).cast<String>().first;
  return ArtLibrary(
    rigs: rigs,
    clips:
        ClipLibrary.fromJson(await _json(bundle, '$artRoot${index['clips']}')),
    scene: Scene.fromJson(await _json(bundle, '$artRoot$scenePath')),
  );
}
