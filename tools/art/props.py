#!/usr/bin/env python3
"""Objetos de la trama como rigs de una sola pieza (campana, linterna, olla, pan, búho…).

Usan el MISMO formato `caldero-rig` y el mismo renderizador que los personajes: huesos con pivote y
pistas de animación (`art/clips/props.json`, generado por make_clips.py). Así una campana puede
balancearse, una llama parpadear y una olla echar vapor sin código nuevo en la app.

Convención: el origen (0, 0) es el punto de apoyo (la base) y el eje y crece hacia abajo, igual que en
los personajes. `build_all()` devuelve los rigs; los escribe medieval_kit.py junto a los personajes.
"""
import math

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

# ------------------------------------------------------------------ cabrita
GOAT = {"fur": "#f3ecda", "fur2": "#d9cfb4", "hoof": "#4a3a30", "horn": "#cdb67a", "ear": "#b98a62",
        "eye": "#2a1c14", "nose": "#e9a6a0", "beard": "#e8dfc6"}


def cabrita():
    """Cabrita de perfil mirando a la derecha. Origen: bajo las pezuñas, centrada. Huesos: legsA/legsB
    (patas), tail, head (cabeza y cuello), eyes (parpadeo)."""
    def leg(x):
        return [S(rrect(x - 5, -34, 10, 34, 4), "$fur2"), S(rrect(x - 6, -8, 12, 8, 3), "$hoof")]

    legs_b = node("legsB", (-26, -34), shapes=leg(-26) + leg(30))           # patas lejanas (hacia atrás)
    legs_a = node("legsA", (-12, -34), shapes=leg(-12) + leg(42))           # patas cercanas
    tail = node("tail", (-48, -62), shapes=[S("M-48,-62 C-62,-72 -66,-58 -58,-52 C-56,-56 -52,-58 -48,-56 Z", "$fur")])
    eyes = node("eyes", (26, -96), shapes=[S(ell(26, -96, 3.4, 4.4), "$eye", None), S(ell(25, -97.5, 1.1, 1.1), "#ffffff", None)])
    head = node("head", (34, -70), shapes=[
        S("M28,-72 C34,-96 46,-110 62,-100 C74,-96 82,-84 80,-74 C74,-66 52,-68 44,-60 C38,-60 30,-64 28,-72 Z", "$fur"),
        S("M62,-100 C74,-96 82,-84 80,-74 C74,-66 64,-70 60,-76 Z", "$fur2", None, 0, 0.55),
        S(ell(78, -80, 4.2, 3.2), "$nose", None),
        S("M44,-60 C46,-48 52,-44 54,-52 C52,-56 48,-58 44,-60 Z", "$beard"),
        S("M34,-99 C28,-120 40,-126 44,-114 C42,-110 38,-104 34,-99 Z", "$horn"),
        S("M46,-102 C46,-114 58,-114 54,-104 Z", "$ear"),
        S("M38,-100 C26,-100 20,-92 24,-86 C30,-90 36,-92 40,-94 Z", "$ear"),
    ], post=[eyes])
    body = [S("M-52,-70 C-56,-92 -30,-100 0,-98 C34,-98 48,-92 46,-72 C46,-52 36,-42 0,-40 C-34,-40 -50,-48 -52,-70 Z", "$fur"),
            shade("M10,-96 C34,-98 48,-92 46,-72 C46,-52 36,-42 4,-40 C24,-56 22,-78 10,-96 Z"),
            shine("M-40,-86 C-30,-94 -14,-96 0,-96 C-18,-90 -32,-80 -38,-70 Z")]
    root = node("root", (0, 0), pre=[legs_b], shapes=body, post=[legs_a, tail, head])
    return rig("cabrita", "Cabrita", [-80, -135, 170, 140], GOAT, root)

# ------------------------------------------------------------------ bolsa
BAG = {"leather": "#9a6a3c", "leather2": "#b98a52", "rope": "#e8d3a8", "coin": "#f4e9c0"}


