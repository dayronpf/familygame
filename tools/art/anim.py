"""Muestreo de animaciones (la misma lógica está portada a Dart en packages/caldero_rig).

* Clips por tipo de rig (`art/clips/<rig>.json`): pistas de claves [[t, valor], ...] por hueso.
  Los ángulos son ADITIVOS sobre la pose de reposo del personaje, así un mismo clip sirve a
  cualquier personaje del mismo rig.
* Animaciones ambientales de escena (aspas, luciérnagas): valores repartidos de forma uniforme.

Pistas: `hueso` (rotación en grados), `hueso.dx` / `hueso.dy` (desplazamiento),
`hueso.sx` / `hueso.sy` (escala, absoluta; 1 = normal).
"""
import json
import math
from pathlib import Path

ART = Path(__file__).resolve().parent.parent.parent / "art"


def load_clips(rig_type="humanoid"):
    return json.loads((ART / "clips" / f"{rig_type}.json").read_text(encoding="utf-8"))["clips"]


def ease(u, kind):
    return u if kind == "linear" else (1 - math.cos(math.pi * u)) / 2


def sample_keys(keys, t, dur, loop, kind="smooth"):
    t = t % dur if loop else max(0.0, min(t, dur))
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0) if t1 > t0 else 1.0
            return v0 + (v1 - v0) * ease(u, kind)
    return keys[-1][1]


def sample_pose(rig, clip, t):
    """Pose = reposo del personaje + pistas del clip en el instante t."""
    p = {"armL": 0.0, "armR": 0.0}
    p.update(rig.get("rest", {}))
    for track, keys in clip["tracks"].items():
        v = sample_keys(keys, t, clip["dur"], clip.get("loop", True), clip.get("ease", "smooth"))
        if track.endswith((".dx", ".dy", ".sx", ".sy")):
            p[track] = v
        else:
            p[track] = p.get(track, 0.0) + v
    if rig.get("itemUpright"):  # el arma sigue erguida aunque el brazo se mueva
        p["itemR"] = -p["armR"] + rig.get("itemTilt", 0)
    return p


def sample_ambient(a, t):
    """Animación ambiental de un nodo de escena: `values` repartidos de forma uniforme en `dur`."""
    vals, dur = a["values"], a["dur"]
    keys = [[dur * i / (len(vals) - 1), v] for i, v in enumerate(vals)]
    return sample_keys(keys, t + a.get("phase", 0.0), dur, True, a.get("ease", "smooth"))
