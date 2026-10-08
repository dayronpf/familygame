import 'svg_path.dart';

/// Un archivo de arte no tiene el formato esperado.
class ArtFormatException implements Exception {
  ArtFormatException(this.message);

  final String message;

  @override
  String toString() => 'ArtFormatException: $message';
}

Map<String, Object?> _map(Object? v, String where) => v is Map<String, Object?>
    ? v
    : throw ArtFormatException('$where: se esperaba un objeto');

List<Object?> _list(Object? v, String where) => v is List<Object?>
    ? v
    : throw ArtFormatException('$where: se esperaba una lista');

double _d(Object? v, String where) => v is num
    ? v.toDouble()
    : throw ArtFormatException('$where: se esperaba un número');

String _s(Object? v, String where) =>
    v is String ? v : throw ArtFormatException('$where: se esperaba un texto');

List<double> _pair(Object? v, String where) {
  final l = _list(v, where);
  if (l.length != 2) throw ArtFormatException('$where: se esperaban 2 números');
  return [_d(l[0], where), _d(l[1], where)];
}

/// Forma vectorial. `fill` y `stroke` son `$token` de paleta, `@degradado`, `#hex`, `auto` (stroke) o `null`.
class RigShape {
  RigShape({
    required this.d,
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.opacity,
  });

  factory RigShape.fromJson(Object? json) {
    final j = _map(json, 'forma');
    return RigShape(
      d: _s(j['d'], 'forma.d'),
      fill: j['fill'] as String?,
      stroke: j['stroke'] as String?,
      strokeWidth: j['sw'] == null ? 0 : _d(j['sw'], 'forma.sw'),
      opacity: j['op'] == null ? 1 : _d(j['op'], 'forma.op'),
    );
  }

  final String d;
  final String? fill;
  final String? stroke;
  final double strokeWidth;
  final double opacity;

  /// Ruta interpretada (se calcula una sola vez).
  late final List<PathCmd> commands = parseSvgPath(d);
}

/// Animación ambiental de un nodo (aspas, destellos): `values` repartidos de forma uniforme en `dur`.
class AmbientAnim {
  AmbientAnim({
    required this.prop,
    required this.values,
    required this.dur,
    required this.phase,
    required this.ease,
  });

  factory AmbientAnim.fromJson(Object? json) {
    final j = _map(json, 'anim');
    final values = [
      for (final v in _list(j['values'], 'anim.values')) _d(v, 'anim.values'),
    ];
    if (values.length < 2) {
      throw ArtFormatException('anim.values necesita al menos 2 valores');
    }
    final prop = _s(j['prop'], 'anim.prop');
    if (prop != 'opacity' && prop != 'rotate') {
      throw ArtFormatException('anim.prop desconocido: $prop');
    }
    return AmbientAnim(
      prop: prop,
      values: values,
      dur: _d(j['dur'], 'anim.dur'),
      phase: j['phase'] == null ? 0 : _d(j['phase'], 'anim.phase'),
      ease: (j['ease'] as String?) ?? 'smooth',
    );
  }

  final String prop;
  final List<double> values;
  final double dur, phase;
  final String ease;
}

/// Hueso o grupo: pivote, formas propias, hijos detrás (`pre`) y delante (`post`).
class RigNode {
  RigNode({
    required this.id,
    required this.pivotX,
    required this.pivotY,
    required this.pre,
    required this.shapes,
    required this.post,
    required this.restRotation,
    required this.anims,
  });

  factory RigNode.fromJson(Object? json) {
    final j = _map(json, 'nodo');
    final id = _s(j['id'], 'nodo.id');
    final pivot = _pair(j['pivot'], 'nodo "$id".pivot');
    return RigNode(
      id: id,
      pivotX: pivot[0],
      pivotY: pivot[1],
      pre: [
        for (final c in _list(j['pre'] ?? const <Object?>[], 'nodo "$id".pre'))
          RigNode.fromJson(c),
      ],
      shapes: [
        for (final s
            in _list(j['shapes'] ?? const <Object?>[], 'nodo "$id".shapes'))
          RigShape.fromJson(s),
      ],
      post: [
        for (final c
            in _list(j['post'] ?? const <Object?>[], 'nodo "$id".post'))
          RigNode.fromJson(c),
      ],
      restRotation: j['rot'] == null ? 0 : _d(j['rot'], 'nodo "$id".rot'),
      anims: [
        for (final a
            in _list(j['anim'] ?? const <Object?>[], 'nodo "$id".anim'))
          AmbientAnim.fromJson(a),
      ],
    );
  }

  final String id;
  final double pivotX, pivotY;
  final List<RigNode> pre, post;
  final List<RigShape> shapes;

  /// Rotación fija (grados) sobre el pivote, aparte de las animaciones.
  final double restRotation;
  final List<AmbientAnim> anims;
}

