#!/usr/bin/env python3
"""Fondos de los lugares del pack medieval, como DATOS (`caldero-scene`), en formato 4:3 (640×480)
pensado para el escenario que acompaña a cada cuento.

Escribe, por cada lugar:
    art/medieval/scenes/<id>.json          ← lo que lee la app
    art/medieval/preview/stage_<id>.svg    ← vista previa con los 3 personajes en sus posiciones
Y actualiza `art/medieval/index.json` (lista de escenas y bloque `places` con el suelo y la escala).

Las posiciones de los personajes siguen la misma regla que la app (ver `stage_slots`).
"""
import json
from pathlib import Path

import anim
import looks
import medieval_kit as kit
import scene_castle as castle
from medieval_kit import S, ell, n, node, poly, rrect

W, H = 640, 480
FLOOR = 410  # línea de los pies de los personajes
SCALE = 0.6


def lcg(seed):
    s = seed
    while True:
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        yield s / 0xFFFFFFFF


def ambient(prop, values, dur=3.0, phase=0.0, ease="smooth"):
    return {"prop": prop, "values": values, "dur": dur, "phase": round(phase, 3), "ease": ease}


def layer(id_, shapes=(), post=()):
    return node(id_, (0, 0), shapes=shapes, post=post)


def full(fill):
    return S(rrect(0, 0, W, H, 0), fill, None, 0)


def hills(y0, amp, color, seed, stroke=None, bottom=H):
    """Colina ondulada que llena hasta abajo."""
    r = lcg(seed)
    pts, x = [], 0
    d = f"M0,{n(y0 + (next(r) - .5) * amp)}"
    while x < W:
        x2 = min(W, x + 110 + next(r) * 60)
        d += f" Q{n((x + x2) / 2)},{n(y0 + (next(r) - .5) * amp * 2)} {n(x2)},{n(y0 + (next(r) - .5) * amp)}"
        x = x2
    return S(d + f" L{W},{bottom} L0,{bottom} Z", color, stroke, 2.5 if stroke else 0)


def pine(x, base, h, body="#1f6b57", dark="#134a3c"):
    w = h * 0.42
    o = [S(rrect(x - 4, base - h * 0.18, 8, h * 0.2, 2), "#5a3a22", "#2a180c", 2)]
    for i, k in enumerate((0.0, 0.26, 0.5)):
        top = base - h + k * h * 0.5
        bot = base - h * 0.16 - (2 - i) * h * 0.2
        ww = w * (0.55 + i * 0.25)
        o.append(S(poly([(x - ww, bot), (x + ww, bot), (x, top)]), body, dark, 2.5))
        o.append(S(poly([(x, top), (x + ww, bot), (x + 3, bot)]), "#000000", None, 0, 0.14))
    return o


def oak(x, base, k, leaf="#3a9a62", leaf2="#2f8456"):
    def sc(v):
        return v * k
    return [S(rrect(x - sc(8), base - sc(60), sc(16), sc(64), sc(5)), "#6a4426", "#2a180c", 2.5),
            S(ell(x, base - sc(98), sc(44), sc(40)), leaf, "#16463a", 3),
            S(ell(x - sc(28), base - sc(72), sc(30), sc(26)), leaf2, "#16463a", 3),
            S(ell(x + sc(28), base - sc(74), sc(30), sc(26)), leaf2, "#16463a", 3),
            S(ell(x + sc(14), base - sc(104), sc(16), sc(28)), "#000000", None, 0, 0.12)]


def fireflies(count, seed, y_min, y_max, color="#fff59d", glow=9):
    r = lcg(seed)
    out = []
    for i in range(count):
        x, y = round(next(r) * W, 1), round(y_min + next(r) * (y_max - y_min), 1)
        nd = node(f"fly{i}", (x, y), shapes=[S(ell(x, y, glow, glow), color, None, 0, 0.25),
                                              S(ell(x, y, 2.6, 2.6), "#fffde0", None, 0)])
        nd["anim"] = [ambient("opacity", [0.2, 1.0, 0.2], 3.0, next(r) * 3)]
        out.append(nd)
    return out


def twinkles(count, seed, y_max, color="#fff6d8"):
    r = lcg(seed)
    out = []
    for i in range(count):
        x, y = round(next(r) * W, 1), round(next(r) * y_max, 1)
        nd = node(f"st{i}", (x, y), shapes=[S(ell(x, y, 1.6, 1.6), color, None, 0)])
        nd["anim"] = [ambient("opacity", [0.25, 0.95, 0.25], 3.0, next(r) * 3)]
        out.append(nd)
    return out


def scene(id_, name, gradients, layers):
    return {"format": "caldero-scene", "version": 1, "id": id_, "name": name, "size": [W, H],
            "gradients": gradients, "layers": layers, "actors": []}


def lin(stops):
    return {"type": "linear", "from": [0, 0], "to": [0, 1], "stops": stops}


# ------------------------------------------------------------------ bosque
def bosque():
    grads = {"sky": lin([[0, "#2c6e86", 1], [0.6, "#8fd0a0", 1], [1, "#f7e6a6", 1]]),
             "sun": {"type": "radial", "stops": [[0, "#fff6c8", 0.9], [1, "#fff6c8", 0]]},
             "ground": lin([[0, "#3f9a62", 1], [1, "#1f6b57", 1]])}
    sky = layer("sky", [full("@sky"), S(ell(470, 120, 150, 150), "@sun", None, 0),
                        S(ell(470, 120, 34, 34), "#fff3c4", None, 0)])
    far = layer("far", [hills(250, 30, "#5bb083", 3), hills(290, 24, "#3f9a62", 5)]
                + sum([pine(x, 330, 110 + (x % 40), "#2c8a62", "#17533f") for x in (40, 150, 330, 540, 610)], []))
    mid = layer("mid", sum([pine(x, 372, 150 + (x % 30)) for x in (90, 250, 410, 575)], [])
                + sum([oak(x, 380, 0.9) for x in (20, 340)], []))
    near = layer("near", [S(f"M0,{FLOOR - 28} C150,{FLOOR - 52} 340,{FLOOR - 8} {W},{FLOOR - 36} L{W},{H} L0,{H} Z",
                           "@ground", "#154a3c", 3),
                          S(f"M0,{FLOOR + 30} C200,{FLOOR + 6} 420,{FLOOR + 44} {W},{FLOOR + 14} L{W},{H} L0,{H} Z",
                            "#1a5c48", None, 0)]
                + sum([oak(x, FLOOR - 10, 0.75) for x in (610,)], [])
                + [S(ell(x, FLOOR + y, 6, 4), c, None, 0) for x, y, c in
                   [(120, 38, "#f4c542"), (300, 52, "#ff8fa3"), (470, 40, "#ffffff"), (560, 58, "#f4c542"), (60, 60, "#ff8fa3")]],
                fireflies(14, 11, 220, 430))
    return scene("bosque", "Bosque de los robles", grads, [sky, far, mid, near])


