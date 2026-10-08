#!/usr/bin/env python3
"""Datos de referencia para probar que el muestreo de animación en Dart coincide con el de Python.
Escribe art/fixtures/animation_samples.json (poses por clip/personaje/instante y valores ambientales)."""
import json
from pathlib import Path

import anim
import medieval_kit as kit
import scene_castle

TIMES = [0.0, 0.13, 0.37, 0.71, 1.07, 2.9, 5.5]
RIGS = ["aldo", "zafiro", "bonifacio", "sombra"]


def walk(nd, out):
    if "anim" in nd:
        out.append(nd)
    for c in nd["pre"] + nd["post"]:
        walk(c, out)


def main():
    rigs, clips, scene = scene_castle.load_rigs(), anim.load_clips("humanoid"), scene_castle.build_scene()
    poses = []
    for rid in RIGS:
        for cname, clip in clips.items():
            for t in TIMES:
                p = anim.sample_pose(rigs[rid], clip, t)
                poses.append({"rig": rid, "clip": cname, "t": t, "pose": {k: round(v, 6) for k, v in sorted(p.items())}})
    animated = []
    for layer in scene["layers"]:
        walk(layer, animated)
    ambient = []
    for nd in animated[:12]:
        for a in nd["anim"]:
            for t in (0.0, 0.4, 1.3, 2.9, 7.7):
                ambient.append({"node": nd["id"], "prop": a["prop"], "t": t, "value": round(anim.sample_ambient(a, t), 6)})
    out = kit.OUT.parent / "fixtures" / "animation_samples.json"
    out.write_text(json.dumps({"poses": poses, "ambient": ambient}, separators=(",", ":")), encoding="utf-8")
    print(f"{len(poses)} poses y {len(ambient)} valores ambientales → {out.name} ({out.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