/// Personaje: esqueleto + paleta + datos de reposo.
class Rig {
  Rig({
    required this.id,
    required this.name,
    required this.type,
    required this.bodyScale,
    required this.rest,
    required this.itemUpright,
    required this.itemTilt,
    required this.palette,
    required this.root,
    required this.viewBox,
  });

  factory Rig.fromJson(Map<String, Object?> j) {
    if (j['format'] != 'caldero-rig' || j['version'] != 1) {
      throw ArtFormatException('no es un rig caldero-rig versión 1');
    }
    final palette = {
      for (final e in _map(j['palette'], 'palette').entries)
        e.key: _s(e.value, 'palette.${e.key}'),
    };
    final rest = {
      for (final e
          in _map(j['rest'] ?? const <String, Object?>{}, 'rest').entries)
        e.key: _d(e.value, 'rest.${e.key}'),
    };
    return Rig(
      id: _s(j['id'], 'id'),
      name: _s(j['name'], 'name'),
      type: _s(j['rig'], 'rig'),
      bodyScale: j['bodyScale'] == null ? 1 : _d(j['bodyScale'], 'bodyScale'),
      rest: rest,
      itemUpright: j['itemUpright'] == true,
      itemTilt: j['itemTilt'] == null ? 0 : _d(j['itemTilt'], 'itemTilt'),
      palette: palette,
      root: RigNode.fromJson(j['root']),
      viewBox: [
        for (final v in _list(j['viewBox'], 'viewBox')) _d(v, 'viewBox'),
      ],
    );
  }

  final String id, name;

  /// Tipo de esqueleto (`humanoid`); define qué clips le sirven.
  final String type;
  final double bodyScale;
  final Map<String, double> rest;
  final bool itemUpright;
  final double itemTilt;
  final Map<String, String> palette;
  final RigNode root;

  /// `[x, y, ancho, alto]` del área del personaje.
  final List<double> viewBox;
}

class GradientStop {
  const GradientStop(this.offset, this.color, this.opacity);
  final double offset;
  final String color;
  final double opacity;
}

/// Degradado de escena (coordenadas relativas a la caja de la forma, como `objectBoundingBox` de SVG).
class SceneGradient {
  SceneGradient({
    required this.linear,
    required this.from,
    required this.to,
    required this.stops,
  });

  factory SceneGradient.fromJson(Object? json) {
    final j = _map(json, 'degradado');
    final type = _s(j['type'], 'degradado.type');
    return SceneGradient(
      linear: type == 'linear',
      from: type == 'linear'
          ? _pair(j['from'], 'degradado.from')
          : const [0.5, 0.5],
      to: type == 'linear' ? _pair(j['to'], 'degradado.to') : const [1.0, 0.5],
      stops: [
        for (final s in _list(j['stops'], 'degradado.stops'))
          GradientStop(
            _d(_list(s, 'stop')[0], 'stop.offset'),
            _s(_list(s, 'stop')[1], 'stop.color'),
            _d(_list(s, 'stop')[2], 'stop.opacity'),
          ),
      ],
    );
  }

  final bool linear;
  final List<double> from, to;
  final List<GradientStop> stops;
}

/// Personaje colocado en una escena.
class Actor {
  Actor({
    required this.rig,
    required this.x,
    required this.y,
    required this.scale,
    required this.clip,
    required this.phase,
  });

  factory Actor.fromJson(Object? json) {
    final j = _map(json, 'actor');
    return Actor(
      rig: _s(j['rig'], 'actor.rig'),
      x: _d(j['x'], 'actor.x'),
      y: _d(j['y'], 'actor.y'),
      scale: _d(j['scale'], 'actor.scale'),
      clip: _s(j['clip'], 'actor.clip'),
      phase: j['phase'] == null ? 0 : _d(j['phase'], 'actor.phase'),
    );
  }

  final String rig, clip;
  final double x, y, scale, phase;
}

/// Escena: capas de fondo (de atrás hacia delante), degradados y personajes.
class Scene {
  Scene({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.gradients,
    required this.layers,
    required this.actors,
  });

  factory Scene.fromJson(Map<String, Object?> j) {
    if (j['format'] != 'caldero-scene' || j['version'] != 1) {
      throw ArtFormatException('no es una escena caldero-scene versión 1');
    }
    final size = _pair(j['size'], 'size');
    return Scene(
      id: _s(j['id'], 'id'),
      name: _s(j['name'], 'name'),
      width: size[0],
      height: size[1],
      gradients: {
        for (final e
            in _map(j['gradients'] ?? const <String, Object?>{}, 'gradients')
                .entries)
          e.key: SceneGradient.fromJson(e.value),
      },
      layers: [
        for (final l in _list(j['layers'], 'layers')) RigNode.fromJson(l),
      ],
      actors: [
        for (final a in _list(j['actors'] ?? const <Object?>[], 'actors'))
          Actor.fromJson(a),
      ],
    );
  }

  final String id, name;
  final double width, height;
  final Map<String, SceneGradient> gradients;
  final List<RigNode> layers;
  final List<Actor> actors;
}
