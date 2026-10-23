#!/usr/bin/env python3
"""Fondos del pack «Aldea de las Nubes» (docs/27), como DATOS (`caldero-scene`), en 4:3 (640×480).

Mismas reglas que `scenes_story.py` y `mar_scenes.py`. Los lugares con cielo de la Tierra (la aldea, el observatorio, la
plataforma, el planeta jardín y el dormitorio) sacan sus horas con `looks.relook`; los del espacio (la luna, el planeta
de cristal, los anillos, la cabina, la estación, el taller y el espacio abierto) no tienen hora: siempre es noche de
estrellas, que es lo bonito.

Uso:
    python3 tools/art/cosmos_scenes.py
"""
import json
import math
from pathlib import Path

import anim
import looks
import medieval_kit as kit
import scene_castle as castle
from mar_scenes import planks
from medieval_kit import S, ell, mix, n, node, poly, rrect, star
from scenes_story import ambient, fireflies, full, hills, layer, lcg, lin, scene

OUT = Path(__file__).resolve().parent.parent.parent / "art" / "cosmos"
W, H = 640, 480
FLOOR = 410
SCALE = 0.6
DARK = kit.DARK


# ------------------------------------------------------------------ piezas
def sky_day(sun_x=480, sun_y=110):
    grads = {"sky": lin([[0, "#5a8ae0", 1], [0.6, "#a8d0f8", 1], [1, "#f8e8ff", 1]]),
             "sun": {"type": "radial", "stops": [[0, "#fff6c8", 0.85], [1, "#fff6c8", 0]]}}
    return grads, layer("sky", [full("@sky"), S(ell(sun_x, sun_y, 120, 120), "@sun", None, 0), S(ell(sun_x, sun_y, 30, 30), "#fff3c4", None, 0)])


def space_sky(seed, nebula=("#7a4ab0", "#e05a8b")):
    """Cielo de espacio: degradado oscuro, una nebulosa de colores y estrellas que titilan."""
    grads = {"space": lin([[0, "#0c0a2a", 1], [0.6, "#1c1650", 1], [1, "#2a1a5a", 1]]),
             "neb1": {"type": "radial", "stops": [[0, nebula[0], 0.55], [1, nebula[0], 0]]},
             "neb2": {"type": "radial", "stops": [[0, nebula[1], 0.4], [1, nebula[1], 0]]}}
    r = lcg(seed)
    stars = []
    for i in range(40):
        x, y = round(next(r) * W, 1), round(next(r) * 330, 1)
        rad = 1.2 + next(r) * 1.4
        nd = node(f"st{i}", (x, y), shapes=[S(ell(x, y, rad, rad), "#fff6d8", None, 0)])
        nd["anim"] = [ambient("opacity", [0.3, 1.0, 0.3], 2.4 + next(r) * 2, next(r) * 3)]
        stars.append(nd)
    big = [S(star(x, y, 6, 2.4, 4), "#fff6c8", None, 0, 0.9) for x, y in ((90, 70), (520, 50), (360, 150))]
    return grads, layer("sky", [full("@space"), S(ell(170, 140, 200, 120), "@neb1", None, 0), S(ell(470, 210, 180, 110), "@neb2", None, 0)] + big, stars)


def cloud(x, y, k, col="#ffffff"):
    return [S(ell(x, y, 60 * k, 24 * k), col, None, 0, 0.95), S(ell(x - 40 * k, y + 6 * k, 38 * k, 20 * k), col, None, 0, 0.95),
            S(ell(x + 40 * k, y + 6 * k, 42 * k, 20 * k), col, None, 0, 0.95)]


