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
    bridge = [S(rrect(210, 330, 230, 14, 4), "#a8703c", "#4a2c14", 2.5)]
    for x in range(222, 430, 26):
        bridge.append(S(rrect(x, 332, 4, 10, 1), "#4a2c14", None, 0, 0.5))
    bridge += [S(rrect(214, 300, 6, 34, 2), "#8a5a2b", "#3a2412", 2), S(rrect(430, 300, 6, 34, 2), "#8a5a2b", "#3a2412", 2),
               S(rrect(214, 304, 222, 5, 2), "#8a5a2b", "#3a2412", 2)]
    near = layer("near", [S(f"M0,{FLOOR - 12} C160,{FLOOR - 36} 380,{FLOOR - 4} {W},{FLOOR - 30} L{W},{H} L0,{H} Z",
                           "@grass", "#1e5e3a", 3),
                          S(f"M0,{FLOOR + 34} C200,{FLOOR + 14} 420,{FLOOR + 48} {W},{FLOOR + 20} L{W},{H} L0,{H} Z", "#277a48", None, 0)]
                + bridge + oak(70, FLOOR - 6, 0.85)
                + [S(ell(x, FLOOR + y, 6, 4), c, None, 0) for x, y, c in
                   [(180, 44, "#ff8fa3"), (330, 60, "#f4c542"), (520, 46, "#ffffff"), (600, 64, "#ff8fa3")]])
    return scene("rio", "Río de plata", grads, [sky, far, water, near])


# ------------------------------------------------------------------- aldea
def house(x, base, w, h, wall, roof):
    o = [S(rrect(x, base - h, w, h, 3), wall, "#4a2c1a", 2.5),
         S(rrect(x + w * 0.62, base - h + 2, w * 0.36, h - 4, 3), "#000000", None, 0, 0.12),
         S(poly([(x - 8, base - h + 2), (x + w + 8, base - h + 2), (x + w / 2, base - h - h * 0.55)]), roof, "#4a1a2a", 2.5),
         S(poly([(x + w / 2, base - h - h * 0.55), (x + w + 8, base - h + 2), (x + w / 2 + 3, base - h + 2)]), "#000000", None, 0, 0.18),
         S(rrect(x + w * 0.4, base - h * 0.55, w * 0.2, h * 0.55, 3), "#5a3a2a", "#2a1a14", 2),
         S(rrect(x + w * 0.12, base - h * 0.7, w * 0.2, h * 0.24, 2), "#ffd27a", "#5a3a14", 2)]
    return o


def aldea():
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
    mid = layer("mid", house(60, 350, 90, 70, "#e8d2a8", "#b04a52") + house(190, 346, 76, 60, "#dcc294", "#8a4a96")
                + house(330, 350, 96, 76, "#e8d2a8", "#c05a3a") + mill
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
                + [S(rrect(x, FLOOR - 10, 4, 36, 1), "#8a5a2b", "#3a2412", 2) for x in (30, 52, 74)]
                + [S(rrect(26, FLOOR - 4, 56, 5, 1), "#8a5a2b", "#3a2412", 2)]
                + [S(ell(x, FLOOR + y, 6, 4), c, None, 0) for x, y, c in
                   [(540, 40, "#ff8fa3"), (590, 60, "#f4c542"), (20, 62, "#ffffff"), (500, 66, "#ffffff")]], smoke)
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
}
BUILDERS = {"bosque": bosque, "cueva": cueva, "rio": rio, "aldea": aldea, "casa": casa}


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


def main():
    out = kit.OUT
    (out / "scenes").mkdir(parents=True, exist_ok=True)
    (out / "preview").mkdir(parents=True, exist_ok=True)
    for pid, build in BUILDERS.items():
        data = build()
        path = out / "scenes" / f"{data['id']}.json"
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"{path.name}: {path.stat().st_size / 1024:.0f} KB")

    index_path = out / "index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    index["scenes"] = ["medieval/scenes/castle_night.json"] + [f"medieval/scenes/{PLACES[p]['scene']}.json" for p in BUILDERS]
    index["places"] = PLACES
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")

    rigs, clips = castle.load_rigs(), anim.load_clips("humanoid")
    cast = {"hero": "aldo", "helper": "zafiro", "villain": "codicio"}
    for pid in PLACES:
        (out / "preview" / f"stage_{pid}.svg").write_text(preview(pid, rigs, clips, cast), encoding="utf-8")
    print("índice y vistas previas escritos")


if __name__ == "__main__":
    main()
