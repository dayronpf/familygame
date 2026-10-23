#!/usr/bin/env python3
"""Fondos del pack «Mar de las Estrellas» (docs/26), como DATOS (`caldero-scene`), en 4:3 (640×480).

Los mismos principios que `scenes_story.py` (pack medieval): capas `sky`, `far`, `mid`, `near`; los pies de los
personajes en `FLOOR`; las horas del día se sacan de un fondo base con `looks.relook` (nuevo cielo y colores
retocados, con las luces encendidas respetadas). Lo que no tiene cielo se resuelve aparte:

* **arrecife** (bajo el agua): el fondo es agua, no cielo; de noche solo se oscurece (`dim`).
* **camarote**: interior con ojo de buey; cada hora dibuja su propio cielo por el cristal.
* **bodega** y **cueva_tesoro**: interiores sin hora (solo el fondo base).

Escribe:
    art/mar/scenes/<id>.json          ← lo que lee la app
    art/mar/preview/stage_<id>.svg    ← vista previa con tres personajes del pack
Y actualiza `art/mar/index.json` (lista de escenas y bloque `places`).

Uso:
    python3 tools/art/mar_scenes.py
"""
import copy
import json
import math
from pathlib import Path

import anim
import looks
import medieval_kit as kit
import scene_castle as castle
from medieval_kit import S, ell, mix, n, node, poly, rrect, star
from scenes_story import ambient, fireflies, full, hills, layer, lcg, lin, scene

OUT = Path(__file__).resolve().parent.parent.parent / "art" / "mar"
W, H = 640, 480
FLOOR = 410
SCALE = 0.6
DARK = kit.DARK


# ------------------------------------------------------------------ piezas
def sky_base(sun_x, sun_y=110):
    grads = {"sky": lin([[0, "#3f86d6", 1], [0.6, "#8fd0f0", 1], [1, "#e8f6ff", 1]]),
             "sun": {"type": "radial", "stops": [[0, "#fff6c8", 0.85], [1, "#fff6c8", 0]]}}
    return grads, layer("sky", [full("@sky"), S(ell(sun_x, sun_y, 120, 120), "@sun", None, 0),
                                S(ell(sun_x, sun_y, 30, 30), "#fff3c4", None, 0)])


def sea(y_top, y_bot, seed, crest="#e8f6ff", grad="@sea"):
    """Franja de mar con crestas que brillan y se apagan."""
    r = lcg(seed)
    waves = []
    rows = max(2, int((y_bot - y_top) / 22))
    for i in range(rows * 3):
        x = 20 + next(r) * (W - 60)
        y = y_top + 8 + next(r) * (y_bot - y_top - 14)
        w = 22 + (y - y_top) / (y_bot - y_top + 1) * 26
        nd = node(f"wv{seed}_{i}", (x, y), shapes=[S(f"M{n(x)},{n(y)} Q{n(x + w / 2)},{n(y - 5)} {n(x + w)},{n(y)}", None, crest, 2.6, 0.85)])
        nd["anim"] = [ambient("opacity", [0.15, 0.9, 0.15], 2.4 + next(r) * 1.4, next(r) * 3)]
        waves.append(nd)
    return [S(f"M0,{y_top} L{W},{y_top} L{W},{y_bot} L0,{y_bot} Z", grad, None, 0)], waves


def sea_grad():
    return lin([[0, "#5ab4e0", 1], [1, "#1f6aa8", 1]])


def palm(x, base, h, lean=1, seed=1):
    """Palmera con el tronco curvo y las hojas que se mecen (giro suave sobre la copa)."""
    tx, ty = x + lean * h * 0.28, base - h
    trunk = [S(f"M{n(x - 9)},{base} C{n(x - 6 + lean * h * 0.05)},{n(base - h * 0.5)} {n(tx - 8)},{n(ty + 20)} {n(tx - 4)},{n(ty)} "
               f"L{n(tx + 4)},{n(ty)} C{n(tx + 6)},{n(ty + 22)} {n(x + 6 + lean * h * 0.08)},{n(base - h * 0.5)} {n(x + 9)},{base} Z",
               "#b0804a", "#5a3a1e", 2.5)]
    for k in range(1, 6):  # anillos del tronco
        f = k / 6
        cx = x + (tx - x) * f ** 1.4
        cy = base - h * f
        trunk.append(S(f"M{n(cx - 7)},{n(cy)} Q{n(cx)},{n(cy + 4)} {n(cx + 7)},{n(cy)}", None, "#7a5430", 2))
    leaves = []
    for i, ang in enumerate((-160, -120, -60, -20, -95)):
        a = math.radians(ang)
        ex, ey = tx + math.cos(a) * 70, ty + math.sin(a) * 34 + 26
        mx, my = tx + math.cos(a) * 40, ty + math.sin(a) * 30 - 6
        leaves.append(S(f"M{n(tx)},{n(ty)} Q{n(mx)},{n(my - 14)} {n(ex)},{n(ey)} Q{n(mx + 4)},{n(my + 8)} {n(tx)},{n(ty)} Z",
                        "#3fa85a" if i % 2 else "#2f9050", "#1a5a30", 2))
    leaves += [S(ell(tx - 6, ty + 6, 7, 7), "#8a5a2b", "#3a2412", 1.5), S(ell(tx + 6, ty + 8, 7, 7), "#8a5a2b", "#3a2412", 1.5)]
    crown = node(f"palm{seed}", (tx, ty), shapes=leaves)
    crown["anim"] = [ambient("rotate", [-2.5, 2.5, -2.5], 4.0 + seed * 0.3, seed * 0.7)]
    return trunk, crown