def round_house(x, base, k, wall, roof):
    w, h = 70 * k, 56 * k
    return [S(rrect(x - w / 2, base - h, w, h, 18 * k), wall, mix(wall, DARK, 0.5), 2.5),
            S(f"M{n(x - w / 2 - 6)},{n(base - h + 10 * k)} C{n(x - w / 2)},{n(base - h - 40 * k)} {n(x + w / 2)},{n(base - h - 40 * k)} {n(x + w / 2 + 6)},{n(base - h + 10 * k)} Z",
              roof, mix(roof, DARK, 0.5), 2.5),
            S(ell(x, base - h * 0.55, 10 * k, 10 * k), "#ffd27a", "#5a3a14", 2), S(rrect(x - 9 * k, base - 22 * k, 18 * k, 22 * k, 8 * k), "#6a4a8a", None)]


def rocket(x, base, k=1.0):
    def p(v):
        return v * k
    return [S(f"M{n(x)},{n(base - p(230))} C{n(x + p(40))},{n(base - p(190))} {n(x + p(46))},{n(base - p(100))} {n(x + p(38))},{n(base - p(40))} "
              f"L{n(x - p(38))},{n(base - p(40))} C{n(x - p(46))},{n(base - p(100))} {n(x - p(40))},{n(base - p(190))} {n(x)},{n(base - p(230))} Z",
              "#f0f2f8", "#5a6a8a", 3),
            S(f"M{n(x)},{n(base - p(230))} C{n(x + p(20))},{n(base - p(212))} {n(x + p(30))},{n(base - p(196))} {n(x + p(34))},{n(base - p(180))} "
              f"L{n(x - p(34))},{n(base - p(180))} C{n(x - p(30))},{n(base - p(196))} {n(x - p(20))},{n(base - p(212))} {n(x)},{n(base - p(230))} Z", "#e84a5f", None),
            S(ell(x, base - p(130), p(18), p(18)), "#7ad0ff", "#2a5a8a", 3),
            S(poly([(x - p(38), base - p(90)), (x - p(70), base - p(20)), (x - p(36), base - p(40))]), "#e84a5f", "#7a1a2a", 2.5),
            S(poly([(x + p(38), base - p(90)), (x + p(70), base - p(20)), (x + p(36), base - p(40))]), "#e84a5f", "#7a1a2a", 2.5),
            S(rrect(x - p(24), base - p(42), p(48), p(16), p(4)), "#8a98b0", "#3a4a5a", 2)]


def crater(x, y, rx, ry, col="#b8b8cc"):
    return [S(ell(x, y, rx, ry), mix(col, DARK, 0.25), mix(col, DARK, 0.5), 2), S(ell(x, y - ry * 0.15, rx * 0.8, ry * 0.6), mix(col, DARK, 0.12), None)]


def planet(x, y, r, col, ring=None):
    sh = [S(ell(x, y, r, r), col, mix(col, DARK, 0.5), 2.5), S(f"M{n(x)},{n(y - r)} A{n(r)},{n(r)} 0 0 1 {n(x)},{n(y + r)} A{n(r * 0.55)},{n(r)} 0 0 0 {n(x)},{n(y - r)} Z", DARK, None, 0, 0.18)]
    if ring:
        sh.insert(0, S(ell(x, y, r * 1.8, r * 0.4), None, ring, 4, 0.8))
    return sh


# ------------------------------------------------------------------ lugares con cielo
def aldea():
    grads, sky = sky_day(480, 100)
    far = layer("far", cloud(110, 200, 1.4, "#f4ecff") + cloud(530, 230, 1.2, "#f4ecff"))
    ground = cloud(120, FLOOR - 10, 2.4) + cloud(330, FLOOR - 20, 2.6) + cloud(540, FLOOR - 6, 2.3) + \
        [S(f"M0,{FLOOR - 30} C200,{FLOOR - 50} 440,{FLOOR - 26} {W},{FLOOR - 44} L{W},{H} L0,{H} Z", "#ffffff", None, 0)]
    houses = round_house(110, FLOOR - 50, 1.1, "#ffd8e8", "#7a4ab0") + round_house(250, FLOOR - 60, 0.9, "#d8f0ff", "#e05a8b") + \
        round_house(520, FLOOR - 52, 1.2, "#fff2c8", "#4a6ab0")
    obs = [S(rrect(372, FLOOR - 160, 70, 110, 6), "#e8e0ff", "#5a4a8a", 2.5), S(f"M366,{FLOOR - 158} C366,{FLOOR - 206} 448,{FLOOR - 206} 448,{FLOOR - 158} Z", "#9aa8c0", "#4a5a6a", 2.5),
           S(f"M400,{FLOOR - 196} L440,{FLOOR - 220}", None, "#4a5a6a", 6)]
    mid = layer("mid", ground + houses + obs)
    near = layer("near", cloud(60, H - 10, 1.6) + cloud(600, H - 6, 1.5), fireflies(6, 41, 200, 400, "#fff6c8"))
    return scene("aldea", "Aldea de las Nubes", grads, [sky, far, mid, near])


