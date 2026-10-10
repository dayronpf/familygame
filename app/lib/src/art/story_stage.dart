import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter/material.dart' hide Clip;

import 'art_library.dart';
import 'rig_renderer.dart';
import 'scene_painter.dart';

/// Animación de cada rol según el ánimo (`mood`) de la escena cuando la escena no dice otra cosa.
/// Los nombres son clips de `art/clips/humanoid.json`; lo desconocido cae en `calm`.
/// `extra` = los secundarios (Tomás, Lía, los vecinos…).
const Map<String, Map<String, String>> moodClips = {
  'calm': {
    'hero': 'idle',
    'helper': 'idle',
    'villain': 'idle',
    'extra': 'idle'
  },
  'tension': {
    'hero': 'surprised',
    'helper': 'surprised',
    'villain': 'talk',
    'extra': 'surprised'
  },
  'hope': {
    'hero': 'talk',
    'helper': 'talk',
    'villain': 'idle',
    'extra': 'idle'
  },
  'mystery': {
    'hero': 'surprised',
    'helper': 'idle',
    'villain': 'idle',
    'extra': 'idle'
  },
  'triumph': {
    'hero': 'cheer',
    'helper': 'cheer',
    'villain': 'scared',
    'extra': 'clap'
  },
  'joy': {'hero': 'cheer', 'helper': 'wave', 'villain': 'bow', 'extra': 'clap'},
  'sleep': {
    'hero': 'sleep',
    'helper': 'sleep',
    'villain': 'idle',
    'extra': 'sleep'
  },
};

/// Luz de cada ambiente: se multiplica sobre la escena.
const Map<String, Color> lightTints = {
  'dusk': Color(0xFFFFD2B0),
  'night': Color(0xFF8A90CC),
  'dark': Color(0xFF50567F),
  'cold': Color(0xFFD0E2FF),
};

/// Orden de aparición de izquierda a derecha en las escenas antiguas (`actors`).
const List<String> roleOrder = ['hero', 'helper', 'villain'];

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

  /// Un clip por nombre, de los personajes o de los objetos.
  Clip? clip(String? name) =>
      library.clips.clips[name] ?? library.propClips[name];
}

/// Lo que se ve en una escena del cuento.
class StageSetup {
  const StageSetup({
    required this.placeId,
    required this.place,
    required this.scene,
    required this.actors,
    this.props = const [],
    this.tint,
  });

  final String placeId;
  final PlaceArt place;
  final CompiledScene scene;
  final List<ActorInstance> actors;

  /// Objetos de la trama (campana, olla, linterna…).
  final List<ActorInstance> props;

  /// Luz de la escena, o `null` (pleno día).
  final Color? tint;
}