# ------------------------------------------------------------------- cueva
def cueva():
    grads = {"wall": lin([[0, "#17122e", 1], [1, "#2e2552", 1]]),
             "glow": {"type": "radial", "stops": [[0, "#9fe8ff", 0.55], [1, "#9fe8ff", 0]]},
             "floor": lin([[0, "#4a3d7a", 1], [1, "#2b2352", 1]])}

    def crystal(x, base, h, color, light):
        return [S(poly([(x - h * .22, base), (x - h * .1, base - h), (x + h * .08, base - h * .85), (x + h * .24, base)]),
                  color, "#1c1740", 2.5),
                S(poly([(x - h * .1, base - h), (x + h * .08, base - h * .85), (x - h * .02, base - h * .2)]),
                  light, None, 0, 0.55)]

    back = layer("sky", [full("@wall")])
    rocks = layer("far", [
        S(f"M0,0 L{W},0 L{W},120 Q{W * .85},170 {W * .7},110 Q{W * .55},60 {W * .4},130 Q{W * .22},180 {W * .1},110 L0,150 Z",
          "#0d0a20", "#07050f", 2.5)]
        + [S(poly([(x, 0), (x + 26, 0), (x + 13, h)]), "#1a1438", "#07050f", 2) for x, h in
           [(70, 90), (170, 140), (280, 70), (410, 120), (520, 95), (600, 60)]]
        + [S(ell(330, 250, 160, 120), "@glow", None, 0)])
    mid = layer("mid", [hills(300, 20, "#2c2452", 9, "#120e2c")]
                + crystal(80, 330, 120, "#5ac8e8", "#d8f6ff") + crystal(122, 335, 78, "#7aa0ff", "#e0e8ff")
                + crystal(560, 330, 130, "#b07aff", "#efe0ff") + crystal(520, 336, 80, "#5ac8e8", "#d8f6ff"))
    gl = []
    r = lcg(4)
    for i, (x, y) in enumerate([(80, 250), (122, 290), (560, 245), (520, 292), (330, 200)]):
        nd = node(f"gl{i}", (x, y), shapes=[S(ell(x, y, 22, 22), "#9fe8ff", None, 0, 0.18)])
        nd["anim"] = [ambient("opacity", [0.2, 0.9, 0.2], 3.0, next(r) * 3)]
        gl.append(nd)
    near = layer("near", [S(f"M0,{FLOOR - 24} C160,{FLOOR - 44} 380,{FLOOR - 6} {W},{FLOOR - 30} L{W},{H} L0,{H} Z",
                           "@floor", "#120e2c", 3),
                          S(ell(560, FLOOR + 30, 46, 14), "#5ac8e8", None, 0, 0.15),
                          S(poly([(30, FLOOR + 34), (60, FLOOR + 6), (96, FLOOR + 34)]), "#3a3068", "#120e2c", 2.5)],
                gl + fireflies(8, 13, 200, 400, "#c8f0ff", 7))
    return scene("cueva", "Cueva de los cristales", grads, [back, rocks, mid, near])


# --------------------------------------------------------------------- río
def rio():
    grads = {"sky": lin([[0, "#3f7fd0", 1], [0.7, "#9fd6ff", 1], [1, "#e8f6ff", 1]]),
             "water": lin([[0, "#3aa6d8", 1], [1, "#1e6aa8", 1]]),
             "grass": lin([[0, "#5cc070", 1], [1, "#2f8a54", 1]]),
             "sun": {"type": "radial", "stops": [[0, "#fff6c8", 0.85], [1, "#fff6c8", 0]]}}
    r = lcg(31)
    clouds = []
    for i, (x, y, k) in enumerate([(110, 70, 1.0), (380, 110, 0.8), (540, 55, 0.9)]):
        sh = [S(ell(x, y, 54 * k, 20 * k), "#ffffff", None, 0, 0.95), S(ell(x - 28 * k, y + 4, 32 * k, 15 * k), "#ffffff", None, 0, 0.95),
              S(ell(x + 30 * k, y + 5, 34 * k, 15 * k), "#f4fbff", None, 0, 0.95)]
        nd = node(f"cloud{i}", (x, y), shapes=sh)
        nd["anim"] = [ambient("opacity", [0.75, 1.0, 0.75], 6.0, next(r) * 6)]
        clouds.append(nd)
    sky = layer("sky", [full("@sky"), S(ell(100, 140, 120, 120), "@sun", None, 0), S(ell(100, 140, 30, 30), "#fff3c4", None, 0)], clouds)
    far = layer("far", [hills(240, 30, "#7ac98a", 8), hills(285, 22, "#4fae6e", 6),
                        S(poly([(430, 300), (470, 250), (500, 300)]), "#8a8fb0", "#4a4f70", 2.5),
                        S(poly([(430, 300), (470, 250), (454, 300)]), "#000000", None, 0, 0.12),
                        S(poly([(466, 262), (470, 250), (478, 262), (470, 266)]), "#ffffff", None, 0, 0.9)])
    wave = []
    for i, (x, y) in enumerate([(120, 372), (300, 392), (470, 366), (560, 396)]):
        nd = node(f"wv{i}", (x, y), shapes=[S(f"M{n(x)},{n(y)} Q{n(x + 16)},{n(y - 8)} {n(x + 32)},{n(y)} Q{n(x + 48)},{n(y + 8)} {n(x + 64)},{n(y)}",
                        None, "#e8f6ff", 3, 0.8)])
        nd["anim"] = [ambient("opacity", [0.25, 0.9, 0.25], 2.4, i * 0.7)]
        wave.append(nd)
    water = layer("mid", [S(f"M0,330 C140,318 300,342 {W},322 L{W},{FLOOR - 22} C400,{FLOOR - 4} 200,{FLOOR - 36} 0,{FLOOR - 12} Z",
                           "@water", "#124a7a", 3),
                          S(f"M0,350 C160,340 320,362 {W},346 L{W},352 C320,368 160,346 0,356 Z", "#9fe0ff", None, 0, 0.35)], wave)
    # puente de madera
    bridge = [S(rrect(206, 330, 238, 14, 4), "#8a7a66", "#3a2e24", 2.5)]
    for x in range(214, 440, 11):  # unos cuarenta tablones, viejos y gastados
        bridge.append(S(rrect(x, 331, 1.6, 12, 0.5), "#3a2e24", None, 0, 0.7))
    bridge += [S(rrect(210, 298, 6, 36, 2), "#6a5a48", "#2a2018", 2), S(rrect(434, 298, 6, 36, 2), "#6a5a48", "#2a2018", 2),
               S(rrect(210, 304, 230, 5, 2), "#6a5a48", "#2a2018", 2), S("M300,309 L300,330 M372,309 L372,330", None, "#6a5a48", 3)]
    near = layer("near", [S(f"M0,{FLOOR - 12} C160,{FLOOR - 36} 380,{FLOOR - 4} {W},{FLOOR - 30} L{W},{H} L0,{H} Z",
                           "@grass", "#1e5e3a", 3),
                          S(f"M0,{FLOOR + 34} C200,{FLOOR + 14} 420,{FLOOR + 48} {W},{FLOOR + 20} L{W},{H} L0,{H} Z", "#277a48", None, 0)]
                + bridge + oak(70, FLOOR - 6, 0.85)
                + [S(ell(x, FLOOR + y, 6, 4), c, None, 0) for x, y, c in
                   [(180, 44, "#ff8fa3"), (330, 60, "#f4c542"), (520, 46, "#ffffff"), (600, 64, "#ff8fa3")]])
    return scene("rio", "Río de plata", grads, [sky, far, water, near])


