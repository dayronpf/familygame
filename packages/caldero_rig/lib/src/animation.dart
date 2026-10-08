import 'dart:math' as math;

import 'model.dart';

/// Pose = valor por pista: `hueso` (grados), `hueso.dx/.dy` (desplazamiento), `hueso.sx/.sy` (escala).
typedef Pose = Map<String, double>;

/// Clip: pistas de claves `[t, valor]` por hueso. Los ángulos se SUMAN al reposo del personaje.
class Clip {
  Clip({
    required this.dur,
    required this.loop,
    required this.ease,
    required this.tracks,
  });

  factory Clip.fromJson(Map<String, Object?> j) {
    final tracks = <String, List<List<double>>>{};
    final raw = j['tracks'];
    if (raw is! Map<String, Object?>) {
      throw ArtFormatException('clip.tracks: se esperaba un objeto');
    }
    for (final e in raw.entries) {
      final keys = e.value;
      if (keys is! List<Object?> || keys.length < 2) {
        throw ArtFormatException(
          'pista "${e.key}": necesita al menos 2 claves',
        );
      }
      tracks[e.key] = [
        for (final k in keys)
          if (k is List<Object?> && k.length == 2 && k[0] is num && k[1] is num)
            [(k[0]! as num).toDouble(), (k[1]! as num).toDouble()]
          else
            throw ArtFormatException('pista "${e.key}": clave inválida $k'),
      ];
    }
    return Clip(
      dur: (j['dur']! as num).toDouble(),
      loop: j['loop'] != false,
      ease: (j['ease'] as String?) ?? 'smooth',
      tracks: tracks,
    );
  }

  final double dur;
  final bool loop;
  final String ease;
  final Map<String, List<List<double>>> tracks;
}

/// Biblioteca de clips de un tipo de esqueleto (p. ej. `humanoid`).
class ClipLibrary {
  ClipLibrary({required this.rigType, required this.clips});

  factory ClipLibrary.fromJson(Map<String, Object?> j) {
    if (j['format'] != 'caldero-clips' || j['version'] != 1) {
      throw ArtFormatException('no es una biblioteca caldero-clips versión 1');
    }
    final raw = j['clips'];
    if (raw is! Map<String, Object?>) {
      throw ArtFormatException('clips: se esperaba un objeto');
    }
    return ClipLibrary(
      rigType: j['rig']! as String,
      clips: {
        for (final e in raw.entries)
          e.key: Clip.fromJson(e.value! as Map<String, Object?>),
      },
    );
  }

  final String rigType;
  final Map<String, Clip> clips;
}

double _ease(double u, String kind) =>
    kind == 'linear' ? u : (1 - math.cos(math.pi * u)) / 2;

/// Valor de una pista en el instante [t]. Misma lógica que `tools/art/anim.py`.
double sampleKeys(
  List<List<double>> keys,
  double t,
  double dur,
  bool loop,
  String ease,
) {
  final tt = loop ? t % dur : t.clamp(0.0, dur).toDouble();
  if (tt <= keys.first[0]) return keys.first[1];
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (tt <= b[0]) {
      final u = b[0] > a[0] ? (tt - a[0]) / (b[0] - a[0]) : 1.0;
      return a[1] + (b[1] - a[1]) * _ease(u, ease);
    }
  }
  return keys.last[1];
}

/// Pose del personaje: reposo + pistas del clip en [t].
Pose samplePose(Rig rig, Clip clip, double t) {
  final p = <String, double>{'armL': 0, 'armR': 0, ...rig.rest};
  for (final e in clip.tracks.entries) {
    final v = sampleKeys(e.value, t, clip.dur, clip.loop, clip.ease);
    final track = e.key;
    final absolute = track.endsWith('.dx') ||
        track.endsWith('.dy') ||
        track.endsWith('.sx') ||
        track.endsWith('.sy');
    p[track] = absolute ? v : (p[track] ?? 0) + v;
  }
  if (rig.itemUpright) {
    p['itemR'] = -p['armR']! + rig.itemTilt; // el arma sigue erguida
  }
  return p;
}

/// Valor de una animación ambiental en [t].
double sampleAmbient(AmbientAnim a, double t) {
  final n = a.values.length;
  final keys = [
    for (var i = 0; i < n; i++) [a.dur * i / (n - 1), a.values[i]],
  ];
  return sampleKeys(keys, t + a.phase, a.dur, true, a.ease);
}
