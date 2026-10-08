#!/usr/bin/env python3
"""Escena «Castillo bajo la luna» como DATOS: capas de formas vectoriales, degradados, animaciones
ambientales (aspas, destellos) y una lista de personajes con su clip.

Escribe:
    art/medieval/scenes/castle_night.json     ← lo que lee la app
    art/medieval/preview/scene_castle.svg     ← vista previa en t = 0
Con --frames DIR --fps 10 --secs 3 escribe un SVG por fotograma (para generar el GIF).
"""
import argparse
import json
from pathlib import Path

import anim
import medieval_kit as kit
from medieval_kit import S, ell, n, node, poly, rrect

W, H = 600, 800
SCENE_ID = "castle_night"


def lcg(seed):
    s = seed
    while True:
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        yield s / 0xFFFFFFFF


def ambient(prop, values, dur=3.0, phase=0.0, ease="smooth"):
    return {"prop": prop, "values": values, "dur": dur, "phase": round(phase, 3), "ease": ease}


def layer(id_, shapes=(), post=()):
    return node(id_, (0, 0), shapes=shapes, post=post)


# ------------------------------------------------------------------ capas
def layer_sky():
    r = lcg(7)
    shapes = [S(rrect(0, 0, W, H, 0), "@sky", None, 0)]
    twinkle = []
    for i in range(70):
        x, y, rad = round(next(r) * W, 1), round(next(r) * 430, 1), round(0.8 + next(r) * 1.6, 1)
        ph = next(r) * 3
        if i % 3 == 0:
            nd = node(f"star{i}", (x, y), shapes=[S(ell(x, y, rad, rad), "#fff6d8", None, 0)])
            nd["anim"] = [ambient("opacity", [0.25, 0.95, 0.25], 3.0, ph)]
            twinkle.append(nd)
        else:
            shapes.append(S(ell(x, y, rad, rad), "#fff6d8", None, 0, 0.8))
    shapes += [S(ell(470, 150, 95, 95), "@moonhalo", None, 0), S(ell(470, 150, 46, 46), "#fff3c4", None, 0)]
    for cx, cy, r_ in [(455, 138, 9), (488, 162, 7), (466, 172, 5)]:
        shapes.append(S(ell(cx, cy, r_, r_), "#f1dc9a", None, 0, 0.7))
    return layer("sky", shapes, twinkle)


def layer_far():
    return layer("far", [
        S("M0,500 C90,455 170,490 270,468 C380,445 470,490 600,455 L600,800 L0,800 Z", "#2a2260", None, 0),
        S("M0,540 C120,500 200,540 320,512 C430,488 520,530 600,505 L600,800 L0,800 Z", "#332a78", None, 0)])