def bolsa():
    """Bolsa de cuero atada con una cuerda; asoma una moneda. Hueso `bag` (tintineo)."""
    bag = node("bag", (0, -4), shapes=[
        S("M-34,-4 C-48,-30 -34,-62 -12,-70 L12,-70 C34,-62 48,-30 34,-4 Z", "$leather"),
        shade("M12,-70 C34,-62 48,-30 34,-4 L16,-4 C26,-26 24,-52 12,-70 Z"),
        shine("M-30,-28 C-28,-44 -20,-58 -10,-64 C-18,-50 -24,-40 -26,-24 Z"),
        S("M-14,-70 L-18,-84 L-6,-78 L0,-88 L6,-78 L18,-84 L14,-70 Z", "$leather2"),
        S(rrect(-16, -72, 32, 6, 3), "$rope", "#5a4a30", 2),
        S(ell(0, -92, 7, 7), "$coin", "#8a7a3a", 2)])
    root = node("root", (0, 0), post=[bag])
    return rig("bolsa", "Bolsa de monedas", [-70, -110, 140, 120], BAG, root)


# ------------------------------------------------------------------ cometa
KITE = {"red": "#d9453d", "red2": "#f0675a", "bow": "#f4c542", "string": "#e8e0c8", "wood": "#8a5a2b"}


def cometa():
    """Cometa roja con cola de lazos amarillos. Origen: el punto donde se ata la cuerda (abajo).
    Huesos: `kite` (cabeceo), `tail` (ondeo de la cola)."""
    tail_shapes = [S("M0,0 C14,18 -14,34 0,52 C14,70 -14,86 0,104", None, "$string", 2.5)]
    for i, y in enumerate((22, 48, 74, 100)):
        x = 6 if i % 2 == 0 else -6
        tail_shapes += [S(poly([(x - 9, y - 5), (x, y), (x - 9, y + 5)]), "$bow", "#8a6a14", 1.5),
                        S(poly([(x + 9, y - 5), (x, y), (x + 9, y + 5)]), "$bow", "#8a6a14", 1.5)]
    tail = node("tail", (0, 0), shapes=tail_shapes)
    kite = node("kite", (0, 0), shapes=[
        S("M0,0 L40,-52 L0,-132 L-40,-52 Z", "$red", "#6a1a14", 3),
        S("M0,0 L0,-132 L40,-52 Z", "$red2", None, 0, 0.55),
        S("M0,-132 L0,0", None, "$wood", 2.5), S("M-40,-52 L40,-52", None, "$wood", 2.5)], post=[tail])
    root = node("root", (0, 0), post=[kite])
    return rig("cometa", "Cometa", [-60, -150, 120, 270], KITE, root)

# --------------------------------------------------------------- girasol
SUN = {"stem": "#4f9a3c", "stem2": "#3a7a2c", "petal": "#f4c542", "petal2": "#ffd966", "core": "#6a4226", "seed": "#3a2412"}


def girasol():
    """Girasol alto. Huesos: `stem` (balanceo y crecimiento) y `head` (cabeceo)."""
    petals = []
    for k in range(14):
        a = 2 * math.pi * k / 14
        cx, cy = 0 + 30 * math.cos(a), -168 + 30 * math.sin(a)
        petals.append(S(ell(cx, cy, 15, 9), "$petal" if k % 2 == 0 else "$petal2", "#b8841a", 1.5))
    core = [S(ell(0, -168, 22, 22), "$core", "#2a180c", 2)] + \
           [S(ell(7 * math.cos(a) * r, -168 + 7 * math.sin(a) * r, 1.6, 1.6), "$seed", None, 0)
            for a, r in [(0.6, 1), (1.9, 1.4), (3.1, 1), (4.3, 1.5), (5.4, 1), (0, 0.2)]]
    head = node("head", (0, -150), shapes=petals + core)
    leaves = [S("M0,-70 C-34,-92 -46,-70 -40,-54 C-26,-58 -10,-62 0,-70 Z", "$stem2", "#2a5a1c", 2),
              S("M0,-100 C34,-122 46,-100 40,-84 C26,-88 10,-92 0,-100 Z", "$stem2", "#2a5a1c", 2)]
    stem = node("stem", (0, 0), shapes=[S(rrect(-5, -158, 10, 158, 4), "$stem")] + leaves, post=[head])
    root = node("root", (0, 0), post=[stem], shapes=[S(ell(0, 2, 22, 6), "#5a3a22", None, 0, 0.7)])
    return rig("girasol", "Girasol", [-70, -210, 140, 220], SUN, root)