/// Decide fondo, personajes, objetos, animación y luz de una escena del cuento a partir de sus
/// directivas y del reparto. Devuelve `null` si no hay arte para ese lugar.
///
/// Directivas: `bg` (ranura de lugar), `stage` (lista de personajes de izquierda a derecha: `who` = ranura del
/// reparto o `rig` = secundario, con `clip` y `x` opcionales; en packs antiguos, `actors`), `mood`,
/// `props` (`prop`, `x`, `clip`, `scale`, `lift`, `front`, `emit`) y `light`.
StageSetup? stageFor(
  StageArt art,
  Map<String, Entity> cast,
  Map<String, Object?> directives,
) {
  // `bg` es la ranura de lugar del reparto (premisas: `torre`, `bosque`…; esquema 1: `place`/`place2`).
  final bg = directives['bg'];
  final slot = bg is String ? cast[bg] : null;
  final placeEntity = slot is Place ? slot : cast['place'];
  if (placeEntity == null) return null;
  final place = art.library.places[placeEntity.id];
  final scene = art.sceneFor(placeEntity.id);
  if (place == null || scene == null) return null;

  var entries = stageEntries(directives);
  if (directives['stage'] == null && directives['actors'] == null) {
    entries = const [StageEntry(who: 'hero')];
  }
  final mood = directives['mood'];
  final clips = moodClips[mood] ?? moodClips['calm']!;
  final view = place.view;

  // Los personajes con rig se reparten a partes iguales; `x` fija la posición de uno concreto.
  final resolved = <(String rigId, StageEntry e, String role)>[];
  for (final e in entries) {
    final who = e.who;
    final rigId = who != null ? cast[who]?.id : e.rig;
    if (rigId == null || !art.rigs.containsKey(rigId)) continue;
    resolved.add((rigId, e, who ?? 'extra'));
  }
  final n = resolved.length;
  final actors = <ActorInstance>[];
  for (var i = 0; i < n; i++) {
    final (rigId, e, role) = resolved[i];
    final clip = art.clip(e.clip) ??
        art.clip(clips[role == 'extra' ? 'extra' : role]) ??
        art.clip('idle');
    if (clip == null) continue;
    // Con 4 o más personajes, los impares se adelantan y empequeñecen un poco para dar profundidad;
    // con pocos, crecen un poco para llenar la imagen.
    final back = n >= 4 && i.isOdd;
    final framing = n <= 2 ? 1.2 : (n == 3 ? 1.1 : 1.0);
    actors.add(ActorInstance(
      rig: art.rigs[rigId]!,
      clip: clip,
      x: view.left + view.width * (e.x ?? (0.08 + 0.84 * (i + 0.5) / n)),
      y: place.floor - (back ? 8 : 0),
      scale: place.scale *
          framing *
          (art.library.sizes[rigId] ?? 1) *
          (back ? 0.95 : 1),
      phase: i * 0.7,
    ));
  }

  final props = <ActorInstance>[];
  final rawProps = directives['props'];
  if (rawProps is List) {
    for (final p in rawProps) {
      if (p is! Map) continue;
      final rig = art.rigs[p['prop']];
      final clip = art.clip(p['clip'] as String?) ?? art.clip('still');
      if (rig == null || clip == null) continue;
      props.add(ActorInstance(
        rig: rig,
        clip: clip,
        x: view.left + view.width * ((p['x'] as num?)?.toDouble() ?? 0.5),
        y: place.floor - ((p['lift'] as num?)?.toDouble() ?? 0),
        scale: place.scale * ((p['scale'] as num?)?.toDouble() ?? 1),
        shadow: (p['lift'] as num?) == null,
        front: p['front'] == true,
        emissive: p['emit'] == true,
      ));
    }
  }

  return StageSetup(
    placeId: placeEntity.id,
    place: place,
    scene: scene,
    actors: actors,
    props: props,
    tint: lightTints[directives['light']],
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

/// Ventana animada con el fondo del lugar, los personajes y los objetos de una escena del cuento.
/// Al aparecer en pantalla los personajes llegan caminando; la cámara se mueve apenas.
class StoryStage extends StatefulWidget {
  const StoryStage({
    super.key,
    required this.setup,
    required this.clock,
    this.art,
    this.animate = true,
  });

  final StageSetup setup;
  final ValueListenable<double> clock;

  /// Para el clip de caminar; si falta, no hay entrada.
  final StageArt? art;

  /// Si es `false`, todo se queda quieto (pruebas, «reducir movimiento»).
  final bool animate;

  @override
  State<StoryStage> createState() => _StoryStageState();
}

class _StoryStageState extends State<StoryStage> {
  late List<ActorInstance> _actors = _build();

  List<ActorInstance> _build() {
    final setup = widget.setup;
    if (!widget.animate) return setup.actors;
    final walk = widget.art?.clip('walk');
    final center = setup.place.view.center.dx;
    final dist = setup.place.view.width * 0.3;
    final t0 = widget.clock.value;
    return [
      for (final a in setup.actors)
        a.entering(t0: t0, walk: walk, from: a.x < center ? -dist : dist),
    ];
  }

  @override
  void didUpdateWidget(StoryStage old) {
    super.didUpdateWidget(old);
    if (old.setup != widget.setup || old.animate != widget.animate) {
      _actors = _build();
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
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
                    actors: _actors,
                    props: setup.props,
                    tint: setup.tint,
                    camera: widget.animate,
                    clock: widget.clock,
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