def observatorio():
    grads, sky = sky_day(130, 110)
    dome = [S(rrect(140, 150, 360, 220, 10), "#e8e0ff", "#5a4a8a", 3), S("M130,152 C130,30 510,30 510,152 Z", "#9aa8c0", "#4a5a6a", 3),
            S("M300,40 L340,40 L346,152 L294,152 Z", "#2a2a5a", None), S(rrect(260, 260, 120, 110, 50), "#6a4a8a", "#3a2a5a", 2.5)]
    scope = [S(poly([(250, 140), (460, 40), (472, 66), (262, 166)]), "#4a6ab0", "#1a2a4a", 3), S(ell(466, 52, 10, 16), "#9ad8ff", "#2a6a9a", 2)]
    floor = planks(FLOOR - 40, H, "#b8a8d8", "#6a5a8a")
    mid = layer("mid", dome + scope + floor)
    near = layer("near", [])
    return scene("observatorio", "Observatorio", grads, [sky, layer("far", cloud(560, 260, 1.2)), mid, near])


def plataforma():
    grads, sky = sky_day(130, 100)
    far = layer("far", cloud(140, 220, 1.4, "#f4ecff") + cloud(520, 200, 1.1, "#f4ecff"))
    tower = [S(rrect(470, 120, 16, 260, 3), "#9aa8c0", "#4a5a6a", 2)] + [S(f"M470,{y} L486,{y + 30}", None, "#4a5a6a", 2) for y in range(130, 360, 30)]
    pad = [S(f"M0,{FLOOR - 40} L{W},{FLOOR - 40} L{W},{H} L0,{H} Z", "#c8c8e0", None, 0)] + \
        [S(f"M{x},{FLOOR - 40} L{x - 30},{H}", None, "#a8a8c8", 2) for x in range(40, W, 80)] + \
        [S(ell(380, FLOOR - 34, 90, 12), "#f4c542", "#a8801a", 2, 0.7)]
    mid = layer("mid", tower + rocket(380, FLOOR - 36, 1.15) + pad)
    near = layer("near", cloud(70, H - 4, 1.5) + cloud(590, H, 1.4))
    return scene("plataforma", "Plataforma de los cohetes", grads, [sky, far, mid, near])


def planeta_jardin():
    grads, sky = sky_day(140, 110)
    grads["sky"] = lin([[0, "#7a5ae0", 1], [0.6, "#e8a8e0", 1], [1, "#fff0d8", 1]])
    far = layer("far", planet(500, 120, 40, "#ffd84a", "#ff9a6a") + [hills(250, 30, "#9ad87a", 121), hills(286, 22, "#6ac06a", 122)])
    flowers = []
    r = lcg(123)
    for i in range(14):
        x = 20 + next(r) * 600
        h = 60 + next(r) * 90
        col = ["#ff6a9a", "#ffd84a", "#7ad0ff", "#c88aff"][i % 4]
        nd = node(f"fl{i}", (x, FLOOR - 30), shapes=[S(f"M{n(x)},{FLOOR - 30} C{n(x - 8)},{n(FLOOR - 30 - h / 2)} {n(x + 8)},{n(FLOOR - 30 - h / 2)} {n(x)},{n(FLOOR - 30 - h)}", None, "#3a9a4a", 4),
                                                      S(ell(x, FLOOR - 30 - h, 16, 16), col, mix(col, DARK, 0.45), 2), S(ell(x, FLOOR - 30 - h, 6, 6), "#fff6c0", None)])
        nd["anim"] = [ambient("rotate", [-3, 3, -3], 3.4 + next(r), next(r) * 2)]
        flowers.append(nd)
    ground = S(f"M0,{FLOOR - 40} C200,{FLOOR - 60} 440,{FLOOR - 30} {W},{FLOOR - 50} L{W},{H} L0,{H} Z", "#7ad07a", "#2a7a3a", 3)
    mid = layer("mid", [ground], flowers)
    near = layer("near", [S(f"M0,{FLOOR + 40} C200,{FLOOR + 26} 420,{FLOOR + 50} {W},{FLOOR + 30} L{W},{H} L0,{H} Z", "#5ab05a", None, 0)], fireflies(8, 127, 200, 400))
    return scene("planeta_jardin", "Planeta jardín", grads, [sky, far, mid, near])