# ------------------------------------------------------------------- aldea
POZO_X, POZO_Y = 262, 396
FLOWERS = [(540, 40, "#ff8fa3"), (590, 60, "#f4c542"), (20, 62, "#ffffff"), (500, 66, "#ffffff")]
# Primavera: charcos y muchas flores más
_r = lcg(9)
SPRING = [S(ell(150, FLOOR + 46, 34, 7), "#9fd0f0", "#5a90c0", 1.5, 0.85), S(ell(455, FLOOR + 52, 40, 8), "#9fd0f0", "#5a90c0", 1.5, 0.85)] \
    + [S(ell(30 + next(_r) * 580, FLOOR + 22 + next(_r) * 52, 5.5, 3.8), c, None, 0)
       for c in ("#ff8fa3", "#f4c542", "#ffffff", "#c58ae8") * 4]


def snow_cap(apex, left, right, k=0.5):
    """Capa de nieve sobre un tejado triangular: del vértice hacia las dos esquinas, con borde ondulado."""
    lx, ly = apex[0] + (left[0] - apex[0]) * k, apex[1] + (left[1] - apex[1]) * k
    rx, ry = apex[0] + (right[0] - apex[0]) * k, apex[1] + (right[1] - apex[1]) * k
    d = (f"M{n(apex[0])},{n(apex[1] - 1)} L{n(rx + 3)},{n(ry)} Q{n((rx + apex[0]) / 2 + 3)},{n(ry + 7)} {n(apex[0] + 4)},{n(ry + 2)} "
         f"Q{n(apex[0] - 6)},{n(ly + 8)} {n(lx - 3)},{n(ly)} Z")
    return [S(d, "#f6f9fd", "#9fb0c8", 2)]


def house(x, base, w, h, wall, roof, snow=False):
    o = [S(rrect(x, base - h, w, h, 3), wall, "#4a2c1a", 2.5),
         S(rrect(x + w * 0.62, base - h + 2, w * 0.36, h - 4, 3), "#000000", None, 0, 0.12),
         S(poly([(x - 8, base - h + 2), (x + w + 8, base - h + 2), (x + w / 2, base - h - h * 0.55)]), roof, "#4a1a2a", 2.5),
         S(poly([(x + w / 2, base - h - h * 0.55), (x + w + 8, base - h + 2), (x + w / 2 + 3, base - h + 2)]), "#000000", None, 0, 0.18),
         S(rrect(x + w * 0.4, base - h * 0.55, w * 0.2, h * 0.55, 3), "#5a3a2a", "#2a1a14", 2),
         S(rrect(x + w * 0.12, base - h * 0.7, w * 0.2, h * 0.24, 2), "#ffd27a", "#5a3a14", 2)]
    if snow:
        o += snow_cap((x + w / 2, base - h - h * 0.55), (x - 8, base - h + 2), (x + w + 8, base - h + 2), 0.55)
        o.append(S(rrect(x - 6, base - 5, w + 12, 7, 3), "#f6f9fd", "#9fb0c8", 1.5))
    return o


def pozo(cx, base, snow=False):
    """Pozo de piedra con tejadillo, cuerda y cubo."""
    o = [S(rrect(cx - 31, base - 74, 6, 50, 2), "#8a5a2b", "#3a2412", 2), S(rrect(cx + 25, base - 74, 6, 50, 2), "#8a5a2b", "#3a2412", 2),
         S(rrect(cx - 31, base - 38, 62, 38, 7), "#b9b2a2", "#5a5040", 2.5),
         S(rrect(cx + 8, base - 36, 21, 34, 5), "#000000", None, 0, 0.12)]
    for yy, off in ((base - 24, 0), (base - 12, 14)):
        o.append(S(f"M{n(cx - 31)},{n(yy)} L{n(cx + 31)},{n(yy)}", None, "#6a6050", 1.5))
        for xx in (cx - 14 + off, cx + 6 - off * 0.5):
            o.append(S(f"M{n(xx)},{n(yy)} L{n(xx)},{n(yy + 12 if yy < base - 20 else yy + 12)}", None, "#6a6050", 1.5))
    o += [S(ell(cx, base - 38, 31, 9), "#8a8272", "#5a5040", 2.5), S(ell(cx, base - 38, 24, 6), "#141a2a", None, 0),
          S(rrect(cx - 1.2, base - 66, 2.4, 26, 1), "#6a4a22", None, 0),
          S(rrect(cx - 7, base - 46, 14, 11, 3), "#8a5a2b", "#3a2412", 2),
          S(poly([(cx - 40, base - 70), (cx + 40, base - 70), (cx, base - 100)]), "#a8453f", "#4a1a2a", 2.5),
          S(poly([(cx, base - 100), (cx + 40, base - 70), (cx + 3, base - 70)]), "#000000", None, 0, 0.18)]
    if snow:
        o += snow_cap((cx, base - 100), (cx - 40, base - 70), (cx + 40, base - 70), 0.6)
        o.append(S(ell(cx, base - 39, 27, 6), "#f6f9fd", None, 0, 0.95))
    return o


