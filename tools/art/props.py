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
def _seed(cx, cy, ang, k=1.0):
    """Semilla de girasol: gota blanquecina con dos rayas oscuras, girada `ang` grados."""
    c, s_ = math.cos(math.radians(ang)), math.sin(math.radians(ang))

    def pt(x, y):
        return f"{(cx + (x * c - y * s_) * k):.1f},{(cy + (x * s_ + y * c) * k):.1f}"

    body = f"M{pt(0, -13)} C{pt(9, -9)} {pt(9, 9)} {pt(0, 13)} C{pt(-9, 9)} {pt(-9, -9)} {pt(0, -13)} Z"
    stripes = [S(f"M{pt(-3, -8)} L{pt(-3, 8)}", None, "#3a2412", 1.4 * k), S(f"M{pt(3, -8)} L{pt(3, 8)}", None, "#3a2412", 1.4 * k)]
    return [S(body, "#f4f0e0", "#3a2412", 1.8 * k)] + stripes


def _pouch(cx):
    return [S(f"M{cx - 30},-4 C{cx - 42},-28 {cx - 32},-58 {cx - 12},-66 L{cx + 12},-66 C{cx + 32},-58 {cx + 42},-28 {cx + 30},-4 Z",
              "#b8844a", "#5a3a1a", 3),
            shade(f"M{cx + 12},-66 C{cx + 32},-58 {cx + 42},-28 {cx + 30},-4 L{cx + 12},-4 C{cx + 22},-30 {cx + 18},-54 {cx + 12},-66 Z"),
            S(f"M{cx - 16},-62 C{cx - 10},-76 {cx - 4},-70 {cx},-76 C{cx + 4},-70 {cx + 10},-76 {cx + 16},-62 Z", "#a07038", "#5a3a1a", 2.5),
            S(rrect(cx - 15, -68, 30, 7, 3), "#7a5430", "#4a2c10", 2),
            S(f"M{cx - 3},-62 C{cx - 8},-46 {cx - 2},-40 {cx - 6},-30", None, "#7a5430", 2.5)]


def semillas(count=5):
    """Bolsita de tela abierta con las semillas de girasol (`count`) en fila delante. Origen: base, centrado."""
    pos = [(8, -22, -20), (28, -17, 12), (46, -22, -12), (64, -17, 18), (82, -22, -8)]
    seeds = []
    for cx, cy, ang in pos[:count]:
        seeds += _seed(cx - 38, cy + 8, ang, 1.15)
    return rig("semillas" if count == 5 else "semillas_dos", "Semillas de girasol" if count == 5 else "Dos semillas de girasol",
               [-70, -92, 150, 100], {}, node("root", (0, 0), shapes=_pouch(-30) + seeds))


def semillas_dos():
    return semillas(2)


# ----------------------------------------------------------------- macetas
def maceta():
    """Maceta de barro con tierra. Origen: base, centrado."""
    return rig("maceta", "Maceta", [-34, -52, 68, 54], {}, node("root", (0, 0), shapes=_pot()))


def _pot():
    return [S("M-24,-34 L24,-34 L18,0 L-18,0 Z", "#c8663a", "#5a2a14", 2.5),
            shade("M10,-34 L24,-34 L18,0 L8,0 Z"),
            S(rrect(-28, -44, 56, 12, 4), "#d9784a", "#5a2a14", 2.5),
            S(ell(0, -42, 22, 4), "#4a2c1a", None, 0)]


def maceta_brote():
    """Maceta con dos brotes verdes que asoman (el girasol recién nacido)."""
    sprouts = []
    for sx, lean in ((-8, -1), (9, 1)):
        sprouts += [S(f"M{sx},-42 C{sx + lean * 2},-54 {sx + lean * 3},-62 {sx + lean * 5},-68", None, "#3a8a2c", 3),
                    S(f"M{sx + lean * 5},-68 C{sx + lean * 5 - 12},-74 {sx + lean * 5 - 16},-62 {sx + lean * 5 - 10},-60 Z", "#5fb04a", "#2a5a1c", 1.5),
                    S(f"M{sx + lean * 5},-68 C{sx + lean * 5 + 12},-74 {sx + lean * 5 + 16},-62 {sx + lean * 5 + 10},-60 Z", "#5fb04a", "#2a5a1c", 1.5)]
    return rig("maceta_brote", "Maceta con brotes", [-34, -80, 68, 82], {}, node("root", (0, 0), shapes=_pot() + sprouts))