def dormitorio(time="noche"):
    night = time == "noche"
    wall = layer("sky", [full("#3a2a6a" if night else "#8a7ad8")] + [S(star(x, y, 5, 2.2), "#fff6c8", None, 0, 0.35) for x, y in ((80, 60), (200, 120), (560, 80), (610, 200), (40, 220))])
    win_sky = "#141040" if night else "#9fd6ff"
    win = [S(rrect(380, 70, 200, 160, 80), win_sky, "#e8e0ff", 6), S("M480,70 L480,230 M380,150 L580,150", None, "#e8e0ff", 4)]
    if night:
        win += [S(kit.crescent(430, 110, 16, 18, 0.45), "#fff3c4", None, 0)] + [S(ell(x, y, 1.8, 1.8), "#fff6d8", None) for x, y in ((520, 100), (550, 180), (420, 190), (500, 130))]
    else:
        win += cloud(520, 120, 0.5)
    bed = [S(rrect(60, FLOOR - 110, 240, 70, 16), "#4a6ab0", "#2a3a6a", 3), S(rrect(60, FLOOR - 130, 70, 50, 16), "#f0f2f8", "#5a6a8a", 2.5),
           S(rrect(110, FLOOR - 112, 190, 40, 14), "#ffd84a", "#a8801a", 2.5)] + [S(star(x, FLOOR - 92, 6, 2.6), "#ff8ab0", None) for x in (150, 200, 250)]
    lamp = [S(ell(330, FLOOR - 120, 60, 60), "#fff6c0", None, 0, 0.18 if night else 0), S(rrect(318, FLOOR - 112, 24, 72, 6), "#c88aff", "#5a3a8a", 2),
            S("M306,FLOOR L354,FLOOR".replace("FLOOR", str(FLOOR - 112)), None, "#5a3a8a", 3)]
    floor = planks(FLOOR - 40, H, "#6a5aa0" if night else "#a898e0", "#4a3a7a")
    mid = layer("mid", win + floor + bed + lamp + [S(ell(470, FLOOR + 20, 120, 22), "#ff8ab0", "#a04a6a", 2)])
    sid = "dormitorio" if night else f"dormitorio__{time}"
    return scene(sid, "Dormitorio" + ("" if night else f" ({time})"), {}, [wall, layer("far", []), mid, layer("near", [])])


# ------------------------------------------------------------------ espacio
def luna():
    grads, sky = space_sky(201)
    far = layer("far", planet(120, 110, 46, "#4a8ae0", None) + [S(ell(120 - 10, 100, 12, 8), "#7ad07a", None, 0, 0.8)])
    ground = S(f"M0,{FLOOR - 60} C160,{FLOOR - 90} 420,{FLOOR - 50} {W},{FLOOR - 80} L{W},{H} L0,{H} Z", "#c8c8dc", "#7a7a90", 3)
    mid = layer("mid", [ground] + crater(150, FLOOR - 20, 70, 16) + crater(470, FLOOR - 30, 50, 12) + crater(330, FLOOR + 30, 36, 9) +
                [S(rrect(530, FLOOR - 140, 4, 90, 1), "#c8c8dc", None), S(poly([(534, FLOOR - 140), (580, FLOOR - 126), (534, FLOOR - 112)]), "#e84a5f", None)])
    near = layer("near", crater(80, H - 20, 44, 10) + crater(600, H - 12, 40, 9))
    return scene("luna", "Luna", grads, [sky, far, mid, near])