# --------------------------------------------------------------- semillas
def semillas():
    """Sobrecito de papel con semillas de girasol. Origen: base, centrado."""
    seeds = [S(ell(-14 + i * 14, -8, 5, 9), "#f2ead4", "#3a2412", 1.5) for i in range(3)]
    packet = [S(rrect(-34, -70, 68, 68, 5), "#c9a06a", "#6a4a22", 3),
              S(poly([(-34, -70), (34, -70), (0, -42)]), "#b88a52", "#6a4a22", 2.5),
              S(ell(0, -30, 13, 13), "#f4c542", "#8a6a14", 2), S(ell(0, -30, 5, 5), "#6a4226", None, 0)] + seeds
    return rig("semillas", "Semillas de girasol", [-50, -90, 100, 100], {}, node("root", (0, 0), shapes=packet))


# ---------------------------------------------------------------- piedras
def piedras():
    """Fila de cinco piedras planas para cruzar un río. Origen: centro de la fila, a ras de agua."""
    shapes = []
    for i, (x, y, rx) in enumerate([(-110, 0, 30), (-55, -8, 26), (0, 2, 30), (55, -6, 26), (110, 0, 30)]):
        shapes += [S(ell(x, y, rx, 13), "#8a8f9a", "#3a3f4a", 2.5), S(ell(x - 6, y - 4, rx * 0.6, 5), "#b9bfca", None, 0, 0.7),
                   S(ell(x, y + 14, rx * 0.9, 5), "#a8d8f0", None, 0, 0.5)]
    return rig("piedras", "Piedras del río", [-150, -40, 300, 80], {}, node("root", (0, 0), shapes=shapes))


# ---------------------------------------------------------------- hierba
GRASS = {"leaf": "#9fd8e8", "leaf2": "#cfeff5", "halo": "#bfe8ff"}


def hierba():
    """Hierba de luna: tres tallos plateados que brillan. Huesos: `glow` (pulso) y `leaves` (brisa)."""
    glow = node("glow", (0, -50), shapes=[S(ell(0, -50, 70, 60), "$halo", None, 0, 0.18), S(ell(0, -50, 38, 34), "$halo", None, 0, 0.28)])
    blades = []
    for x, h, bend in [(-18, 84, -14), (0, 104, 4), (18, 80, 16)]:
        blades += [S(f"M{x-4},0 C{x-4},{-h*0.5} {x+bend-4},{-h*0.8} {x+bend},{-h} C{x+bend+4},{-h*0.8} {x+4},{-h*0.5} {x+4},0 Z", "$leaf", "#5a9ab0", 2),
                   S(f"M{x},0 C{x},{-h*0.5} {x+bend*0.8},{-h*0.8} {x+bend},{-h}", None, "$leaf2", 1.5)]
    leaves = node("leaves", (0, 0), shapes=blades)
    root = node("root", (0, 0), pre=[glow], post=[leaves])
    return rig("hierba", "Hierba de luna", [-80, -120, 160, 130], GRASS, root)

