#!/usr/bin/env python3
"""Objetos de la trama como rigs de una sola pieza (campana, linterna, olla, pan, búho…).

Usan el MISMO formato `caldero-rig` y el mismo renderizador que los personajes: huesos con pivote y
pistas de animación (`art/clips/props.json`, generado por make_clips.py). Así una campana puede
balancearse, una llama parpadear y una olla echar vapor sin código nuevo en la app.

Convención: el origen (0, 0) es el punto de apoyo (la base) y el eje y crece hacia abajo, igual que en
los personajes. `build_all()` devuelve los rigs; los escribe medieval_kit.py junto a los personajes.
"""
import medieval_kit as kit
from medieval_kit import S, ell, mix, node, poly, rrect, shade, shine

DARK = kit.DARK


def rig(id_, name, viewbox, palette, root):
    return {"format": "caldero-rig", "version": 1, "id": id_, "name": name, "rig": "prop",
            "viewBox": viewbox, "bodyScale": 1.0, "rest": {}, "itemUpright": False, "itemTilt": 0,
            "palette": palette, "root": root}


BRONZE = {"bronze": "#c98a3a", "bronze2": "#e8b45a", "wood": "#8a5a2b", "iron": "#4a4a56", "gold": "#f4c542"}


# ----------------------------------------------------------------- campana
def bell_body():
    return [S("M-14,-150 L14,-150 L17,-128 C42,-120 58,-84 64,-24 L-64,-24 C-58,-84 -42,-120 -17,-128 Z", "$bronze"),
            shade("M14,-150 L17,-128 C42,-120 58,-84 64,-24 L36,-24 C38,-80 30,-116 14,-150 Z"),
            shine("M-38,-100 C-34,-114 -24,-122 -14,-124 C-24,-114 -32,-104 -34,-82 Z"),
            S(rrect(-68, -30, 136, 14, 6), "$bronze2"),
            S(ell(0, -158, 9, 9), "$bronze2")]


def campana():
    clapper = node("clapper", (0, -112), shapes=[S(rrect(-2.5, -112, 5, 84, 2), "$iron", None),
                                                   S(ell(0, -26, 11, 11), "$iron")])
    swing = node("swing", (0, -170), shapes=bell_body(), post=[clapper])
    beam = [S(rrect(-82, -184, 164, 18, 5), "$wood"), S(rrect(-82, -178, 164, 5, 2), "#000000", None, 0, 0.12),
            S(rrect(-76, -168, 12, 56, 3), "$wood"), S(rrect(64, -168, 12, 56, 3), "$wood")]
    root = node("root", (0, 0), shapes=beam, post=[swing])
    return rig("campana", "Campana", [-110, -200, 220, 210], BRONZE, root)


def campana_rota():
    left = [S("M-60,-8 C-66,-44 -46,-70 -18,-78 L-6,-74 L-14,-60 L-4,-48 L-18,-34 L-8,-8 Z", "$bronze"),
            shade("M-30,-76 L-18,-78 L-6,-74 L-14,-60 L-22,-50 Z"),
            shine("M-52,-40 C-48,-56 -40,-64 -30,-68 C-40,-54 -46,-44 -48,-30 Z")]
    right = [S("M6,-8 L16,-30 L4,-46 L16,-58 L8,-72 C36,-66 62,-44 66,-8 Z", "$bronze"),
             shade("M40,-62 C54,-52 62,-34 66,-8 L44,-8 C46,-30 44,-50 40,-62 Z")]
    lip = [S(rrect(-70, -10, 140, 12, 5), "$bronze2"), S(rrect(-26, -22, 10, 8, 2), "$iron", None)]
    root = node("root", (0, 0), shapes=lip + left + right)
    return rig("campana_rota", "Campana rota", [-110, -110, 220, 120], BRONZE, root)


# ----------------------------------------------------------------- linterna
LAMP = {"iron": "#3d3a4a", "glass": "#ffd27a", "glassoff": "#3a3550", "flame": "#ffb43a", "flame2": "#fff3b0",
        "halo": "#ffd98a", "wood": "#8a5a2b"}


def lamp_frame(lit):
    glass = "$glass" if lit else "$glassoff"
    return [S(rrect(-26, -34, 52, 12, 4), "$iron"),
            S(rrect(-22, -122, 44, 90, 10), glass, "$iron", 3),
            shade(rrect(6, -118, 14, 82, 6)),
            S(poly([(-30, -124), (30, -124), (14, -146), (-14, -146)]), "$iron"),
            S(ell(0, -154, 8, 8), None, "$iron", 4),
            S("M-8,-146 L8,-146", None, "$iron", 4)] + \
        [S(rrect(x, -120, 3, 86, 1), "$iron", None) for x in (-8, 6)]


def linterna():
    glow = node("glow", (0, -76), shapes=[S(ell(0, -76, 170, 170), "$halo", None, 0, 0.16),
                                          S(ell(0, -76, 100, 100), "$halo", None, 0, 0.22),
                                          S(ell(0, -76, 56, 56), "$halo", None, 0, 0.3)])
    flame = node("flame", (0, -48), shapes=[S("M0,-100 C16,-80 16,-56 0,-46 C-16,-56 -16,-80 0,-100 Z", "$flame"),
                                            S("M0,-82 C8,-70 8,-58 0,-52 C-8,-58 -8,-70 0,-82 Z", "$flame2", None)])
    root = node("root", (0, 0), pre=[glow], shapes=lamp_frame(True), post=[flame])
    return rig("linterna", "Linterna encendida", [-190, -250, 380, 270], LAMP, root)