def aldea(season=None):
    snow = season == "invierno"
    grads = {"sky": lin([[0, "#3b2a7a", 1], [0.45, "#d96a8a", 1], [1, "#ffcf7a", 1]]),
             "sun": {"type": "radial", "stops": [[0, "#fff0b0", 0.95], [1, "#fff0b0", 0]]},
             "grass": lin([[0, "#7bb85a", 1], [1, "#3f8a48", 1]]),
             "path": lin([[0, "#d9b27a", 1], [1, "#b4864f", 1]])}
    sky = layer("sky", [full("@sky"), S(ell(150, 300, 190, 190), "@sun", None, 0), S(ell(150, 300, 42, 42), "#fff6c8", None, 0)],
                twinkles(20, 5, 120, "#fff0d0"))
    far = layer("far", [hills(280, 26, "#8a5aa8", 4), hills(318, 20, "#6a4a96", 2)])
    # molino
    hub = (520, 250)
    sails = []
    for rot in (0, 90, 180, 270):
        s_ = node(f"sail{rot}", hub, shapes=[S(rrect(516, 196, 8, 54, 2), "#8a5a2b", "#3a2412", 2),
                                             S(rrect(504, 198, 14, 30, 2), "#efe4c8", "#6a5a3a", 2)])
        s_["rot"] = rot
        sails.append(s_)
    wheel = node("wheel", hub, post=sails)
    wheel["anim"] = [ambient("rotate", [0, 90], 4.0, 0.0, "linear")]
    mill = [S(poly([(494, 340), (546, 340), (538, 258), (502, 258)]), "#d8c8a8", "#5a4a30", 2.5),
            S(poly([(502, 258), (538, 258), (520, 228)]), "#a8453f", "#4a1a1a", 2.5),
            S(rrect(512, 300, 16, 40, 6), "#5a3a2a", "#2a1a14", 2)]
    mill_snow = snow_cap((520, 228), (502, 258), (538, 258), 0.6) if snow else []
    mid = layer("mid", house(60, 350, 90, 70, "#e8d2a8", "#b04a52", snow) + house(190, 346, 76, 60, "#dcc294", "#8a4a96", snow)
                + house(330, 350, 96, 76, "#e8d2a8", "#c05a3a", snow) + mill + mill_snow
                + [S(rrect(158, 300, 5, 46, 2), "#5a3a22", None, 0), S(poly([(163, 304), (190, 312), (163, 320)]), "#f4c542", "#5a4410", 1.5)],
                [wheel, node("hub", hub, shapes=[S(ell(520, 250, 6, 6), "#8a5a2b", "#3a2412", 2)])])
    smoke = []
    for i in range(3):
        nd = node(f"smk{i}", (100 + i * 4, 270), shapes=[S(ell(100 + i * 4, 284 - i * 12, 9 + i * 3, 8 + i * 3), "#ffffff", None, 0, 0.5)])
        nd["anim"] = [ambient("opacity", [0.0, 0.55, 0.0], 3.0, i * 1.0)]
        smoke.append(nd)
    near = layer("near", [S(f"M0,{FLOOR - 40} C160,{FLOOR - 60} 360,{FLOOR - 20} {W},{FLOOR - 48} L{W},{H} L0,{H} Z",
                           "@grass", "#2c6a38", 3),
                          S(f"M120,{H} C200,{FLOOR + 30} 300,{FLOOR - 10} 380,{FLOOR - 40} L430,{FLOOR - 38} "
                            f"C380,{FLOOR - 4} 360,{FLOOR + 30} 470,{H} Z", "@path", "#7a5a30", 2.5)]
                + pozo(POZO_X, POZO_Y, snow)
                + [S(rrect(x, FLOOR - 10, 4, 36, 1), "#8a5a2b", "#3a2412", 2) for x in (30, 52, 74)]
                + [S(rrect(26, FLOOR - 4, 56, 5, 1), "#8a5a2b", "#3a2412", 2)]
                + ([S(rrect(26, FLOOR - 8, 56, 5, 2), "#f6f9fd", None, 0)] if snow else [])
                + ([] if snow else [S(ell(x, FLOOR + y, 6, 4), c, None, 0) for x, y, c in FLOWERS])
                + (SPRING if season == "primavera" else []), smoke)
    return scene("aldea", "Aldea de los molinos", grads, [sky, far, mid, near])