def ship(x, base, k=1.0, sail="#f6efe0"):
    """La Gaviota de perfil: casco, un mástil, vela con la estrella y la bandera de la luna."""
    def p(v):
        return v * k
    sh = [S(f"M{n(x - p(80))},{n(base - p(30))} L{n(x + p(90))},{n(base - p(30))} Q{n(x + p(84))},{n(base)} {n(x + p(60))},{n(base + p(10))} "
            f"L{n(x - p(56))},{n(base + p(10))} Q{n(x - p(74))},{n(base)} {n(x - p(80))},{n(base - p(20))} Z", "#8a4a2a", "#3a1a0e", 2.5),
          S(rrect(x - p(80), base - p(30), p(170), p(7), p(2)), "#c9a070", "#3a1a0e", 1.5),
          S(rrect(x - p(3), base - p(150), p(6), p(122), p(2)), "#6a4426", "#2a180c", 1.5),
          S(f"M{n(x + p(4))},{n(base - p(140))} C{n(x + p(56))},{n(base - p(120))} {n(x + p(58))},{n(base - p(60))} {n(x + p(4))},{n(base - p(44))} Z",
            sail, "#8a7a5a", 2),
          S(star(x + p(30), base - p(92), p(12), p(5)), "#f4c542", None),
          S(poly([(x + p(3), base - p(150)), (x + p(30), base - p(158)), (x + p(3), base - p(166))]), "#2a5aa0", "#1a2a5a", 1.5)]
    for i in range(3):
        sh.append(S(ell(x - p(40) + i * p(36), base - p(14), p(5), p(5)), "#3a2a1a", None))
    return sh


def gulls(seed, count=3, y_max=200):
    r = lcg(seed)
    out = []
    for i in range(count):
        x, y = 60 + next(r) * (W - 120), 50 + next(r) * (y_max - 50)
        w = 10 + next(r) * 6
        nd = node(f"gull{seed}_{i}", (x, y), shapes=[S(f"M{n(x - w)},{n(y)} Q{n(x - w / 2)},{n(y - 7)} {n(x)},{n(y)} "
                                                       f"Q{n(x + w / 2)},{n(y - 7)} {n(x + w)},{n(y)}", None, "#ffffff", 2.6)])
        nd["anim"] = [ambient("rotate", [-6, 6, -6], 1.6 + next(r), next(r) * 2)]
        out.append(nd)
    return out


def barrel(x, base, k=1.0):
    w, h = 34 * k, 46 * k
    return [S(f"M{n(x - w / 2)},{n(base)} C{n(x - w / 2 - 5 * k)},{n(base - h / 2)} {n(x - w / 2 - 5 * k)},{n(base - h / 2)} {n(x - w / 2)},{n(base - h)} "
              f"L{n(x + w / 2)},{n(base - h)} C{n(x + w / 2 + 5 * k)},{n(base - h / 2)} {n(x + w / 2 + 5 * k)},{n(base - h / 2)} {n(x + w / 2)},{n(base)} Z",
              "#a8703a", "#4a2a12", 2.5),
            S(rrect(x - w / 2 - 3 * k, base - h * 0.78, w + 6 * k, 4 * k, 1), "#5a5a66", None),
            S(rrect(x - w / 2 - 3 * k, base - h * 0.26, w + 6 * k, 4 * k, 1), "#5a5a66", None),
            S(rrect(x + w * 0.12, base - h + 3, 5 * k, h - 6, 2), "#000000", None, 0, 0.12)]


def crate(x, base, w, h):
    return [S(rrect(x - w / 2, base - h, w, h, 2), "#c9a070", "#4a2c14", 2.5),
            S(f"M{n(x - w / 2 + 4)},{n(base - 4)} L{n(x + w / 2 - 4)},{n(base - h + 4)}", None, "#8a5a2b", 3),
            S(rrect(x - w / 2, base - h, w, 6, 2), "#a8804a", None)]


def planks(y_top, y_bot, color="#b08a58", line="#6a4a26"):
    sh = [S(f"M0,{y_top} L{W},{y_top} L{W},{y_bot} L0,{y_bot} Z", color, None, 0)]
    y, k = y_top + 14, 0
    while y < y_bot:
        sh.append(S(f"M0,{n(y)} L{W},{n(y)}", None, line, 1.8, 0.6))
        k += 1
        y += 14 + k * 3
    return sh


def rock(x, base, w, h, col="#8a8a9a", dark="#4a4a5a"):
    return [S(f"M{n(x - w / 2)},{base} C{n(x - w / 2)},{n(base - h * 0.7)} {n(x - w / 4)},{n(base - h)} {n(x)},{n(base - h)} "
              f"C{n(x + w / 3)},{n(base - h)} {n(x + w / 2)},{n(base - h * 0.6)} {n(x + w / 2)},{base} Z", col, dark, 2.5),
            S(f"M{n(x + w / 8)},{n(base - h * 0.95)} C{n(x + w / 3)},{n(base - h * 0.9)} {n(x + w / 2)},{n(base - h * 0.5)} {n(x + w / 2)},{base} "
              f"L{n(x + w / 4)},{base} Z", "#000000", None, 0, 0.14)]