def planeta_cristal():
    grads, sky = space_sky(211, ("#4ab0d8", "#c88aff"))
    far = layer("far", planet(530, 90, 30, "#ff9a6a", "#ffd84a"))
    ground = S(f"M0,{FLOOR - 50} C200,{FLOOR - 70} 440,{FLOOR - 40} {W},{FLOOR - 60} L{W},{H} L0,{H} Z", "#5a4a9a", "#2a1a5a", 3)
    crystals = []
    r = lcg(213)
    for i, (x, h) in enumerate(((60, 150), (110, 90), (230, 70), (440, 120), (520, 180), (590, 100), (330, 50))):
        col = ["#a8f0ff", "#c8a8ff", "#ff9ad8"][i % 3]
        nd = node(f"cr{i}", (x, FLOOR - 50), shapes=[S(poly([(x - h * 0.22, FLOOR - 50), (x - h * 0.12, FLOOR - 50 - h * 0.8), (x, FLOOR - 50 - h), (x + h * 0.14, FLOOR - 50 - h * 0.75), (x + h * 0.22, FLOOR - 50)]),
                                                         col, mix(col, DARK, 0.45), 2.5, 0.9),
                                                       S(poly([(x, FLOOR - 50 - h), (x + h * 0.14, FLOOR - 50 - h * 0.75), (x + h * 0.06, FLOOR - 50)]), "#ffffff", None, 0, 0.3)])
        nd["anim"] = [ambient("opacity", [0.7, 1.0, 0.7], 2.6 + next(r), next(r) * 2)]
        crystals.append(nd)
    mid = layer("mid", [ground], crystals)
    return scene("planeta_cristal", "Planeta de cristal", grads, [sky, far, mid, layer("near", [])])


def anillos():
    grads, sky = space_sky(221, ("#e05a8b", "#4ab0d8"))
    far = layer("far", planet(420, 200, 90, "#e8b06a", "#f4dca0"))
    rocks = []
    r = lcg(223)
    for i in range(10):
        x, y, k = 40 + next(r) * 560, 80 + next(r) * 260, 10 + next(r) * 22
        nd = node(f"as{i}", (x, y), shapes=[S(f"M{n(x - k)},{n(y)} C{n(x - k)},{n(y - k)} {n(x + k * 0.6)},{n(y - k * 1.1)} {n(x + k)},{n(y - k * 0.2)} C{n(x + k * 1.1)},{n(y + k)} {n(x - k * 0.5)},{n(y + k)} {n(x - k)},{n(y)} Z",
                                               "#9a8a7a", "#4a3a2a", 2)])
        nd["anim"] = [ambient("rotate", [0, 20, 0], 6 + next(r) * 4, next(r) * 3)]
        rocks.append(nd)
    big = S(f"M-20,{FLOOR - 40} C120,{FLOOR - 80} 300,{FLOOR - 70} 400,{FLOOR - 40} C480,{FLOOR - 20} 600,{FLOOR - 50} 680,{FLOOR - 30} L680,{H} L-20,{H} Z", "#8a7a6a", "#3a2a1a", 3)
    mid = layer("mid", [big] + crater(200, FLOOR + 10, 40, 10, "#9a8a7a"), rocks)
    return scene("anillos", "Anillo de asteroides", grads, [sky, far, mid, layer("near", [])])