# -------------------------------------------------------------------- casa
def casa():
    """Cocina de una casa de la aldea, de noche: pared de madera, ventana con nieve, horno encendido."""
    grads = {"wall": lin([[0, "#5a3524", 1], [1, "#8a5a3a", 1]]),
             "floor": lin([[0, "#7a4c2e", 1], [1, "#4a2c1a", 1]]),
             "night": lin([[0, "#1d2350", 1], [1, "#3a4a8a", 1]]),
             "glow": {"type": "radial", "stops": [[0, "#ffb45a", 0.55], [1, "#ffb45a", 0]]}}
    wall = layer("wall", [full("@wall")] + [S(rrect(x, 0, 3, FLOOR - 20, 0), "#000000", None, 0, 0.12) for x in range(64, W, 64)])
    # ventana con nieve
    snow = []
    r = lcg(11)
    for i in range(18):
        x, y = 78 + next(r) * 104, 96 + next(r) * 118
        nd = node(f"flake{i}", (x, y), shapes=[S(ell(x, y, 2.2, 2.2), "#ffffff", None, 0)])
        nd["anim"] = [ambient("opacity", [0.15, 1.0, 0.15], 2.4, next(r) * 2.4)]
        snow.append(nd)
    window = layer("window", [S(rrect(60, 80, 140, 150, 6), "#3a2412", "#1a0f08", 3),
                              S(rrect(70, 90, 120, 130, 3), "@night", None, 0),
                              S(rrect(127, 90, 6, 130, 0), "#3a2412", None, 0), S(rrect(70, 151, 120, 6, 0), "#3a2412", None, 0),
                              S(rrect(54, 228, 152, 12, 4), "#5a3a22", "#2a180c", 2)], snow)
    # estantería con tarros
    jars = []
    for i, c in enumerate(["#e8b45a", "#c8553d", "#7ab55a", "#e8b45a", "#9a6ab0"]):
        x = 250 + i * 30
        jars += [S(rrect(x, 128, 22, 28, 4), c, "#3a2412", 2), S(rrect(x + 3, 122, 16, 8, 2), "#d9c8a0", "#3a2412", 1.5)]
    shelf = layer("shelf", [S(rrect(236, 156, 180, 8, 2), "#5a3a22", "#2a180c", 2)] + jars
                  + [S("M300,40 L300,70", None, "#2a180c", 2), S(ell(300, 84, 18, 14), "#8a8a96", "#3a3a46", 2)])
    # horno de ladrillo con fuego
    fire = node("fire", (520, 360), shapes=[S("M490,396 C484,372 504,366 508,338 C516,360 528,360 534,336 C540,362 556,366 550,396 Z", "#ff8a2a", None, 0),
                                              S("M504,396 C500,380 512,376 516,360 C522,376 534,378 538,396 Z", "#ffd34a", None, 0)])
    fire["anim"] = [ambient("opacity", [0.7, 1.0, 0.8, 1.0], 1.6, 0.0)]
    glow = node("ovenglow", (520, 340), shapes=[S(ell(520, 340, 230, 190), "@glow", None, 0)])
    glow["anim"] = [ambient("opacity", [0.7, 1.0, 0.75], 2.4, 0.4)]
    brick = [S(rrect(430, 220, 180, 190, 8), "#a8553f", "#4a1a14", 3),
             S(rrect(450, 240, 140, 160, 6), "#8a4030", None, 0, 0.5)]
    for yy in range(250, 400, 24):
        brick.append(S(f"M450,{yy} L590,{yy}", None, "#4a1a14", 1.5))
    brick += [S("M474,396 L474,350 C474,318 566,318 566,350 L566,396 Z", "#1a0f10", "#2a1a14", 2.5)]
    oven = layer("oven", [S(ell(520, 340, 260, 200), "@glow", None, 0, 0.0)] + brick, [glow, fire])
    floor_ = layer("floor", [S(rrect(0, FLOOR - 24, W, H - FLOOR + 24, 0), "@floor", "#2a180c", 3)]
                   + [S(rrect(0, y, W, 2, 0), "#000000", None, 0, 0.18) for y in range(FLOOR + 6, H, 22)]
                   + [S(ell(300, FLOOR + 30, 150, 26), "#a8453f", "#5a2418", 3), S(ell(300, FLOOR + 30, 118, 17), "#d9b27a", None, 0, 0.5)])
    return scene("casa", "Cocina de la aldea", grads, [wall, window, shelf, oven, floor_])