# ------------------------------------------------- objetos de la ronda 8
def manta():
    """Manta roja con rayas: cubre al que duerme. Origen: base, centrado."""
    body = [S("M-66,0 L-66,-20 Q-52,-42 -22,-36 Q8,-46 38,-37 Q62,-34 66,-18 L66,0 Z", "#b0453f", "#5a1a14", 2.5),
            shade("M30,-37 Q62,-34 66,-18 L66,0 L40,0 Q46,-20 30,-37 Z")]
    stripes = [S(f"M{x},-36 Q{x + 3},-18 {x},0", None, "#e07a68", 3) for x in (-44, -14, 16, 46)]
    fold = [S("M-62,-22 Q-30,-32 0,-26 Q30,-34 62,-22", None, "#f0a090", 2, 0.7)]
    return rig("manta", "Manta", [-70, -50, 140, 52], {}, node("root", (0, 0), shapes=body + stripes + fold))


def taza():
    """Taza de té humeante. Origen: base."""
    sh = [S("M-18,-30 L18,-30 L14,0 L-14,0 Z", "#e8dcc4", "#6a5a3a", 2.5), shade("M6,-30 L18,-30 L14,0 L4,0 Z"),
          S("M16,-24 C32,-24 32,-6 15,-8", None, "#6a5a3a", 3),
          S(ell(0, -30, 18, 5), "#a8c85a", "#6a5a3a", 2)]
    steam_ = [S("M-6,-40 C-12,-50 0,-54 -4,-66", None, "#ffffff", 3, 0.7), S("M6,-40 C0,-50 12,-54 8,-66", None, "#ffffff", 3, 0.7)]
    return rig("taza", "Taza de té", [-24, -72, 52, 74], {}, node("root", (0, 0), shapes=sh + steam_))


def cuenco():
    """Cuenco de sopa caliente. Origen: base."""
    sh = [S("M-26,-26 L26,-26 L18,0 L-18,0 Z", "#c98a3a", "#5a3a14", 2.5), shade("M12,-26 L26,-26 L18,0 L8,0 Z"),
          S(ell(0, -26, 26, 6), "#e8a43a", "#5a3a14", 2),
          S("M-8,-34 C-14,-46 -2,-50 -6,-62", None, "#ffffff", 3, 0.7), S("M8,-34 C2,-46 14,-50 10,-62", None, "#ffffff", 3, 0.7)]
    return rig("cuenco", "Cuenco de sopa", [-30, -68, 60, 70], {}, node("root", (0, 0), shapes=sh))


def regadera():
    """Regadera de hojalata. Origen: base."""
    sh = [S("M-24,-40 L16,-40 L20,0 L-28,0 Z", "#7a9ac0", "#2a3a5a", 2.5), shade("M6,-40 L16,-40 L20,0 L8,0 Z"),
          S("M16,-30 L46,-56 L52,-50 L22,-20 Z", "#7a9ac0", "#2a3a5a", 2.5), S(ell(50, -53, 8, 4), "#5a7aa0", "#2a3a5a", 2),
          S("M-24,-34 C-46,-44 -44,-12 -28,-12", None, "#2a3a5a", 4)]
    return rig("regadera", "Regadera", [-52, -62, 108, 64], {}, node("root", (0, 0), shapes=sh))