def espacio():
    grads, sky = space_sky(231)
    far = layer("far", planet(110, 380, 70, "#4a8ae0") + planet(540, 120, 28, "#e8b06a", "#f4dca0"))
    trail = node("trail", (320, 300), shapes=[S("M60,80 C180,120 260,170 300,200", None, "#ffd84a", 10, 0.4), S("M60,80 C180,120 260,170 300,200", None, "#fff6c0", 4, 0.8), S(star(302, 202, 10, 4), "#fff6c0", None)])
    trail["anim"] = [ambient("opacity", [0.5, 1.0, 0.5], 1.2, 0)]
    mid = layer("mid", [], [trail])
    return scene("espacio", "Espacio", grads, [sky, far, mid, layer("near", [])])


def interior(sid, name, wall, floorcol, extra):
    grads = {"lamp": {"type": "radial", "stops": [[0, "#c8f0ff", 0.4], [1, "#c8f0ff", 0]]}}
    back = layer("sky", [full(wall)] + [S(rrect(0, y, W, 6, 0), mix(wall, DARK, 0.2), None) for y in (60, 200)])
    mid = layer("mid", extra + [S(f"M0,{FLOOR - 40} L{W},{FLOOR - 40} L{W},{H} L0,{H} Z", floorcol, None, 0)] +
                [S(f"M{x},{FLOOR - 40} L{x},{H}", None, mix(floorcol, DARK, 0.2), 2) for x in range(0, W, 80)])
    return scene(sid, name, grads, [back, layer("far", []), mid, layer("near", [])])


def porthole(x, y, r, seed):
    sh = [S(ell(x, y, r + 8, r + 8), "#9aa8c0", "#4a5a6a", 3), S(ell(x, y, r, r), "#141040", None)]
    rr = lcg(seed)
    sh += [S(ell(x - r * 0.6 + next(rr) * r * 1.2, y - r * 0.6 + next(rr) * r * 1.2, 1.6, 1.6), "#fff6d8", None) for _ in range(6)]
    return sh


