import 'dart:convert';

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter/services.dart';

/// Cómo se muestra un lugar del pack: qué escena lo dibuja, qué parte de ella se ve, dónde pisan
/// los personajes y a qué tamaño. Viene de `places` en `index.json`.
class PlaceArt {
  const PlaceArt({
    required this.scene,
    required this.view,
    required this.floor,
    required this.scale,
  });

  factory PlaceArt.fromJson(Map<String, Object?> j) {
    final v = (j['view']! as List<Object?>).cast<num>();
    return PlaceArt(
      scene: j['scene']! as String,
      view: Rect.fromLTWH(
          v[0].toDouble(), v[1].toDouble(), v[2].toDouble(), v[3].toDouble()),
      floor: (j['floor']! as num).toDouble(),
      scale: (j['scale']! as num).toDouble(),
    );
  }

  final String scene;

  /// Parte visible de la escena, en coordenadas de la escena.
  final Rect view;

  /// Coordenada y de los pies de los personajes.
  final double floor;
  final double scale;
}

/// Arte cargado: personajes, biblioteca de clips y escenas.
class ArtLibrary {
  ArtLibrary({
    required this.rigs,
    required this.clips,
    required this.scene,
    this.scenes = const {},
    this.places = const {},
  });

  final Map<String, Rig> rigs;
  final ClipLibrary clips;

  /// Primera escena del índice (la usa el Taller).
  final Scene scene;

  /// Todas las escenas por id.
  final Map<String, Scene> scenes;

  /// Lugares del pack (id del lugar → su escena y dónde se colocan los personajes).
  final Map<String, PlaceArt> places;
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
  final scenes = <String, Scene>{};
  for (final path in (index['scenes']! as List<Object?>).cast<String>()) {
    final scene = Scene.fromJson(await _json(bundle, '$artRoot$path'));
    scenes[scene.id] = scene;
  }
  final places = <String, PlaceArt>{
    for (final e
        in ((index['places'] as Map<String, Object?>?) ?? const {}).entries)
      e.key: PlaceArt.fromJson(e.value! as Map<String, Object?>),
  };
  return ArtLibrary(
    rigs: rigs,
    clips:
        ClipLibrary.fromJson(await _json(bundle, '$artRoot${index['clips']}')),
    scene: scenes.values.first,
    scenes: scenes,
    places: places,
  );
}