# ------------------------------------------------------------------ cuarto
def cuarto(time="noche", season=None):
    """Cuarto de dormir: ventana (con luna y estrellas de noche, con sol o nieve de día), cama con colcha,
    mesita con vela, alfombra. De día la vela está apagada y la luz entra por la ventana."""
    night = time == "noche"
    wall = ("#2a2552", "#4a3a72") if night else ("#caa57a", "#e2c595")
    floor = ("#6a4a38", "#3e2a20") if night else ("#a8764e", "#7a5030")
    grads = {"wall": lin([[0, wall[0], 1], [1, wall[1], 1]]),
             "floor": lin([[0, floor[0], 1], [1, floor[1], 1]]),
             "sky": {"type": "linear", "from": [0, 0], "to": [0, 1], "stops": looks.sky_stops(time, season)},
             "moon": {"type": "radial", "stops": [[0, "#fff6c8", 0.9], [1, "#fff6c8", 0]]},
             "sun": {"type": "radial", "stops": [[0, "#fff0b0", 0.9], [1, "#fff0b0", 0]]},
             "candle": {"type": "radial", "stops": [[0, "#ffd27a", 0.6], [1, "#ffd27a", 0]]},
             "beam": {"type": "linear", "from": [0, 0], "to": [0, 1], "stops": [[0, "#fff6c8", 0.35], [1, "#fff6c8", 0]]}}
    wall_l = layer("wall", [full("@wall")] + [S(rrect(x, 0, 3, FLOOR - 20, 0), "#000000", None, 0, 0.1) for x in range(80, W, 80)])
    sky_things, deco = [], []
    r = lcg(21)
    if night and season == "invierno":
        # nevando de noche: copos y ninguna estrella
        for i in range(18):
            x, y = 262 + next(r) * 116, 66 + next(r) * 150
            nd = node(f"wfl{i}", (x, y), shapes=[S(ell(x, y, 2.4, 2.4), "#ffffff", None, 0)])
            nd["anim"] = [ambient("opacity", [0.1, 1.0, 0.1], 2.4, next(r) * 2.4)]
            sky_things.append(nd)
        deco = [S(ell(300, 100, 30, 12), "#6a7aa0", None, 0, 0.8), S(ell(360, 130, 26, 10), "#6a7aa0", None, 0, 0.8)]
    elif night:
        for i in range(10):
            x, y = 262 + next(r) * 116, 66 + next(r) * 150
            nd = node(f"wst{i}", (x, y), shapes=[S(ell(x, y, 1.8, 1.8), "#fff6d8", None, 0)])
            nd["anim"] = [ambient("opacity", [0.2, 1.0, 0.2], 2.8, next(r) * 2.8)]
            sky_things.append(nd)
        deco = [S(ell(330, 118, 52, 52), "@moon", None, 0), S(ell(330, 118, 22, 22), "#fff6c8", None, 0),
                S(ell(340, 112, 18, 18), "#2a3a7a", None, 0)]
    elif season == "invierno":
        for i in range(16):
            x, y = 262 + next(r) * 116, 66 + next(r) * 150
            nd = node(f"wfl{i}", (x, y), shapes=[S(ell(x, y, 2.4, 2.4), "#ffffff", None, 0)])
            nd["anim"] = [ambient("opacity", [0.1, 1.0, 0.1], 2.4, next(r) * 2.4)]
            sky_things.append(nd)
        deco = [S(ell(300, 100, 30, 12), "#e4ebf3", None, 0, 0.9), S(ell(360, 128, 26, 10), "#e4ebf3", None, 0, 0.9)]
    else:
        deco = [S(ell(330, 110, 70, 70), "@sun", None, 0), S(ell(330, 110, 24, 24), "#fff3b0", None, 0),
                S(ell(292, 168, 28, 10), "#ffffff", None, 0, 0.9), S(ell(366, 186, 24, 9), "#ffffff", None, 0, 0.9)]
    sill_fill = "#f6f9fd" if season == "invierno" and not night else "#4a2c1a"
    window = layer("window", [S(rrect(244, 46, 152, 188, 8), "#2a1a10", "#120a06", 3), S(rrect(254, 56, 132, 168, 4), "@sky", None, 0)]
                   + deco +
                   [S(rrect(317, 56, 6, 168, 0), "#2a1a10", None, 0), S(rrect(254, 136, 132, 6, 0), "#2a1a10", None, 0),
                    S(rrect(236, 232, 168, 12, 4), sill_fill, "#2a180c", 2)], sky_things)
    curtains = layer("curtains", [S("M236,40 L262,40 Q270,120 256,236 L236,236 Z", "#a8453f", "#5a1a14", 2.5),
                                  S("M404,40 L378,40 Q370,120 384,236 L404,236 Z", "#a8453f", "#5a1a14", 2.5),
                                  S("M246,44 Q250,130 244,230", None, "#d96a5a", 2, 0.7), S("M394,44 Q390,130 396,230", None, "#d96a5a", 2, 0.7),
                                  S(rrect(228, 34, 184, 8, 3), "#5a3a22", "#2a180c", 2)])
    layers = [wall_l, window, curtains]
    if not night:
        layers.append(layer("beam", [S(poly([(262, 60), (378, 60), (470, FLOOR), (170, FLOOR)]), "@beam", None, 0)]))
    bed = layer("bed", [S(ell(122, 392, 112, 9), "#000000", None, 0, 0.35),
                        S(rrect(24, 270, 196, 120, 6), "#6a4a38", "#2a180c", 3), S(rrect(34, 330, 176, 8, 2), "#000000", None, 0, 0.18),
                        S(rrect(24, 250, 20, 142, 4), "#5a3a28", "#2a180c", 3), S(rrect(204, 296, 16, 96, 4), "#5a3a28", "#2a180c", 3),
                        S(rrect(36, 236, 176, 48, 10), "#e8dcc4", "#8a7a5a", 2.5),
                        S(rrect(40, 238, 60, 34, 12), "#fffaf0", "#8a7a5a", 2.5),
                        S(rrect(36, 262, 176, 32, 6), "#a8453f", "#5a1a14", 2.5)]
                 + [S(rrect(36 + i * 44, 262, 4, 32, 0), "#d96a5a", None, 0, 0.6) for i in range(1, 4)])
    stand_shapes = [S(rrect(500, 310, 80, 100, 4), "#5a3a28", "#2a180c", 3), S(rrect(506, 330, 68, 4, 0), "#2a180c", None, 0, 0.5),
                    S(rrect(530, 282, 16, 28, 3), "#f2e7c8", "#8a7a5a", 2)]
    post = []
    if night:
        stand_shapes.append(S(ell(538, 272, 5, 9), "#ffb43a", None, 0))
        glow = node("candleglow", (540, 300), shapes=[S(ell(540, 300, 120, 100), "@candle", None, 0)])
        glow["anim"] = [ambient("opacity", [0.7, 1.0, 0.8, 1.0], 1.8, 0.3)]
        post = [glow]
    stand = layer("stand", stand_shapes, post)
    floor_ = layer("floor", [S(rrect(0, FLOOR - 24, W, H - FLOOR + 24, 0), "@floor", "#2a180c", 3)]
                   + [S(rrect(0, y, W, 2, 0), "#000000", None, 0, 0.18) for y in range(FLOOR + 6, H, 22)]
                   + [S(ell(330, FLOOR + 34, 140, 24), "#4a6aa8", "#1a2a5a", 3), S(ell(330, FLOOR + 34, 108, 15), "#7a9ad0", None, 0, 0.5)])
    name = "Cuarto de noche" if night else "Cuarto de día"
    return scene("cuarto", name, grads, layers + [bed, stand, floor_])