def cinta():
    """Cinta azul de premio (roseta con dos colas). Origen: base."""
    sh = [S("M-8,-12 L-20,18 L-10,14 L-4,22 L2,-8 Z", "#2f5ac0", "#1a2a6a", 2),
          S("M8,-12 L20,18 L10,14 L4,22 L-2,-8 Z", "#3f6ad0", "#1a2a6a", 2),
          S(ell(0, -22, 18, 18), "#3f6ad0", "#1a2a6a", 2.5), S(ell(0, -22, 10, 10), "#8fb0f0", None, 0),
          S(ell(0, -22, 4, 4), "#f4c542", None, 0)]
    return rig("cinta", "Cinta azul", [-24, -44, 48, 70], {}, node("root", (0, 0), shapes=[S(ell(0, 3, 14, 3), "#000000", None, 0, 0.0)] + sh))


def girasol_seco():
    """Girasol de otoño: el cuello se dobla y la cabeza, pesada de semillas, cuelga. Origen: base."""
    cx, cy = 56, -104
    petals = []
    for k in range(12):
        a = 2 * math.pi * k / 12
        petals.append(S(ell(cx + 27 * math.cos(a), cy + 24 * math.sin(a), 13, 8), "#c89a30" if k % 2 == 0 else "#d8b050", "#8a6a18", 1.5))
    seeds = [S(ell(cx + 9 * math.cos(a) * r_, cy + 8 * math.sin(a) * r_, 2.4, 2.4), "#f4f0e0", "#3a2412", 0.8)
             for a, r_ in [(0.6, 1), (1.9, 1.5), (3.1, 1), (4.3, 1.6), (5.4, 1), (0, 0.3), (2.5, 2), (4.9, 2), (1.2, 2.2), (3.7, 2.2)]]
    head = node("head", (0, -130), shapes=[S("M0,-150 C4,-168 40,-170 52,-134", None, "#8a7a3a", 9)] + petals
                + [S(ell(cx, cy, 21, 20), "#4a2c16", "#2a180c", 2)] + seeds)
    leaves = [S("M0,-60 C-34,-82 -46,-60 -40,-44 C-26,-48 -10,-52 0,-60 Z", "#a8914a", "#5a4a1c", 2),
              S("M0,-96 C34,-118 46,-96 40,-80 C26,-84 10,-88 0,-96 Z", "#a8914a", "#5a4a1c", 2)]
    stem = node("stem", (0, 0), shapes=[S(rrect(-5, -152, 10, 152, 4), "#8a7a3a")] + leaves, post=[head])
    root = node("root", (0, 0), post=[stem], shapes=[S(ell(0, 2, 22, 6), "#5a3a22", None, 0, 0.7)])
    return rig("girasol_seco", "Girasol seco", [-70, -210, 150, 220], {}, root)


def roble():
    """Roble viejo con un hueco en el tronco y una rama larga a la izquierda de la que cuelga la linterna.
    La punta de la rama está en (-95, -245). Origen: pie del tronco."""
    trunk = [S("M-34,0 C-30,-60 -26,-150 -22,-250 L24,-250 C30,-150 32,-60 38,0 Z", "#6a4426", "#2a180c", 3),
             shade("M10,-250 L24,-250 C30,-150 32,-60 38,0 L18,0 C22,-80 16,-170 10,-250 Z"),
             S("M-34,0 C-50,6 -60,8 -64,12 L-30,-6 Z", "#6a4426", "#2a180c", 2.5), S("M38,0 C54,6 64,8 70,12 L34,-6 Z", "#6a4426", "#2a180c", 2.5)]
    hollow = [S(ell(4, -84, 22, 34), "#1a0f08", "#120a06", 2.5), S(ell(4, -64, 17, 18), "#000000", None, 0, 0.5)]
    branch = [S("M-18,-236 C-50,-252 -80,-248 -102,-240 L-100,-250 C-78,-260 -44,-264 -16,-250 Z", "#6a4426", "#2a180c", 2.5),
              S(ell(-98, -244, 5, 5), "#4a2c16", "#2a180c", 1.5)]
    crown = [S(ell(0, -306, 118, 60), "#2f8f66", "#16463a", 3), S(ell(-58, -286, 50, 36), "#2a7d5b", "#16463a", 3),
             S(ell(78, -280, 62, 40), "#2a7d5b", "#16463a", 3), S(ell(30, -326, 56, 34), "#38a074", None, 0, 0.8)]
    return rig("roble", "Roble viejo", [-170, -370, 340, 384], {}, node("root", (0, 0), shapes=trunk + hollow + crown + branch))