def linterna_apagada():
    root = node("root", (0, 0), shapes=lamp_frame(False)
                + [S("M0,-86 C6,-74 6,-60 0,-52 C-6,-60 -6,-74 0,-86 Z", "#2a2638", None)])
    return rig("linterna_apagada", "Linterna apagada", [-60, -170, 120, 190], LAMP, root)


# --------------------------------------------------------------------- olla
POT = {"iron": "#34343e", "iron2": "#4e4e5c", "soup": "#e9a64a", "soup2": "#f6c878", "steam": "#ffffff",
       "fire": "#ff8a2a", "fire2": "#ffd34a", "log": "#6a4426", "wood": "#8a5a2b"}


def olla():
    steam = [node(f"steam{i}", (x, -110), shapes=[S(ell(x, -110, 20, 15), "$steam", None, 0, 0.55),
                                                  S(ell(x + 12, -120, 14, 11), "$steam", None, 0, 0.45)])
             for i, x in enumerate((-30, 6, 38), start=1)]
    fire = node("fire", (0, 0), shapes=[S("M-44,0 C-48,-22 -30,-30 -26,-52 C-20,-34 -8,-30 -2,-60 C4,-34 18,-30 22,-50 C28,-30 46,-24 42,0 Z", "$fire"),
                                        S("M-24,0 C-26,-14 -14,-18 -10,-34 C-4,-20 6,-18 10,-30 C16,-16 26,-12 22,0 Z", "$fire2", None)])
    pot = [S(rrect(-82, -6, 164, 10, 4), "$log"),
           S("M-74,-96 C-84,-40 -56,-14 0,-12 C56,-14 84,-40 74,-96 Z", "$iron"),
           shade("M30,-94 C64,-80 74,-60 70,-50 C60,-20 30,-14 10,-12 C30,-40 36,-70 30,-94 Z"),
           shine("M-62,-84 C-68,-60 -60,-40 -46,-30 C-54,-52 -54,-70 -52,-86 Z"),
           S(ell(0, -96, 76, 15), "$iron2"),
           S(ell(0, -96, 66, 10), "$soup"),
           S(ell(-14, -97, 30, 4), "$soup2", None, 0, 0.7),
           S(rrect(-92, -100, 14, 10, 4), "$iron"), S(rrect(78, -100, 14, 10, 4), "$iron")]
    root = node("root", (0, 0), pre=[fire], shapes=pot, post=steam)
    return rig("olla", "Olla de sopa", [-120, -230, 240, 240], POT, root)


# ---------------------------------------------------------------------- pan
def pan():
    bread = [S(ell(0, -22, 42, 24), "#c98a4a"), shade("M10,-44 C40,-40 46,-22 42,-12 C30,-2 10,0 0,-2 C20,-14 22,-30 10,-44 Z"),
             shine("M-30,-34 C-22,-42 -10,-44 0,-43 C-12,-40 -22,-34 -28,-26 Z"),
             S("M-18,-36 L-6,-20", None, "#f4d9a0", 3), S("M-2,-40 L10,-22", None, "#f4d9a0", 3), S("M14,-38 L26,-22", None, "#f4d9a0", 3)]
    return rig("pan", "Pan redondo", [-70, -60, 140, 70], {}, node("root", (0, 0), shapes=bread))


def trozos_de_pan():
    def piece(x, y, rot):
        return [S(f"M{x - 16},{y} L{x + 16},{y} L{x + 12},{y - 20} Q{x},{y - 28} {x - 12},{y - 20} Z", "#c98a4a"),
                S(f"M{x - 12},{y - 6} L{x + 12},{y - 6}", None, "#f4d9a0", 2.5)]
    root = node("root", (0, 0), shapes=piece(-34, -2, 0) + piece(0, -2, 0) + piece(34, -2, 0))
    return rig("trozos_de_pan", "Tres pedazos de pan", [-70, -40, 140, 50], {}, root)


# --------------------------------------------------------------------- búho
OWL = {"body": "#8a6a4a", "belly": "#e8d3a8", "beak": "#f4b33a", "eye": "#ffd23f", "dark": "#2a1c14", "branch": "#5a3a22"}


def buho():
    eyes = node("eyes", (0, -86), shapes=[S(ell(-16, -86, 12, 12), "$eye"), S(ell(16, -86, 12, 12), "$eye"),
                                          S(ell(-16, -86, 5, 7), "$dark", None), S(ell(16, -86, 5, 7), "$dark", None),
                                          S(ell(-18, -89, 2, 2), "#ffffff", None), S(ell(14, -89, 2, 2), "#ffffff", None)])
    body = [S("M-34,-4 C-44,-40 -40,-96 -22,-110 L-18,-124 L-8,-112 L8,-112 L18,-124 L22,-110 C40,-96 44,-40 34,-4 Z", "$body"),
            S("M-20,-6 C-26,-34 -22,-70 0,-76 C22,-70 26,-34 20,-6 Z", "$belly"),
            shade("M14,-110 C40,-96 44,-40 34,-4 L18,-4 C28,-44 26,-90 14,-110 Z"),
            S(poly([(-4, -78), (4, -78), (0, -66)]), "$beak", None)]
    for y in (-52, -38, -24):
        body.append(S(f"M-14,{y} Q-7,{y + 6} 0,{y} Q7,{y + 6} 14,{y}", None, "#c9a870", 2))
    body += [S(rrect(-56, -6, 112, 8, 4), "$branch")]
    root = node("root", (0, 0), shapes=body, post=[eyes])
    return rig("buho", "Búho", [-70, -140, 140, 150], OWL, root)


def build_all():
    return [campana(), campana_rota(), linterna(), linterna_apagada(), olla(), pan(), trozos_de_pan(), buho()]