# --------------------------------------------------------------- campanario
def campanario(time="noche"):
    """Interior de la torre: muros de piedra, un arco abierto al cielo (a la hora que sea), vigas con un
    gancho y la cuerda que cuelga de él, y la escalera que baja a la izquierda."""
    sky_stops = looks.sky_stops(time, None)
    grads = {"sky": {"type": "linear", "from": [0, 0], "to": [0, 1], "stops": sky_stops},
             "sun": {"type": "radial", "stops": [[0, "#fff0b0", 0.95], [1, "#fff0b0", 0]]},
             "moon": {"type": "radial", "stops": [[0, "#fff3c4", 0.55], [1, "#fff3c4", 0]]},
             "stone": lin([[0, "#8f88b0", 1], [1, "#6a6490", 1]]),
             "floor": lin([[0, "#6a6490", 1], [1, "#443f66", 1]]),
             "torch": {"type": "radial", "stops": [[0, "#ffb45a", 0.6], [1, "#ffb45a", 0]]}}
    sky_shapes = [S(f"M0,0 L{W},0 L{W},{H} L0,{H} Z", "@sky", None, 0)]
    r = lcg(5)
    post = []
    if time == "noche":
        sky_shapes += [S(ell(470, 150, 80, 80), "@moon", None, 0), S(looks._crescent(470, 150, 34, 29, 13), "#fff3c4", None, 0)]
        for i in range(14):
            x, y = 400 + next(r) * 150, 110 + next(r) * 120
            nd = node(f"st{i}", (x, y), shapes=[S(ell(x, y, 1.7, 1.7), "#fff6d8", None, 0)])
            nd["anim"] = [ambient("opacity", [0.25, 0.95, 0.25], 3.0, next(r) * 3)]
            post.append(nd)
    else:
        sy = 170 if time == "dia" else 262
        sky_shapes += [S(ell(470, sy, 120, 120), "@sun", None, 0), S(ell(470, sy, 30, 30), "#fff3b0" if time == "dia" else "#fff0b0", None, 0)]
    sky_shapes += [hills(262, 14, looks.tone("#5bb083", time, None), 3, None, 330), hills(284, 10, looks.tone("#3f9a62", time, None), 5, None, 330)]
    sky = layer("sky", sky_shapes, post)

    stone = "@stone"
    wall_shapes = [S("M0,0 L380,0 L380,480 L0,480 Z", stone, None, 0), S("M560,0 L640,0 L640,480 L560,480 Z", stone, None, 0),
                   S("M380,0 L560,0 L560,190 A90,90 0 0 0 380,190 Z", stone, None, 0), S("M380,300 L560,300 L560,480 L380,480 Z", stone, None, 0)]
    for row, y in enumerate(range(20, 480, 34)):
        off = 0 if row % 2 == 0 else 24
        segs = [(0, 380), (560, 640)] + ([(380, 560)] if (y < 96 or y > 300) else [])
        for x0, x1 in segs:
            wall_shapes.append(S(f"M{x0},{y} L{x1},{y}", None, "#4a4570", 1.6, 0.6))
            for x in range(x0 + off, x1, 48):
                wall_shapes.append(S(f"M{x},{y} L{x},{y + 34}", None, "#4a4570", 1.6, 0.6))
    wall_shapes.append(S("M376,306 L376,190 A94,94 0 0 1 564,190 L564,306", None, "#3a3560", 9))
    wall_shapes.append(S(rrect(366, 296, 208, 14, 3), "#5a5480", "#2a2548", 2.5))
    wall = layer("wall", wall_shapes)
    # escalera que baja a la izquierda
    steps = [S("M0,330 L120,330 L120,480 L0,480 Z", "#14101e", None, 0)]
    for i in range(6):
        steps.append(S(f"M0,{338 + i * 24} L{110 - i * 4},{338 + i * 24} L{110 - i * 4},{348 + i * 24} L0,{348 + i * 24} Z", "#3a3560", "#201c38", 1.5, 1.0 - i * 0.12))
    stair = layer("stair", steps)
    beam = [S(rrect(0, 0, W, 38, 0), "#6a4426", "#2a180c", 3), S(rrect(0, 28, W, 6, 0), "#000000", None, 0, 0.2)]
    for x in (120, 300, 480):
        beam.append(S(f"M{x},38 L{x - 22},64 L{x + 22},64 Z", "#5a3a22", "#2a180c", 2))
    # gancho de hierro y la cuerda que cuelga
    beam += [S("M240,38 L240,64 C240,84 262,84 262,66", None, "#3d3a4a", 6), S(rrect(232, 36, 16, 8, 3), "#3d3a4a", "#1a1824", 2),
             S("M262,70 C262,150 252,200 256,262", None, "#3a2412", 6), S("M262,70 C262,150 252,200 256,262", None, "#c9a06a", 3.4),
             S(ell(256, 266, 7, 9), "#c9a06a", "#3a2412", 2)]
    # antorcha en la pared (encendida solo si no hay luz de día)
    torch_shapes = [S(rrect(150, 150, 8, 40, 2), "#3d3a4a", "#1a1824", 2), S("M136,150 L172,150 L166,162 L142,162 Z", "#3d3a4a", "#1a1824", 2)]
    torch_post = []
    if time != "dia":
        flame = node("flame", (154, 140), shapes=[S("M144,150 C140,132 152,126 154,108 C160,126 168,130 164,150 Z", "#ff8a2a", None, 0),
                                                S("M149,150 C147,138 154,134 155,122 C159,134 163,138 160,150 Z", "#ffd34a", None, 0)])
        flame["anim"] = [ambient("opacity", [0.75, 1.0, 0.82, 1.0], 1.6, 0.0)]
        glow = node("glow", (154, 140), shapes=[S(ell(154, 140, 110, 90), "@torch", None, 0)])
        glow["anim"] = [ambient("opacity", [0.7, 1.0, 0.75], 2.2, 0.3)]
        torch_post = [glow, flame]
    beams = layer("beam", beam + torch_shapes, torch_post)
    floor_ = layer("floor", [S(rrect(0, FLOOR - 24, W, H - FLOOR + 24, 0), "@floor", "#26223e", 3)]
                   + [S(f"M{x},{FLOOR - 24} L{x - 20},{H}", None, "#26223e", 1.5, 0.7) for x in range(0, W + 60, 80)])
    layers_ = [wall, stair, beams, floor_]
    for l_ in layers_:
        looks._recolor_node(l_, time, None)
    name = {"dia": "Campanario de día", "atardecer": "Campanario al atardecer", "noche": "Campanario de noche"}[time]
    return scene("campanario", name, grads, [sky] + layers_)


# ---------------------------------------------------------------- castillo (recorte del existente)
CASTILLO_VIEW = [0, 250, 600, 450]