# ------------------------------------------------- pedernal, vela, saco, cofre
def pedernal():
    """Pedernal (piedra de las chispas) con dos chispitas. Origen: base."""
    shapes = [S("M-34,-2 L-40,-22 L-22,-44 L8,-48 L36,-30 L40,-6 L12,2 Z", "#5c606c", "#2a2c34", 2.5),
              S("M-22,-44 L8,-48 L36,-30 L10,-30 Z", "#8a8f9c", None, 0, 0.8),
              S(poly([(-4, -52), (2, -64), (8, -52), (2, -56)]), "#ffd34a", None, 0), S(poly([(24, -40), (30, -52), (34, -40), (30, -43)]), "#fff3b0", None, 0)]
    return rig("pedernal", "Pedernal", [-60, -80, 120, 90], {}, node("root", (0, 0), shapes=shapes))


LIT = {"wax": "#f2e7c8", "flame": "#ffb43a", "flame2": "#fff3b0", "halo": "#ffd98a", "dish": "#8a6a3a"}


def vela():
    """Cabo de vela en un platillo. Huesos `flame` y `glow` (los clips `glow` de la linterna sirven)."""
    glow = node("glow", (0, -60), shapes=[S(ell(0, -60, 64, 64), "$halo", None, 0, 0.18), S(ell(0, -60, 34, 34), "$halo", None, 0, 0.3)])
    flame = node("flame", (0, -46), shapes=[S("M0,-84 C10,-70 10,-54 0,-46 C-10,-54 -10,-70 0,-84 Z", "$flame"), S("M0,-74 C5,-66 5,-58 0,-52 C-5,-58 -5,-66 0,-74 Z", "$flame2", None)])
    root = node("root", (0, 0), pre=[glow], shapes=[S(ell(0, -4, 26, 7), "$dish", "#4a3414", 2), S(rrect(-9, -46, 18, 42, 3), "$wax", "#8a7a5a", 2)], post=[flame])
    return rig("vela", "Cabo de vela", [-80, -130, 160, 140], LIT, root)


def saco():
    """Saco de tela atado con una cuerda. Origen: base."""
    shapes = [S("M-36,-2 C-52,-34 -34,-70 -12,-78 L12,-78 C34,-70 52,-34 36,-2 Z", "#c0a070", "#5a4220", 3),
              S("M12,-78 C34,-70 52,-34 36,-2 L18,-2 C28,-30 26,-60 12,-78 Z", "#000000", None, 0, 0.14),
              S(poly([(-14, -78), (-20, -92), (-6, -84), (0, -96), (6, -84), (20, -92), (14, -78)]), "#b09060", "#5a4220", 2),
              S(rrect(-16, -80, 32, 6, 3), "#e8d3a8", "#5a4a30", 2)]
    return rig("saco", "Saco", [-70, -110, 140, 120], {}, node("root", (0, 0), shapes=shapes))


def cofre():
    """Cofrecito de madera con monedas asomando. Origen: base."""
    shapes = [S(rrect(-44, -46, 88, 46, 4), "#8a5a2b", "#3a2412", 3), S("M-44,-46 C-44,-76 44,-76 44,-46 Z", "#a06a34", "#3a2412", 3),
              S(rrect(-46, -50, 92, 8, 3), "#4a4a56", "#2a2a32", 2), S(rrect(-6, -52, 12, 16, 3), "#f4c542", "#8a6a14", 2),
              S(ell(-14, -78, 8, 4), "#f4c542", "#8a6a14", 1.5), S(ell(10, -80, 8, 4), "#ffd966", "#8a6a14", 1.5)]
    return rig("cofre", "Cofre", [-70, -110, 140, 120], {}, node("root", (0, 0), shapes=shapes))


def build_all():
    return [campana(), campana_rota(), linterna(), linterna_apagada(), olla(), pan(), trozos_de_pan(), buho(), cabrita(), bolsa(), cometa(), girasol(), semillas(), piedras(), hierba(), pedernal(), vela(), saco(), cofre()]
