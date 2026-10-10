import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'art_library.dart';
import 'rig_renderer.dart';
import 'scene_painter.dart';

/// Animación de cada rol según el ánimo (`mood`) que declara el fragmento.
/// Los nombres son clips de `art/clips/humanoid.json`; lo desconocido cae en `calm`.
const Map<String, Map<String, String>> moodClips = {
  'calm': {'hero': 'idle', 'helper': 'idle', 'villain': 'idle'},
  'tension': {'hero': 'surprised', 'helper': 'surprised', 'villain': 'talk'},
  'hope': {'hero': 'talk', 'helper': 'talk', 'villain': 'idle'},
  'mystery': {'hero': 'surprised', 'helper': 'idle', 'villain': 'idle'},
  'triumph': {'hero': 'cheer', 'helper': 'cheer', 'villain': 'scared'},
  'joy': {'hero': 'cheer', 'helper': 'wave', 'villain': 'bow'},
  'sleep': {'hero': 'idle', 'helper': 'idle', 'villain': 'idle'},
};

/// Orden de aparición de izquierda a derecha.
const List<String> roleOrder = ['hero', 'helper', 'villain'];

/// Posición horizontal (fracción del ancho visible) según cuántos personajes salen.
const Map<int, List<double>> slotX = {
  1: [0.5],
  2: [0.34, 0.68],
  3: [0.2, 0.48, 0.8],
};

/// Arte listo para dibujar: personajes compilados y escenas compiladas bajo demanda.
class StageArt {
  StageArt(this.library)
      : rigs = {
          for (final e in library.rigs.entries) e.key: CompiledRig(e.value)
        };

  final ArtLibrary library;
  final Map<String, CompiledRig> rigs;
  final Map<String, CompiledScene> _scenes = {};

  /// Escena compilada del lugar [placeId], o `null` si ese lugar no tiene arte.
  CompiledScene? sceneFor(String placeId) {
    final place = library.places[placeId];
    final scene = place == null ? null : library.scenes[place.scene];
    if (scene == null) return null;
    return _scenes.putIfAbsent(scene.id, () => CompiledScene(scene));
  }
}

/// Lo que se ve en una escena del cuento.
class StageSetup {
  const StageSetup({
    required this.placeId,
    required this.place,
    required this.scene,
    required this.actors,
  });

  final String placeId;
  final PlaceArt place;
  final CompiledScene scene;
  final List<ActorInstance> actors;
}

/// Decide fondo, personajes y animación de una escena del cuento a partir de sus directivas
/// (`bg`, `actors`, `mood`) y del reparto. Devuelve `null` si no hay arte para ese lugar.
StageSetup? stageFor(
  StageArt art,
  Map<String, Entity> cast,
  Map<String, Object?> directives,
) {
  final bg = directives['bg'];
  final placeEntity = cast[bg == 'place2' ? 'place2' : 'place'];
  if (placeEntity == null) return null;
  final place = art.library.places[placeEntity.id];
  final scene = art.sceneFor(placeEntity.id);
  if (place == null || scene == null) return null;

  final wanted = directives['actors'];
  final roles = [
    for (final r in roleOrder)
      if ((wanted is List ? wanted.contains(r) : r == 'hero') &&
          art.rigs.containsKey(cast[r]?.id))
        r,
  ];
  final mood = directives['mood'];
  final clips = moodClips[mood] ?? moodClips['calm']!;
  final xs = slotX[roles.length] ?? const <double>[];
  final actors = <ActorInstance>[];
  for (var i = 0; i < roles.length; i++) {
    final role = roles[i];
    final clip =
        art.library.clips.clips[clips[role]] ?? art.library.clips.clips['idle'];
    if (clip == null) continue;
    actors.add(ActorInstance(
      rig: art.rigs[cast[role]!.id]!,
      clip: clip,
      x: place.view.left + place.view.width * xs[i],
      y: place.floor,
      scale: place.scale,
      phase: i * 0.7,
    ));
  }
  return StageSetup(
    placeId: placeEntity.id,
    place: place,
    scene: scene,
    actors: actors,
  );
}

/// Carga el arte del pack; si falta o está roto devuelve `null` (el cuento se lee igual, sin dibujos).
Future<StageArt?> loadStageArt(AssetBundle bundle) async {
  try {
    return StageArt(await loadArtLibrary(bundle));
  } catch (e) {
    debugPrint('Sin arte para los cuentos: $e');
    return null;
  }
}

/// Ventana animada con el fondo del lugar y los personajes de una escena del cuento.
class StoryStage extends StatelessWidget {
  const StoryStage({super.key, required this.setup, required this.clock});

  final StageSetup setup;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final Rect view = setup.place.view;
    return Semantics(
      label: 'Ilustración animada del cuento',
      image: true,
      child: Center(
        // En pantallas anchas (tableta, horizontal) el dibujo no crece sin límite.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: view.width / view.height,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ScenePainter(
                    scene: setup.scene,
                    actors: setup.actors,
                    clock: clock,
                    view: view,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