PLACES = {
    # id del lugar en el pack → escena, ventana visible [x, y, ancho, alto], y de los pies y escala
    "castillo": {"scene": "castle_night", "view": CASTILLO_VIEW, "floor": 662, "scale": 0.56},
    "bosque": {"scene": "bosque", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
    "cueva": {"scene": "cueva", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
    "rio": {"scene": "rio", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
    "aldea": {"scene": "aldea", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
    "casa": {"scene": "casa", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
    "cuarto": {"scene": "cuarto", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
    "campanario": {"scene": "campanario", "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE},
}
BUILDERS = {"bosque": bosque, "cueva": cueva, "rio": rio, "aldea": aldea, "casa": casa, "cuarto": cuarto, "campanario": campanario}


# ------------------------------------------------- posiciones de los personajes
ROLE_ORDER = ["hero", "helper", "villain"]
SLOT_X = {1: [0.5], 2: [0.34, 0.68], 3: [0.2, 0.48, 0.8]}


def stage_slots(roles):
    """Posición horizontal (fracción del ancho visible) de cada rol presente, en orden hero, helper, villain."""
    present = [r for r in ROLE_ORDER if r in roles]
    return dict(zip(present, SLOT_X[len(present)]))


def preview(place, rigs, clips, cast, t=0.4):
    sc_path = kit.OUT / "scenes" / f"{PLACES[place]['scene']}.json"
    sc = json.loads(sc_path.read_text(encoding="utf-8"))
    vx, vy, vw, vh = PLACES[place]["view"]
    sc = dict(sc, actors=[])
    for role, fx in stage_slots(cast).items():
        sc["actors"].append({"rig": cast[role], "x": vx + vw * fx, "y": PLACES[place]["floor"],
                             "scale": PLACES[place]["scale"], "clip": "idle" if role != "villain" else "talk",
                             "phase": 0.0})
    svg = castle.scene_svg(sc, rigs, clips, t)
    return svg.replace(f'viewBox="0 0 {sc["size"][0]} {sc["size"][1]}"', f'viewBox="{vx} {vy} {vw} {vh}"', 1) \
              .replace(f'width="{sc["size"][0]}" height="{sc["size"][1]}"', f'width="{vw}" height="{vh}"', 1)


# ----------------------------------------------- luces y estaciones por lugar
# Parámetros del cielo de cada fondo: x del sol, su y a mediodía, y de la línea de colinas.
SKY_AT = {
    "aldea": dict(w=W, h=H, sun_x=150, sun_y_day=100, horizon=300),
    "bosque": dict(w=W, h=H, sun_x=470, sun_y_day=110, horizon=268),
    "rio": dict(w=W, h=H, sun_x=100, sun_y_day=120, horizon=255),
    "castillo": dict(w=600, h=800, sun_x=470, sun_y_day=150, horizon=560),
}
# El castillo base es nocturno: de día sus colinas violetas pasan a verdes
CASTLE_DAY_SWAP = {"#2a2260": "#4f8a48", "#332a78": "#5f9a50", "#3d3288": "#6aa85a", "#251c5a": "#2f5f2f", "#2c6b5e": "#4a9a5a", "#245a50": "#3f8a50",
                   "#1b3f3a": "#2a5a30"}
LOOKS = {
    # lugar → (hora, estación) que se generan además del fondo base
    "aldea": [(t, s) for t in looks.TIMES for s in (None, *looks.SEASONS)],
    "bosque": [(t, None) for t in ("dia", "atardecer", "noche")],
    "rio": [(t, None) for t in ("dia", "atardecer", "noche")],
    "castillo": [("dia", None), ("atardecer", None)],
    "campanario": [("dia", None), ("atardecer", None)],
    "cuarto": [("dia", None), ("dia", "invierno"), ("dia", "primavera"), ("noche", "invierno"), ("noche", "primavera")],
}
# Hora del fondo base de cada lugar (la que se usa si el cuento no dice nada)
BASE_TIME = {"campanario": "noche", "aldea": "atardecer", "bosque": "dia", "rio": "dia", "castillo": "noche", "cuarto": "noche", "casa": "noche"}


def write_scene(out, data):
    path = out / "scenes" / f"{data['id']}.json"
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return path


def variants(out):
    """Genera las escenas de cada lugar a cada hora/estación. Devuelve {lugar: {clave: id de escena}}."""
    table = {}
    castle = json.loads((out / "scenes" / "castle_night.json").read_text(encoding="utf-8"))
    for place, wanted in LOOKS.items():
        table[place] = {BASE_TIME[place]: PLACES[place]["scene"]}
        for time, season in wanted:
            if place == "campanario":
                sc = campanario(time)
                sc["id"] = f"campanario__{time}"
            elif place == "cuarto":
                sc = cuarto(time, None if (time == "noche" and season == "primavera") else season)
                sc["id"] = f"cuarto__{looks.key_of(time, season)}"
            else:
                if place == "castillo":
                    base = castle
                elif place == "aldea":
                    base = aldea(season)
                else:
                    base = BUILDERS[place]()
                sc = looks.relook(base, time, season, **SKY_AT[place], moon_xy=(SKY_AT[place]["sun_x"], SKY_AT[place]["sun_y_day"]),
                                  swap=CASTLE_DAY_SWAP if place == "castillo" else None)
            write_scene(out, sc)
            table[place][looks.key_of(time, season)] = sc["id"]
    # La cocina es de noche y, con la ventana nevada, de invierno
    table["casa"] = {"noche": PLACES["casa"]["scene"], "noche__invierno": PLACES["casa"]["scene"]}
    return table


def main():
    out = kit.OUT
    (out / "scenes").mkdir(parents=True, exist_ok=True)
    (out / "preview").mkdir(parents=True, exist_ok=True)
    for pid, build in BUILDERS.items():
        data = build()
        path = out / "scenes" / f"{data['id']}.json"
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"{path.name}: {path.stat().st_size / 1024:.0f} KB")

    table = variants(out)
    extra = sorted({sid for m in table.values() for sid in m.values()} - {PLACES[p]["scene"] for p in PLACES})
    for p, m in table.items():
        PLACES[p]["looks"] = m
    index_path = out / "index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    index["scenes"] = ["medieval/scenes/castle_night.json"] + [f"medieval/scenes/{PLACES[p]['scene']}.json" for p in BUILDERS] \
        + [f"medieval/scenes/{sid}.json" for sid in extra]
    index["places"] = PLACES
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")

    rigs, clips = castle.load_rigs(), anim.load_clips("humanoid")
    cast = {"hero": "aldo", "helper": "zafiro", "villain": "codicio"}
    for pid in PLACES:
        (out / "preview" / f"stage_{pid}.svg").write_text(preview(pid, rigs, clips, cast), encoding="utf-8")
    print("índice y vistas previas escritos")


if __name__ == "__main__":
    main()