def cabina():
    panel = [S(rrect(60, 240, 520, 90, 16), "#4a5a8a", "#2a3a5a", 3)]
    r = lcg(241)
    for i in range(16):
        x, y = 90 + (i % 8) * 62, 262 + (i // 8) * 36
        col = ["#ff6a6a", "#7aff9a", "#7ad0ff", "#ffd84a"][i % 4]
        nd = node(f"bt{i}", (x, y), shapes=[S(ell(x, y, 8, 8), col, None)])
        nd["anim"] = [ambient("opacity", [0.4, 1.0, 0.4], 1.2 + next(r) * 2, next(r) * 2)]
        panel.append(nd)
    window = [S(rrect(110, 40, 420, 180, 60), "#141040", "#9aa8c0", 8)] + [S(ell(140 + next(r) * 360, 60 + next(r) * 140, 1.8, 1.8), "#fff6d8", None) for _ in range(18)] + \
        planet(440, 120, 30, "#4a8ae0")
    sc = interior("cabina", "Cabina del cohete", "#d8dcf0", "#8a98b0", window)
    sc["layers"][2]["post"] = [p for p in panel if isinstance(p, dict) and "pivot" in p]
    sc["layers"][2]["shapes"] += [p for p in panel if "pivot" not in p]
    return sc


def estacion():
    extra = porthole(130, 130, 54, 251) + porthole(320, 120, 54, 252) + porthole(510, 130, 54, 253) + \
        [S(rrect(40, 230, 560, 40, 10), "#9aa8c0", "#4a5a6a", 2.5)] + [S(rrect(80 + i * 120, 236, 60, 28, 6), "#7ad0ff", None, 0, 0.6) for i in range(4)]
    return interior("estacion", "Estación espacial", "#e8ecf8", "#a8b0c8", extra)


def taller():
    extra = [S(rrect(60, 80, 220, 140, 8), "#8a5a3a", "#3a2a1a", 3)] + [S(rrect(80 + i * 46, 100, 10, 60, 3), "#9aa8c0", None) for i in range(4)] + \
        [S(rrect(360, 230, 220, 20, 4), "#8a5a3a", "#3a2a1a", 3), S(rrect(380, 250, 14, 120, 3), "#6a4a2a", None), S(rrect(546, 250, 14, 120, 3), "#6a4a2a", None),
         S(ell(450, 214, 30, 16), "#e84a5f", "#7a1a2a", 2), S(ell(510, 220, 12, 12), "#ffd84a", "#a8801a", 2)] + porthole(470, 100, 44, 261)
    return interior("taller", "Taller de Tornillo", "#c8b8e8", "#8a7aa8", extra)


# ------------------------------------------------------------------ tabla
PLACES = {p: {"scene": p, "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE}
          for p in ("aldea", "observatorio", "plataforma", "cabina", "luna", "planeta_cristal", "planeta_jardin", "anillos", "estacion",
                    "taller", "dormitorio", "espacio")}
BUILDERS = {"aldea": aldea, "observatorio": observatorio, "plataforma": plataforma, "cabina": cabina, "luna": luna,
            "planeta_cristal": planeta_cristal, "planeta_jardin": planeta_jardin, "anillos": anillos, "estacion": estacion,
            "taller": taller, "dormitorio": dormitorio, "espacio": espacio}
BASE_TIME = {"dormitorio": "noche", "observatorio": "noche"}
SKY_AT = {"aldea": (480, 100, 250), "observatorio": (130, 110, 150), "plataforma": (130, 100, 260), "planeta_jardin": (140, 110, 250)}


def pack_times():
    pack = json.loads((OUT.parent.parent / "content" / "packs" / "cosmos" / "pack.json").read_text(encoding="utf-8"))
    return {p["id"]: p.get("times") for p in pack["places"]}


def write_scene(data):
    (OUT / "scenes" / f"{data['id']}.json").write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def build_all():
    table = {}
    for place, times in pack_times().items():
        base_time = BASE_TIME.get(place, "dia" if times else None)
        base = BUILDERS[place]()
        if place == "observatorio":  # el observatorio vive de noche: el fondo base es la noche
            sx, sy, hz = SKY_AT[place]
            base = looks.relook(base, "noche", None, W, H, sx, sy, hz, moon_xy=(sx, sy))
            base["id"] = "observatorio"
        write_scene(base)
        table[place] = {base_time: base["id"]} if base_time else {}
        for time in times or []:
            if time == base_time:
                continue
            if place == "dormitorio":
                sc = dormitorio(time)
            else:
                sx, sy, hz = SKY_AT[place]
                sc = looks.relook(BUILDERS[place](), time, None, W, H, sx, sy, hz, moon_xy=(sx, sy))
            write_scene(sc)
            table[place][time] = sc["id"]
    return table


def preview(place, rigs, clips, t=0.4):
    sc = json.loads((OUT / "scenes" / f"{PLACES[place]['scene']}.json").read_text(encoding="utf-8"))
    space = place in ("luna", "anillos", "espacio", "estacion", "cabina")
    cast = [("lira", "float" if space else "idle", 0.2), ("aurora", "talk", 0.48), ("tornillo", "wave", 0.8)]
    sc = dict(sc, actors=[{"rig": r, "x": W * x, "y": FLOOR, "scale": SCALE, "clip": c, "phase": 0.0} for r, c, x in cast])
    return castle.scene_svg(sc, rigs, clips, t)


def main():
    (OUT / "scenes").mkdir(parents=True, exist_ok=True)
    (OUT / "preview").mkdir(parents=True, exist_ok=True)
    table = build_all()
    for p, m in table.items():
        PLACES[p]["looks"] = m
    index_path = OUT / "index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    index["scenes"] = sorted(f"cosmos/scenes/{f.name}" for f in (OUT / "scenes").glob("*.json"))
    index["places"] = PLACES
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    rigs = {f.stem: json.loads(f.read_text(encoding="utf-8")) for f in (OUT / "rigs").glob("*.json")}
    clips = anim.load_clips("humanoid")
    for p in PLACES:
        (OUT / "preview" / f"stage_{p}.svg").write_text(preview(p, rigs, clips), encoding="utf-8")
    total = sum(f.stat().st_size for f in (OUT / "scenes").glob("*.json"))
    print(f"{len(index['scenes'])} escenas, {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