def puerta_cabana():
    """Frente de una cabaña de piedra con una puerta de madera entreabierta: por la rendija (un hueco sin pintar,
    de x = 6 a 24 desde el centro) se ve lo que haya detrás, p. ej. el que vive dentro. Origen: base, centrado."""
    stone = "#9a9aa8"
    wall = [S("M-110,0 L-110,-225 L-48,-225 L-48,0 Z", stone, "#4a4a5a", 2.5), S("M42,0 L42,-225 L110,-225 L110,0 Z", stone, "#4a4a5a", 2.5),
            S("M-48,-225 L42,-225 L42,-205 L-48,-205 Z", stone, "#4a4a5a", 2.5)]
    for y in range(-215, 0, 28):
        wall.append(S(f"M-110,{y} L-48,{y}", None, "#6a6a7a", 1.5))
        wall.append(S(f"M42,{y} L110,{y}", None, "#6a6a7a", 1.5))
    door_l = [S("M-48,0 L-48,-205 L6,-205 L6,0 Z", "#7a4a2a", "#2a180c", 2.5)] + \
             [S(f"M{x},0 L{x},-205", None, "#4a2a14", 1.5) for x in (-30, -12)] + \
             [S(ell(-4, -95, 5, 5), "#f4c542", "#5a4410", 1.5)]
    door_r = [S("M24,0 L24,-205 L42,-205 L42,0 Z", "#7a4a2a", "#2a180c", 2.5), S("M33,0 L33,-205", None, "#4a2a14", 1.5)]
    roof = [S("M-120,-225 L0,-290 L120,-225 Z", "#a8453f", "#4a1a2a", 3), shade("M0,-290 L120,-225 L6,-225 Z")]
    return rig("puerta_cabana", "Puerta de cabaña", [-124, -292, 248, 294], {}, node("root", (0, 0), shapes=wall + door_l + door_r + roof))


# -------------------------------------------------------------------- mesa
def mesa():
    """Mesa larga de madera con cuencos de sopa, cucharas y pan: para la fiesta de la plaza. Origen: base."""
    top = [S(rrect(-130, -64, 260, 14, 4), "#a8703c", "#4a2c14", 2.5), S(rrect(-130, -54, 260, 6, 2), "#000000", None, 0, 0.16)]
    legs = [S(rrect(x, -50, 10, 50, 2), "#8a5a2b", "#3a2412", 2) for x in (-118, 108)]
    legs += [S(rrect(-40, -46, 6, 44, 2), "#7a4a1b", None, 0, 0.5), S(rrect(34, -46, 6, 44, 2), "#7a4a1b", None, 0, 0.5)]
    things = []
    for i, x in enumerate((-96, -54, -12, 30, 72, 110)):
        things += [S("M%d,-66 L%d,-66 L%d,-80 L%d,-80 Z" % (x - 14, x + 14, x + 10, x - 10), "#e8dcc4", "#6a5a3a", 2),
                   S(ell(x, -80, 10, 3), "#e8a43a" if i % 2 else "#d9784a", None, 0)]
    things += [S(ell(-72, -72, 12, 6), "#d9a050", "#7a5a22", 1.5)]
    return rig("mesa", "Mesa de la fiesta", [-135, -90, 270, 92], {}, node("root", (0, 0), shapes=legs + top + things))


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
    return [campana(), campana_rota(), linterna(), linterna_apagada(), olla(), pan(), trozos_de_pan(), buho(), cabrita(), bolsa(), cometa(), girasol(), semillas(), semillas_dos(), mesa(), manta(), taza(), cuenco(), regadera(), cinta(), girasol_seco(), roble(), puerta_cabana(), maceta(), maceta_brote(), piedras(), hierba(), pedernal(), vela(), saco(), cofre()]