def tower(x, w, top, base, roof_h, roof="#c0455f", wins=1):
    stone, side, ink = "#b4abd8", "#9188c0", "#4a3f86"
    o = [S(rrect(x, top, w, base - top, 3), stone, ink, 2.5),
         S(rrect(x + w * 0.62, top + 2, w * 0.36, base - top - 4, 3), "#000000", None, 0, 0.12),
         S(rrect(x - 4, top - 8, w + 8, 12, 3), side, ink, 2.5)]
    for i in range(int((w + 8) // 12)):
        o.append(S(rrect(x - 4 + i * 12 + 1, top - 15, 8, 9, 1.5), side, ink, 2))
    o.append(S(poly([(x - 8, top - 8), (x + w + 8, top - 8), (x + w / 2, top - 8 - roof_h)]), roof, "#5a2036", 2.5))
    o.append(S(poly([(x + w / 2, top - 8 - roof_h), (x + w + 8, top - 8), (x + w / 2 + 3, top - 8)]), "#000000", None, 0, 0.18))
    o.append(S(rrect(x + w / 2 - 1, top - 8 - roof_h - 22, 2.4, 24, 1), "#6a5a8a", None, 0))
    o.append(S(poly([(x + w / 2 + 1, top - 8 - roof_h - 22), (x + w / 2 + 17, top - 8 - roof_h - 16),
                     (x + w / 2 + 1, top - 8 - roof_h - 10)]), "#f4c542", "#5a4410", 1.5))
    for i in range(wins):
        wy = top + 24 + i * 38
        o.append(S(f"M{n(x + w / 2 - 6)},{n(wy + 18)} L{n(x + w / 2 - 6)},{n(wy + 6)} A6,6 0 0 1 {n(x + w / 2 + 6)},{n(wy + 6)} "
                   f"L{n(x + w / 2 + 6)},{n(wy + 18)} Z", "#ffd27a", "#5a3a14", 2))
    return o


def layer_mid():
    sh = [S("M180,600 C230,540 300,530 420,538 C520,545 570,570 640,600 L640,800 L180,800 Z", "#3d3288", "#251c5a", 2.5),
          S(rrect(318, 500, 200, 60, 3), "#a69dcc", "#4a3f86", 2.5)]
    sh += tower(300, 46, 440, 565, 44, wins=2)
    sh += tower(494, 46, 440, 565, 44, wins=2)
    sh += [S(rrect(356, 380, 126, 185, 4), "#b4abd8", "#4a3f86", 2.5), S(rrect(432, 382, 48, 181, 3), "#000000", None, 0, 0.12)]
    sh += tower(380, 78, 330, 400, 62, roof="#7a4fd0")
    sh += [S("M390,565 L390,520 A29,29 0 0 1 448,520 L448,565 Z", "#ffcf70", "#4a2f2a", 3),
           S("M404,565 L404,526 A15,15 0 0 1 434,526 L434,565 Z", "#5a3a2a", "#2a1a14", 2)]
    for wx, wy in [(392, 440), (428, 440)]:
        sh.append(S(f"M{wx},{wy + 22} L{wx},{wy + 8} A9,9 0 0 1 {wx + 18},{wy + 8} L{wx + 18},{wy + 22} Z", "#ffd27a", "#5a3a14", 2))
    # molino
    sh += [S("M70,590 C90,570 120,572 150,590 L150,800 L70,800 Z", "#3d3288", "#251c5a", 2.5),
           S(poly([(98, 585), (142, 585), (134, 490), (106, 490)]), "#8f84c4", "#4a3f86", 2.5),
           S(poly([(104, 490), (136, 490), (120, 458)]), "#7a4fd0", "#3a2670", 2.5),
           S(rrect(114, 540, 12, 45, 5), "#5a3a2a", "#2a1a14", 2), S(ell(120, 520, 5, 7), "#ffd27a", "#5a3a14", 1.5)]
    # aspas: cuatro iguales ⇒ girar 90° es un bucle sin costuras
    hub = (120, 482)
    sails = []
    for rot in (0, 90, 180, 270):
        s_ = node(f"sail{rot}", hub, shapes=[
            S(rrect(116, 420, 8, 62, 2), "#8a5a2b", "#3a2412", 2),
            S(rrect(104, 422, 14, 34, 2), "#efe4c8", "#6a5a3a", 2)])
        s_["rot"] = rot
        sails.append(s_)
    wheel = node("wheel", hub, post=sails)
    wheel["anim"] = [ambient("rotate", [0, 90], 3.0, 0.0, "linear")]
    hub_node = node("hub", hub, shapes=[S(ell(120, 482, 6, 6), "#8a5a2b", "#3a2412", 2)])
    return layer("mid", sh, [wheel, hub_node])


def tree(tx, ty, k):
    def sc(v):
        return v * k
    return [S(rrect(tx - sc(7), ty - sc(50), sc(14), sc(56), sc(4)), "#6a4426", "#2a180c", 2.5),
            S(ell(tx, ty - sc(92), sc(38), sc(36)), "#2f8f66", "#16463a", 3),
            S(ell(tx - sc(22), ty - sc(66), sc(28), sc(24)), "#2a7d5b", "#16463a", 3),
            S(ell(tx + sc(24), ty - sc(68), sc(28), sc(24)), "#2a7d5b", "#16463a", 3),
            S(ell(tx + sc(14), ty - sc(96), sc(14), sc(26)), "#000000", None, 0, 0.12)]


def layer_near():
    sh = [S("M0,650 C150,620 300,660 600,625 L600,800 L0,800 Z", "#2c6b5e", "#1b3f3a", 3),
          S("M0,700 C160,676 330,712 600,684 L600,800 L0,800 Z", "#245a50", None, 0)]
    sh += tree(46, 650, 1.0) + tree(560, 640, 0.9)
    r = lcg(21)
    flies = []
    for i in range(16):
        x, y = round(next(r) * W, 1), round(560 + next(r) * 220, 1)
        ph = next(r) * 3
        nd = node(f"fly{i}", (x, y), shapes=[S(ell(x, y, 9, 9), "#fff59d", None, 0, 0.25),
                                              S(ell(x, y, 2.6, 2.6), "#fffde0", None, 0)])
        nd["anim"] = [ambient("opacity", [0.2, 1.0, 0.2], 3.0, ph)]
        flies.append(nd)
    return layer("near", sh, flies)


ACTORS = [
    {"rig": "mara", "x": 345, "y": 706, "scale": 0.62, "clip": "idle", "phase": 0.9},
    {"rig": "aldo", "x": 235, "y": 748, "scale": 0.8, "clip": "idle", "phase": 0.0},
    {"rig": "zafiro", "x": 515, "y": 752, "scale": 0.76, "clip": "idle", "phase": 1.8},
]


def build_scene():
    return {
        "format": "caldero-scene", "version": 1, "id": SCENE_ID, "name": "Castillo bajo la luna", "size": [W, H],
        "gradients": {
            "sky": {"type": "linear", "from": [0, 0], "to": [0, 1],
                    "stops": [[0, "#0c0922", 1], [0.55, "#2b2063", 1], [1, "#6b4aa0", 1]]},
            "moonhalo": {"type": "radial", "stops": [[0, "#fff3c4", 0.5], [1, "#fff3c4", 0]]},
        },
        "layers": [layer_sky(), layer_far(), layer_mid(), layer_near()],
        "actors": ACTORS,
    }


# ----------------------------------------------------------- vista previa SVG
def node_svg(nd, t):
    ang = nd.get("rot", 0)
    opacity = None
    for a in nd.get("anim", []):
        v = anim.sample_ambient(a, t)
        if a["prop"] == "rotate":
            ang += v
        elif a["prop"] == "opacity":
            opacity = v
    px, py = nd["pivot"]
    attrs = ""
    if ang:
        attrs += f' transform="rotate({n(ang)} {n(px)} {n(py)})"'
    if opacity is not None:
        attrs += f' opacity="{opacity:.3f}"'
    out = [f'<g id="{nd["id"]}"{attrs}>']
    out += [node_svg(c, t) for c in nd["pre"]]
    out += [kit.svg_shape({"palette": {}}, s) for s in nd["shapes"]]
    out += [node_svg(c, t) for c in nd["post"]]
    out.append("</g>")
    return "".join(out)


def gradient_defs(grads):
    o = ["<defs>"]
    for gid, g in grads.items():
        stops = "".join(f'<stop offset="{s[0]}" stop-color="{s[1]}" stop-opacity="{s[2]}"/>' for s in g["stops"])
        if g["type"] == "linear":
            (x1, y1), (x2, y2) = g["from"], g["to"]
            o.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>')
        else:
            o.append(f'<radialGradient id="{gid}">{stops}</radialGradient>')
    o.append("</defs>")
    return "".join(o)


def scene_svg(scene, rigs, clips, t):
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
             gradient_defs(scene["gradients"])]
    parts += [node_svg(layer_, t) for layer_ in scene["layers"]]
    parts.append('<g id="actors">')
    for a in scene["actors"]:
        rig = rigs[a["rig"]]
        pose = anim.sample_pose(rig, clips[a["clip"]], t + a.get("phase", 0.0))
        k = a["scale"]
        shadow_rx = 58 * k * rig["bodyScale"] + 8
        parts.append(f'<ellipse cx="{a["x"]}" cy="{a["y"] + 4}" rx="{shadow_rx:.0f}" ry="8" fill="#000" opacity="0.38"/>')
        parts.append(f'<g transform="translate({a["x"]} {a["y"]}) scale({k})">{kit.svg_character(rig, pose)}</g>')
    parts.append("</g></svg>")
    return "".join(parts)


def load_rigs():
    return {c["id"]: json.loads((kit.OUT / "rigs" / f'{c["id"]}.json').read_text(encoding="utf-8")) for c in kit.load_cast()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames")
    ap.add_argument("--fps", type=int, default=10)
    ap.add_argument("--secs", type=float, default=3.0)
    args = ap.parse_args()

    scene = build_scene()
    (kit.OUT / "scenes").mkdir(parents=True, exist_ok=True)
    (kit.OUT / "preview").mkdir(parents=True, exist_ok=True)
    path = kit.OUT / "scenes" / f"{SCENE_ID}.json"
    path.write_text(json.dumps(scene, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    rigs, clips = load_rigs(), anim.load_clips("humanoid")
    (kit.OUT / "preview" / "scene_castle.svg").write_text(scene_svg(scene, rigs, clips, 0.0), encoding="utf-8")
    print(f"{path.name}: {path.stat().st_size / 1024:.0f} KB")
    if args.frames:
        d = Path(args.frames)
        d.mkdir(parents=True, exist_ok=True)
        total = round(args.fps * args.secs)
        for i in range(total):
            (d / f"f{i:03d}.svg").write_text(scene_svg(scene, rigs, clips, i / args.fps), encoding="utf-8")
        print(f"{total} fotogramas en {d}")


if __name__ == "__main__":
    main()