# ------------------------------------------------------------------ playa
def playa():
    """La playa de la Isla Quieta: arena, dos palmeras, el mar con La Gaviota a lo lejos y conchas en la orilla."""
    grads, sky = sky_base(470, 110)
    grads["sea"] = sea_grad()
    grads["sand"] = lin([[0, "#f4dca0", 1], [1, "#d8b070", 1]])
    water, waves = sea(258, 340, 3)
    far = layer("far", water + ship(150, 270, 0.55), waves + gulls(4))
    t1, c1 = palm(70, FLOOR - 4, 230, 1, 1)
    t2, c2 = palm(590, FLOOR + 6, 260, -1, 2)
    sand = S(f"M0,{FLOOR - 64} C180,{FLOOR - 84} 420,{FLOOR - 60} {W},{FLOOR - 80} L{W},{H} L0,{H} Z", "@sand", "#a8803a", 3)
    foam = S(f"M0,{FLOOR - 64} C180,{FLOOR - 84} 420,{FLOOR - 60} {W},{FLOOR - 80}", None, "#ffffff", 5, 0.75)
    mid = layer("mid", [sand, foam] + t1 + t2, [c1, c2])
    shells = [S(star(140, FLOOR + 48, 11, 5), "#f08a5a", "#a04a2a", 1.5), S(ell(470, FLOOR + 40, 9, 7), "#ffd0c8", "#c08070", 1.5),
              S(ell(300, FLOOR + 62, 7, 5), "#ffffff", "#b0a090", 1.5)]
    crab = node("crab", (520, FLOOR + 58), shapes=[S(ell(520, FLOOR + 58, 13, 9), "#e05a3a", "#7a1a0a", 2),
                                                   S(ell(510, FLOOR + 50, 3, 3), "#1b1230", None), S(ell(530, FLOOR + 50, 3, 3), "#1b1230", None),
                                                   S(ell(502, FLOOR + 56, 6, 4), "#e05a3a", "#7a1a0a", 1.5),
                                                   S(ell(538, FLOOR + 56, 6, 4), "#e05a3a", "#7a1a0a", 1.5)])
    crab["anim"] = [ambient("rotate", [-4, 4, -4], 1.2, 0.0)]
    near = layer("near", [S(f"M0,{FLOOR + 40} C200,{FLOOR + 26} 420,{FLOOR + 50} {W},{FLOOR + 30} L{W},{H} L0,{H} Z", "#e8c888", None, 0)] + shells,
                 [crab])
    return scene("playa", "Playa de la Isla Quieta", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ puerto
def puerto():
    """El puerto: muelle de tablones, casitas de colores y La Gaviota amarrada."""
    grads, sky = sky_base(120, 100)
    grads["sea"] = sea_grad()
    water, waves = sea(270, FLOOR - 40, 7)
    houses = []
    for i, (x, w, h, wall, roof) in enumerate([(20, 70, 70, "#f4d8a0", "#c04a3a"), (96, 56, 86, "#a8d0e8", "#3a5a9a"),
                                               (160, 64, 62, "#f0b0a0", "#8a3a3a"), (232, 50, 78, "#fff0d0", "#2a7a6a")]):
        houses += [S(rrect(x, 270 - h, w, h, 2), wall, "#4a3a2a", 2), S(poly([(x - 6, 272 - h), (x + w + 6, 272 - h), (x + w / 2, 240 - h)]), roof, "#3a1a1a", 2),
                   S(rrect(x + w / 2 - 7, 270 - 24, 14, 24, 2), "#6a4a30", None), S(rrect(x + 8, 270 - h + 14, 12, 12, 2), "#ffd27a", "#5a3a14", 1.5)]
    far = layer("far", [hills(236, 16, "#8fd29a", 71)] + houses + water + ship(470, FLOOR - 52, 0.95), waves + gulls(8, 4))
    dock = planks(FLOOR - 40, H, "#b08a58", "#6a4a26")
    posts = [S(rrect(x, FLOOR - 50, 14, 22, 4), "#6a4a30", "#2a1a10", 2) for x in (30, 610)]
    rope = [S(ell(560, FLOOR + 30, 26, 10), None, "#d8c08a", 5), S(ell(560, FLOOR + 30, 15, 6), None, "#d8c08a", 5)]
    mid = layer("mid", dock + posts)
    near = layer("near", rope + barrel(80, FLOOR + 50, 0.9) + crate(130, FLOOR + 52, 40, 34))
    return scene("puerto", "Puerto", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ cubierta
def cubierta():
    """La cubierta de La Gaviota: el palo mayor con la vela, el timón, barriles y el mar detrás de la borda."""
    grads, sky = sky_base(110, 100)
    grads["sea"] = sea_grad()
    water, waves = sea(250, 330, 11)
    far = layer("far", water + ship(560, 268, 0.3), waves + gulls(12))
    rail = [S(rrect(0, 300, W, 12, 3), "#8a5a30", "#3a1a0e", 2.5)] + \
           [S(rrect(x, 312, 8, FLOOR - 340, 2), "#a8703a", "#3a1a0e", 2) for x in range(14, W, 46)]
    mast = [S(rrect(452, 0, 18, FLOOR - 30, 4), "#7a4a26", "#2a180c", 2.5),
            S(rrect(380, 40, 160, 9, 3), "#6a4426", "#2a180c", 2)]
    sail = node("sail", (461, 46), shapes=[
        S("M386,48 L534,48 C548,120 540,200 528,236 L392,236 C380,200 374,120 386,48 Z", "#f6efe0", "#8a7a5a", 2.5),
        S("M470,50 C490,120 488,190 480,236 L528,236 C540,200 548,120 534,48 Z", "#000000", None, 0, 0.08),
        S(star(461, 140, 26, 11), "#f4c542", "#a8801a", 2)])
    sail["anim"] = [ambient("rotate", [-1.2, 1.2, -1.2], 5.0, 0.0)]
    ropes = [S(f"M461,40 L{x},{FLOOR - 70}", None, "#5a4a3a", 1.6, 0.7) for x in (360, 600)]
    deck = planks(FLOOR - 70, H, "#c09a68", "#7a5a32")
    wheel = node("wheel", (112, FLOOR - 110), shapes=[S(ell(112, FLOOR - 110, 34, 34), None, "#7a4a26", 7),
                                                      S(ell(112, FLOOR - 110, 8, 8), "#c9a070", "#3a1a0e", 2)]
                 + [S(f"M{n(112 + math.cos(a) * 8)},{n(FLOOR - 110 + math.sin(a) * 8)} L{n(112 + math.cos(a) * 44)},{n(FLOOR - 110 + math.sin(a) * 44)}",
                      None, "#7a4a26", 6) for a in [i * math.pi / 4 for i in range(8)]])
    wheel["anim"] = [ambient("rotate", [-8, 8, -8], 6.0, 0.0)]
    stand = [S(rrect(102, FLOOR - 110, 20, 52, 3), "#8a5a30", "#3a1a0e", 2)]
    mid = layer("mid", rail + deck + mast + ropes + stand + barrel(590, FLOOR - 40, 1.0) + barrel(548, FLOOR - 46, 0.85), [sail, wheel])
    near = layer("near", [S(rrect(0, H - 26, W, 26, 0), "#8a5a30", "#3a1a0e", 2.5)])
    return scene("cubierta", "Cubierta de La Gaviota", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ mar abierto
def mar_abierto():
    """En alta mar: la proa del barco apuntando al horizonte, olas grandes y ningún puerto a la vista."""
    grads, sky = sky_base(500, 120)
    grads["sea"] = sea_grad()
    grads["deep"] = lin([[0, "#3a96cc", 1], [1, "#13518a", 1]])
    water, waves = sea(262, H, 15)
    big = []
    for i, y in enumerate((300, 340)):
        nd = node(f"swell{i}", (W / 2, y), shapes=[S(f"M-40,{y} " + " ".join(f"Q{x + 40},{y - 18} {x + 80},{y}" for x in range(-40, W + 40, 80)),
                                                     None, "#e8f6ff", 4, 0.7)])
        nd["anim"] = [ambient("opacity", [0.3, 0.9, 0.3], 3.4, i * 1.2)]
        big.append(nd)
    far = layer("far", water, waves + big + gulls(16, 2))
    bow = [S(f"M-20,{FLOOR - 60} L470,{FLOOR - 60} C560,{FLOOR - 56} 620,{FLOOR - 40} 660,{FLOOR - 10} L660,{H} L-20,{H} Z", "#c09a68", "#5a3a1e", 3),
           S(f"M470,{FLOOR - 60} C560,{FLOOR - 56} 620,{FLOOR - 40} 660,{FLOOR - 10}", None, "#8a5a30", 10),
           S(f"M560,{FLOOR - 62} L700,{FLOOR - 120}", None, "#6a4426", 9)]
    bow += [S(f"M0,{n(y)} L{n(W)},{n(y)}", None, "#7a5a32", 1.8, 0.6) for y in (FLOOR - 40, FLOOR - 16, FLOOR + 14, FLOOR + 48)]
    posts = [S(rrect(x, FLOOR - 92, 8, 32, 2), "#8a5a30", "#3a1a0e", 2) for x in (30, 120, 210, 300, 390, 470)]
    mid = layer("mid", bow + posts + [S(rrect(0, FLOOR - 96, 480, 8, 3), "#8a5a30", "#3a1a0e", 2)])
    spray = []
    r = lcg(19)
    for i in range(6):
        x, y = 600 + next(r) * 40, FLOOR - 30 + next(r) * 60
        nd = node(f"spray{i}", (x, y), shapes=[S(ell(x, y, 4 + next(r) * 4, 4 + next(r) * 4), "#ffffff", None, 0, 0.8)])
        nd["anim"] = [ambient("opacity", [0.0, 0.9, 0.0], 1.6, next(r) * 1.6)]
        spray.append(nd)
    near = layer("near", [], spray)
    return scene("mar_abierto", "Mar abierto", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ cofa
def cofa():
    """Lo alto del palo mayor: la cesta de la cofa, el mástil que sigue hacia arriba y el mar allá abajo."""
    grads, sky = sky_base(140, 120)
    grads["sea"] = lin([[0, "#7ac8e8", 1], [1, "#2a78b0", 1]])
    water, waves = sea(330, H, 23)
    far = layer("far", water + ship(150, 352, 0.28) + [S(ell(520, 346, 70, 12), "#e8d8a0", "#a8905a", 1.5),
                                                        S(ell(520, 336, 30, 14), "#5fa85a", "#2a5a30", 1.5)],
                waves + gulls(24, 4, 300))
    mast = [S(rrect(312, 0, 16, FLOOR - 60, 4), "#7a4a26", "#2a180c", 2.5)]
    flag = node("flag", (320, 20), shapes=[S(poly([(328, 14), (390, 26), (328, 44)]), "#2a5aa0", "#1a2a5a", 2),
                                           S(kit.crescent(352, 29, 7, 8, 0.4), "#fff3c4", None, 0)])
    flag["anim"] = [ambient("rotate", [-4, 4, -4], 1.8, 0.0)]
    ropes = [S(f"M320,{y} L{x},{FLOOR + 80}", None, "#5a4a3a", 2, 0.6) for x, y in ((40, 60), (600, 60))]
    floor = [S(ell(320, FLOOR - 20, 250, 22), "#8a5a30", "#3a1a0e", 2.5)]
    mid = layer("mid", ropes + mast + floor, [flag])
    basket = [S(f"M70,{FLOOR - 56} L570,{FLOOR - 56} L548,{H} L92,{H} Z", "#a8703a", "#3a1a0e", 3),
              S(rrect(64, FLOOR - 64, 512, 14, 6), "#8a5a30", "#3a1a0e", 2.5)]
    basket += [S(f"M{x},{FLOOR - 50} L{x + (x - 320) * 0.04},{H}", None, "#7a4a26", 3, 0.6) for x in range(110, 560, 50)]
    near = layer("near", basket)
    return scene("cofa", "Cofa del mástil", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ faro
def faro(night=False):
    """El faro del Abuelo Faro, a rayas, sobre las rocas; de noche su luz barre el mar."""
    grads, sky = sky_base(140, 110)
    grads["sea"] = sea_grad()
    water, waves = sea(270, FLOOR - 30, 31)
    far = layer("far", water + ship(130, 300, 0.4), waves + gulls(32, 2))
    tower = [S("M450,360 L470,120 L540,120 L560,360 Z", "#ffffff", "#5a4a5a", 3)]
    for y0, y1 in ((150, 190), (230, 270), (310, 350)):
        fx = lambda y, s: 505 + s * (35 + (y - 120) / 240 * 20)
        tower.append(S(poly([(fx(y0, -1), y0), (fx(y0, 1), y0), (fx(y1, 1), y1), (fx(y1, -1), y1)]), "#d8463a", None, 0))
    tower += [S(rrect(460, 108, 90, 14, 4), "#3a3a4a", "#1a1a2a", 2), S(rrect(478, 70, 54, 40, 6), "#ffe08a", "#5a4a2a", 2.5),
              S(poly([(470, 72), (540, 72), (505, 44)]), "#d8463a", "#5a1a1a", 2.5),
              S(rrect(492, 296, 26, 64, 4), "#5a3a2a", "#2a1a14", 2)]
    post = []
    if night:  # el haz de luz (de día no se ve)
        beam = node("beam", (505, 90), shapes=[S("M505,80 L40,30 L40,150 L505,100 Z", "#fff3c4", None, 0, 0.28),
                                               S(ell(505, 90, 46, 46), "#fff3c4", None, 0, 0.3)])
        beam["anim"] = [ambient("opacity", [0.35, 1.0, 0.35], 3.0, 0.0)]
        post.append(beam)
    rocks = rock(560, FLOOR - 20, 240, 110) + rock(400, FLOOR - 10, 160, 70, "#9a9aa8")
    ground = S(f"M0,{FLOOR - 40} C160,{FLOOR - 56} 380,{FLOOR - 30} {W},{FLOOR - 48} L{W},{H} L0,{H} Z", "#8a8a96", "#4a4a5a", 3)
    mid = layer("mid", rocks + tower + [ground], post)
    near = layer("near", [S(f"M0,{FLOOR + 44} C200,{FLOOR + 30} 420,{FLOOR + 54} {W},{FLOOR + 36} L{W},{H} L0,{H} Z", "#6a6a78", None, 0)]
                 + [S(ell(x, FLOOR + y, 6, 4), "#7ab06a", None, 0) for x, y in ((90, 50), (330, 60), (600, 52))])
    return scene("faro", "El faro", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ laguna
def laguna():
    """La laguna de las sirenas: agua quieta entre rocas, nenúfares y una roca lisa para sentarse."""
    grads, sky = sky_base(460, 110)
    grads["lagoon"] = lin([[0, "#6ad4c8", 1], [1, "#1f8a8a", 1]])
    t1, c1 = palm(600, 300, 170, -1, 4)
    far = layer("far", [hills(240, 30, "#5fa86a", 81), hills(272, 18, "#3f8a5a", 82)] + rock(90, 300, 160, 90, "#7a8a9a") + t1, [c1])
    r = lcg(83)
    ripples = []
    for i in range(6):
        x, y = 80 + i * 90, 310 + next(r) * 50
        nd = node(f"rp{i}", (x, y), shapes=[S(f"M{n(x)},{n(y)} Q{n(x + 18)},{n(y - 5)} {n(x + 36)},{n(y)}", None, "#e8fff8", 2.5, 0.8)])
        nd["anim"] = [ambient("opacity", [0.2, 0.9, 0.2], 3.0, i * 0.5)]
        ripples.append(nd)
    lilies = []
    for x, y in ((160, 330), (380, 350), (520, 320)):
        lilies += [S(ell(x, y, 22, 8), "#4aa85a", "#1a5a30", 2), S(poly([(x, y), (x + 20, y - 3), (x + 20, y + 3)]), "#1f8a8a", None, 0),
                   S(ell(x - 4, y - 5, 6, 5), "#ff9ac0", "#a04a6a", 1.2)]
    water = layer("mid", [S(f"M0,286 L{W},286 L{W},{FLOOR - 30} C420,{FLOOR - 14} 220,{FLOOR - 40} 0,{FLOOR - 20} Z", "@lagoon", "#0f5a5a", 3)] + lilies,
                  ripples + [c1])
    shore = [S(f"M0,{FLOOR - 24} C180,{FLOOR - 40} 400,{FLOOR - 12} {W},{FLOOR - 34} L{W},{H} L0,{H} Z", "#b0a890", "#5a5040", 3)] + \
            rock(560, FLOOR + 10, 120, 50, "#9a9aa8")
    near = layer("near", shore + [S(ell(x, FLOOR + y, 7, 4), c, None, 0) for x, y, c in ((120, 46, "#ff9ac0"), (300, 60, "#ffffff"))],
                 fireflies(6, 85, 260, 400, "#c8fff0"))
    return scene("laguna", "Laguna de las sirenas", grads, [sky, far, water, near])


# ------------------------------------------------------------------ selva
def selva():
    """La selva de la isla: troncos, hojas enormes, lianas que se mecen y flores de colores."""
    grads, sky = sky_base(320, 80)
    grads["ground"] = lin([[0, "#7ab05a", 1], [1, "#3f7a3a", 1]])
    far = layer("far", [hills(200, 40, "#3f9a5a", 91), hills(250, 30, "#2f7a4a", 92)]
                + [S(rrect(x, 120, 20, 260, 6), "#5a4a30", "#2a1a10", 2) for x in (60, 250, 470)]
                + [S(ell(x, 130, 90, 60), "#2f8a4a", "#14462a", 3) for x in (70, 260, 480, 620)])
    lianas = []
    for i, x in enumerate((140, 360, 560)):
        nd = node(f"liana{i}", (x, 0), shapes=[S(f"M{x},0 C{x - 14},80 {x + 16},160 {x},{230 + i * 20}", None, "#3a7a2a", 4)]
                  + [S(ell(x + (8 if k % 2 else -8), 60 + k * 40, 9, 5), "#5ab04a", "#2a6a2a", 1.5) for k in range(4)])
        nd["anim"] = [ambient("rotate", [-2, 2, -2], 4.5 + i, i * 0.8)]
        lianas.append(nd)
    ground = S(f"M0,{FLOOR - 50} C200,{FLOOR - 66} 420,{FLOOR - 40} {W},{FLOOR - 58} L{W},{H} L0,{H} Z", "@ground", "#2a5a2a", 3)
    path = S(f"M220,{H} C260,{FLOOR + 10} 330,{FLOOR - 20} 400,{FLOOR - 50}", None, "#c8a870", 30, 0.8)
    mid = layer("mid", [ground, path], lianas)
    leaves = []
    for x, y, k, ang in ((20, FLOOR + 40, 1.2, -30), (620, FLOOR + 30, 1.3, 210), (110, FLOOR + 70, 0.9, -60)):
        a = math.radians(ang)
        ex, ey = x + math.cos(a) * 90 * k, y + math.sin(a) * 90 * k
        leaves.append(S(f"M{x},{y} Q{n((x + ex) / 2 - 30 * k)},{n((y + ey) / 2 - 30 * k)} {n(ex)},{n(ey)} "
                        f"Q{n((x + ex) / 2 + 30 * k)},{n((y + ey) / 2 + 30 * k)} {x},{y} Z", "#2f9a4a", "#14462a", 2.5))
    flowers = [S(star(x, FLOOR + y, 9, 4, 5), c, None) for x, y, c in ((180, 46, "#ff6a8a"), (460, 58, "#f4c542"), (540, 40, "#ff8a3a"))]
    near = layer("near", leaves + flowers, fireflies(5, 93, 200, 400))
    return scene("selva", "Selva de la isla", grads, [sky, far, mid, near])


# ------------------------------------------------------------------ arrecife
def arrecife():
    """Bajo el agua: rayos de luz, corales, algas que se mecen, peces y burbujas sobre la arena."""
    grads = {"water": lin([[0, "#3ac0d8", 1], [0.6, "#1f8ab0", 1], [1, "#0f5a8a", 1]]),
             "ray": lin([[0, "#e8fff8", 0.5], [1, "#e8fff8", 0]])}
    rays = []
    for i, x in enumerate((120, 300, 470)):
        nd = node(f"ray{i}", (x, 0), shapes=[S(f"M{x - 20},0 L{x + 20},0 L{x + 90},360 L{x + 20},360 Z", "@ray", None, 0)])
        nd["anim"] = [ambient("opacity", [0.3, 0.9, 0.3], 5.0, i * 1.4)]
        rays.append(nd)
    water = {"id": "water", "pivot": [0, 0], "pre": [], "shapes": [full("@water")], "post": rays}
    fish = []
    r = lcg(101)
    for i, (x, y, c) in enumerate(((120, 120, "#f4c542"), (480, 90, "#ff7a5a"), (300, 200, "#ffffff"), (560, 220, "#8ad0ff"))):
        nd = node(f"fish{i}", (x, y), shapes=[S(ell(x, y, 16, 9), c, mix(c, DARK, 0.5), 2), S(poly([(x - 14, y), (x - 26, y - 8), (x - 26, y + 8)]), c, mix(c, DARK, 0.5), 2),
                                              S(ell(x + 8, y - 2, 2.2, 2.2), DARK, None)])
        nd["anim"] = [ambient("rotate", [-5, 5, -5], 2.0 + next(r), next(r) * 2)]
        fish.append(nd)
    far = layer("far", [hills(300, 30, "#2a7a9a", 102), hills(330, 20, "#236a8a", 103)], fish)
    weeds = []
    for i, (x, h, c) in enumerate(((40, 160, "#3aa86a"), (90, 120, "#2f9060"), (590, 170, "#3aa86a"), (620, 110, "#2f9060"), (250, 90, "#4ab87a"))):
        nd = node(f"weed{i}", (x, FLOOR), shapes=[S(f"M{x - 6},{FLOOR} C{x - 20},{FLOOR - h / 3} {x + 14},{FLOOR - h * 2 / 3} {x},{FLOOR - h} "
                                                    f"C{x + 20},{FLOOR - h * 2 / 3} {x - 8},{FLOOR - h / 3} {x + 6},{FLOOR} Z", c, "#145a3a", 2)])
        nd["anim"] = [ambient("rotate", [-6, 6, -6], 3.2 + i * 0.3, i * 0.6)]
        weeds.append(nd)
    corals = [S(f"M470,{FLOOR - 20} C460,{FLOOR - 80} 480,{FLOOR - 100} 490,{FLOOR - 70} C500,{FLOOR - 110} 520,{FLOOR - 100} 510,{FLOOR - 60} "
                f"C530,{FLOOR - 90} 548,{FLOOR - 70} 530,{FLOOR - 20} Z", "#ff7a9a", "#a03a5a", 2.5),
              S(ell(170, FLOOR - 30, 34, 26), "#ffb05a", "#a0602a", 2.5), S(ell(150, FLOOR - 40, 8, 8), "#ffd08a", None, 0),
              S(ell(185, FLOOR - 26, 7, 7), "#ffd08a", None, 0)]
    sand = S(f"M0,{FLOOR - 30} C180,{FLOOR - 46} 420,{FLOOR - 20} {W},{FLOOR - 40} L{W},{H} L0,{H} Z", "#e8d8a0", "#a8905a", 3)
    mid = layer("mid", [sand] + corals + [S(star(330, FLOOR + 30, 12, 5), "#ff8a5a", "#a04a2a", 1.5)], weeds)
    bubbles = []
    r = lcg(107)
    for i in range(10):
        x, y = 40 + next(r) * 560, 60 + next(r) * 300
        rad = 3 + next(r) * 5
        nd = node(f"bub{i}", (x, y), shapes=[S(ell(x, y, rad, rad), None, "#e8fff8", 1.8, 0.8)])
        nd["anim"] = [ambient("opacity", [0.0, 0.9, 0.0], 2.4 + next(r) * 2, next(r) * 3)]
        bubbles.append(nd)
    near = layer("near", [], bubbles)
    return scene("arrecife", "Arrecife", grads, [water, far, mid, near])


def dim(base, time):
    """Una escena sin cielo (bajo el agua) a otra hora: solo se retocan los colores (de noche, azul oscuro)."""
    sc = copy.deepcopy(base)
    sc["id"] = f'{base["id"]}__{time}'
    sc["name"] = f'{base["name"]} ({time})'
    for g in sc["gradients"].values():
        g["stops"] = [[o, looks.tone(c, time, None), a] for o, c, a in g["stops"]]
    for lyr in sc["layers"]:
        looks._recolor_node(lyr, time, None)
    return sc


# ------------------------------------------------------------------ cueva
def cueva_tesoro():
    """La cueva del tesoro: paredes de roca, charcos que brillan y, al fondo, la boca de la cueva con luz."""
    grads = {"glow": {"type": "radial", "stops": [[0, "#8affe8", 0.6], [1, "#8affe8", 0]]},
             "mouth": {"type": "radial", "stops": [[0, "#fff6d0", 1], [1, "#8ac8e0", 1]]}}
    back = layer("sky", [full("#2a2440"), S(ell(320, 220, 90, 110), "@mouth", None, 0)])
    walls = [S(f"M0,0 L{W},0 L{W},{H} L560,{H} C540,300 480,140 400,110 C360,96 280,96 240,110 C160,140 100,300 80,{H} L0,{H} Z", "#4a3f66", "#1e1830", 3),
             S(f"M0,0 L{W},0 L{W},40 C460,70 180,70 0,40 Z", "#3a3054", None, 0)]
    for x, h in ((140, 70), (220, 46), (420, 60), (500, 80)):
        walls.append(S(poly([(x - 14, 40), (x + 14, 40), (x, 40 + h)]), "#3a3054", "#1e1830", 2))
    far = layer("far", walls)
    floor = S(f"M0,{FLOOR - 40} C200,{FLOOR - 56} 420,{FLOOR - 30} {W},{FLOOR - 50} L{W},{H} L0,{H} Z", "#5a4f78", "#2a2440", 3)
    pools = []
    for i, (x, y, w) in enumerate(((150, FLOOR + 30, 60), (470, FLOOR + 44, 70))):
        nd = node(f"pool{i}", (x, y), shapes=[S(ell(x, y, w * 1.4, w * 0.5), "@glow", None, 0), S(ell(x, y, w, 12), "#6ae0d8", "#2a7a8a", 2)])
        nd["anim"] = [ambient("opacity", [0.5, 1.0, 0.5], 3.0, i * 1.3)]
        pools.append(nd)
    crystals = [S(poly([(x - 8, base), (x, base - h), (x + 8, base)]), "#a8f0ff", "#3a8aa8", 2) for x, base, h in ((40, FLOOR - 30, 40), (56, FLOOR - 28, 26), (600, FLOOR - 40, 46))]
    mid = layer("mid", [floor] + crystals, pools)
    near = layer("near", rock(40, H, 120, 60, "#3a3054", "#1e1830") + rock(610, H, 100, 50, "#3a3054", "#1e1830"))
    return scene("cueva_tesoro", "Cueva del tesoro", grads, [back, far, mid, near])


# ------------------------------------------------------------------ bodega
def bodega():
    """La bodega del barco: vigas, barriles, cajas, sacos y un farol que se balancea."""
    grads = {"lamp": {"type": "radial", "stops": [[0, "#ffd98a", 0.55], [1, "#ffd98a", 0]]}}
    wall = layer("sky", planks(0, H, "#7a5432", "#4a2c14") + [S(rrect(0, y, W, 16, 0), "#5a3a1e", "#2a180c", 2) for y in (30, 150)])
    lamp = node("lamp", (320, 160), shapes=[S("M320,150 L320,176", None, "#2a1a10", 2.5), S(ell(320, 200, 120, 120), "@lamp", None, 0),
                                            S(rrect(306, 176, 28, 34, 6), "#ffe08a", "#4a4a56", 3)])
    lamp["anim"] = [ambient("rotate", [-6, 6, -6], 3.0, 0.0)]
    far = layer("far", barrel(60, FLOOR - 30, 1.2) + barrel(110, FLOOR - 36, 1.0) + barrel(85, FLOOR - 82, 1.0)
                + crate(560, FLOOR - 30, 70, 56) + crate(580, FLOOR - 86, 54, 46)
                + [S(ell(470, FLOOR - 44, 26, 20), "#d8c08a", "#6a5a3a", 2), S(ell(500, FLOOR - 40, 22, 18), "#c9b07a", "#6a5a3a", 2)], [lamp])
    mid = layer("mid", planks(FLOOR - 40, H, "#8a6038", "#4a2c14"))
    near = layer("near", [S(rrect(0, 0, 26, H, 0), "#4a2c14", "#2a180c", 2), S(rrect(W - 26, 0, 26, H, 0), "#4a2c14", "#2a180c", 2)])
    return scene("bodega", "Bodega del barco", grads, [wall, far, mid, near])


# ------------------------------------------------------------------ camarote
def camarote(time="noche"):
    """El camarote: paredes de madera, una hamaca, un baúl, un farol y el ojo de buey (con el cielo de cada hora)."""
    night = time == "noche"
    grads = {"lamp": {"type": "radial", "stops": [[0, "#ffd98a", 0.5 if night else 0.25], [1, "#ffd98a", 0]]}}
    wall = layer("sky", planks(0, H, "#9a6a40" if not night else "#5a3e2a", "#5a3a1e" if not night else "#3a2414"))
    sky_c = "#9fd6ff" if not night else "#1c1a4a"
    port = [S(ell(470, 150, 54, 54), "#c9a14a", "#5a4a1a", 4), S(ell(470, 150, 42, 42), sky_c, None, 0),
            S("M433.1,170 L506.9,170 A42,42 0 0 1 433.1,170 Z", "#3a86c0" if not night else "#16285a", None, 0)]
    if night:
        port += [S(kit.crescent(482, 136, 10, 11, 0.45), "#fff3c4", None, 0), S(ell(450, 130, 1.6, 1.6), "#fff6d8", None, 0),
                 S(ell(492, 158, 1.4, 1.4), "#fff6d8", None, 0)]
    else:
        port += [S(ell(456, 134, 14, 6), "#ffffff", None, 0, 0.9)]
    port.append(S(ell(470, 150, 42, 42), None, "#5a4a1a", 3))
    hammock = node("hammock", (250, 150), shapes=[S("M120,150 C170,250 330,250 380,150", None, "#6a4a30", 3),
                                                  S("M130,160 C180,240 320,240 370,160 C330,210 170,210 130,160 Z", "#e8d8b0", "#8a7a5a", 2.5),
                                                  S("M150,186 C200,214 300,214 350,186", None, "#c84a4a", 3, 0.8)])
    hammock["anim"] = [ambient("rotate", [-2, 2, -2], 4.0, 0.0)]
    lamp = [S(ell(90, 140, 110, 110), "@lamp", None, 0), S("M90,96 L90,120", None, "#2a1a10", 2.5),
            S(rrect(76, 120, 28, 34, 6), "#ffe08a", "#4a4a56", 3)]
    far = layer("far", port + lamp + [S(rrect(110, 120, 8, 40, 2), "#6a4a30", None), S(rrect(382, 120, 8, 40, 2), "#6a4a30", None)], [hammock])
    floor = planks(FLOOR - 40, H, "#a8784a" if not night else "#6a4a2e", "#5a3a1e")
    chest = [S(rrect(520, FLOOR - 76, 90, 50, 6), "#8a5a30", "#3a1a0e", 2.5), S(f"M520,{FLOOR - 66} C540,{FLOOR - 96} 590,{FLOOR - 96} 610,{FLOOR - 66}", "#a0703a", "#3a1a0e", 2.5),
             S(rrect(558, FLOOR - 70, 14, 16, 3), "#f4c542", "#7a5a1a", 1.5)]
    rug = [S(ell(300, FLOOR + 30, 170, 26), "#3a6ab0", "#1a3a6a", 2), S(ell(300, FLOOR + 30, 130, 18), None, "#f4c542", 2.5)]
    mid = layer("mid", floor + rug + chest)
    near = layer("near", [])
    sid = "camarote" if night else f"camarote__{time}"
    return scene(sid, "Camarote" + ("" if night else f" ({time})"), grads, [wall, far, mid, near])


# ------------------------------------------------------------------ tabla
PLACES = {p: {"scene": p, "view": [0, 0, W, H], "floor": FLOOR, "scale": SCALE}
          for p in ("playa", "puerto", "cubierta", "mar_abierto", "cofa", "faro", "laguna", "selva", "arrecife",
                    "cueva_tesoro", "bodega", "camarote")}
BUILDERS = {"playa": playa, "puerto": puerto, "cubierta": cubierta, "mar_abierto": mar_abierto, "cofa": cofa, "faro": faro,
            "laguna": laguna, "selva": selva, "arrecife": arrecife, "cueva_tesoro": cueva_tesoro, "bodega": bodega,
            "camarote": camarote}
# Hora del fondo base y horas que se generan además (las del pack: `places[].times`)
BASE_TIME = {"camarote": "noche", "cueva_tesoro": None, "bodega": None}
SKY_AT = {"playa": (470, 110, 258), "puerto": (120, 100, 270), "cubierta": (110, 100, 250), "mar_abierto": (500, 120, 262),
          "cofa": (140, 120, 330), "faro": (140, 110, 270), "laguna": (460, 110, 286), "selva": (320, 80, 200)}


def pack_times():
    pack = json.loads((OUT.parent.parent / "content" / "packs" / "mar" / "pack.json").read_text(encoding="utf-8"))
    return {p["id"]: p.get("times") for p in pack["places"]}


def write_scene(data):
    (OUT / "scenes" / f"{data['id']}.json").write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def build_all():
    """Escribe todas las escenas y devuelve {lugar: {hora: id de escena}}."""
    table = {}
    for place, times in pack_times().items():
        base_time = BASE_TIME.get(place, "dia")
        base = BUILDERS[place]()
        write_scene(base)
        table[place] = {base_time: base["id"]} if base_time else {}
        for time in times or []:
            if time == base_time:
                continue
            if place == "camarote":
                sc = camarote(time)
            elif place == "arrecife":
                sc = dim(base, time)
            else:
                src = faro(night=True) if place == "faro" and time == "noche" else base
                sx, sy, hz = SKY_AT[place]
                sc = looks.relook(src, time, None, W, H, sx, sy, hz, moon_xy=(sx, sy))
            write_scene(sc)
            table[place][time] = sc["id"]
    return table


def preview(place, rigs, clips, t=0.4):
    sc = json.loads((OUT / "scenes" / f"{PLACES[place]['scene']}.json").read_text(encoding="utf-8"))
    cast = [("vega", "idle", 0.2), ("estela", "talk", 0.48), ("nacar" if place in ("laguna", "arrecife", "playa") else "bruno", "wave", 0.8)]
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
    index["scenes"] = sorted(f"mar/scenes/{f.name}" for f in (OUT / "scenes").glob("*.json"))
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
