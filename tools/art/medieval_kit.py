#!/usr/bin/env python3
"""Kit procedural de personajes (pack medieval).

Un personaje es DATOS: un esqueleto (huesos con pivote), piezas vectoriales y una
paleta. Este script construye los personajes, los exporta como JSON (el formato que
leerá la app) y dibuja una hoja de previsualización en SVG en distintas poses.

Todo el arte nace del código: sin herramientas de pago ni imágenes de terceros.

Uso:
    python3 tools/art/medieval_kit.py            # escribe art/medieval/
"""
import json
import math
from pathlib import Path

import anim

OUT = Path(__file__).resolve().parent.parent.parent / "art" / "medieval"
DARK = "#1b1230"  # tinta de contornos (no negro puro: más amable)


# ---------------------------------------------------------------- color
def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a, b, t):
    ra, rb = _rgb(a), _rgb(b)
    return "#%02x%02x%02x" % tuple(round(ra[i] * (1 - t) + rb[i] * t) for i in range(3))


# ------------------------------------------------------------- geometría
def n(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (f"M{n(x + r)},{n(y)} L{n(x + w - r)},{n(y)} Q{n(x + w)},{n(y)} {n(x + w)},{n(y + r)} "
            f"L{n(x + w)},{n(y + h - r)} Q{n(x + w)},{n(y + h)} {n(x + w - r)},{n(y + h)} "
            f"L{n(x + r)},{n(y + h)} Q{n(x)},{n(y + h)} {n(x)},{n(y + h - r)} "
            f"L{n(x)},{n(y + r)} Q{n(x)},{n(y)} {n(x + r)},{n(y)} Z")


def ell(cx, cy, rx, ry):
    return (f"M{n(cx - rx)},{n(cy)} A{n(rx)},{n(ry)} 0 1 0 {n(cx + rx)},{n(cy)} "
            f"A{n(rx)},{n(ry)} 0 1 0 {n(cx - rx)},{n(cy)} Z")


def poly(pts):
    return "M" + " L".join(f"{n(x)},{n(y)}" for x, y in pts) + " Z"


def crescent(cx, cy, rx, ry, k=0.5):
    """Media luna a la derecha de una elipse (para sombrear)."""
    return (f"M{n(cx)},{n(cy - ry)} A{n(rx)},{n(ry)} 0 0 1 {n(cx)},{n(cy + ry)} "
            f"A{n(rx * k)},{n(ry)} 0 0 0 {n(cx)},{n(cy - ry)} Z")


def star(cx, cy, r1, r2, k=5):
    pts = []
    for i in range(k * 2):
        r = r1 if i % 2 == 0 else r2
        a = -math.pi / 2 + i * math.pi / k
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


# ---------------------------------------------------------------- formas
def S(d, fill, stroke="auto", sw=3, op=1.0):
    """Una forma: `fill`/`stroke` son $token de paleta, #hex o None."""
    return {"d": d, "fill": fill, "stroke": stroke, "sw": sw, "op": op}


def shade(d):
    """Sombra suave (sin contorno) para dar volumen."""
    return S(d, DARK, None, 0, 0.16)


def shine(d):
    return S(d, "#ffffff", None, 0, 0.28)


def node(id_, pivot, shapes=(), pre=(), post=()):
    return {"id": id_, "pivot": list(pivot), "pre": list(pre), "shapes": list(shapes), "post": list(post)}


# ------------------------------------------------------------------ cabeza
def head_shapes(s):
    sh = []
    hat = s.get("hat")
    # --- detrás de la cara
    if hat == "hood":
        sh.append(S(ell(0, -194, 54, 52), "$cloak"))
    if s.get("hair") == "pigtails":
        for sx in (-1, 1):
            sh.append(S(ell(sx * 53, -176, 13, 17), "$hair"))
            sh.append(S(ell(sx * 53, -158, 8, 9), "$hair"))
            sh.append(S(ell(sx * 51, -190, 6, 5), "$accent", None))
    if s.get("hair") == "braid":
        for cy, r in [(-168, 9), (-148, 8.5), (-129, 8), (-112, 7)]:
            sh.append(S(ell(-47, cy, r, r), "$hair"))
        sh.append(S(ell(-47, -104, 5, 5), "$accent", None))
    # --- cara
    sh.append(S(ell(-44, -190, 6, 9), "$skin"))
    sh.append(S(ell(44, -190, 6, 9), "$skin"))
    sh.append(S(ell(0, -192, 44, 41), "$skin"))
    sh.append(shade(crescent(0, -192, 44, 41, 0.62)))
    sh.append(S(ell(-27, -176, 7.5, 4.8), "#ff7a8a", None, 0, 0.45))  # mejillas
    sh.append(S(ell(27, -176, 7.5, 4.8), "#ff7a8a", None, 0, 0.45))
    sh.append(S(ell(0, -180, 3.6, 3), mix(s["palette"]["skin"], "#a0522d", 0.35), None, 0))
    # --- pelo
    if s.get("hair") in ("short", "braid", "pigtails"):
        sh.append(S("M-45,-188 C-50,-238 50,-238 45,-188 C38,-208 22,-215 0,-213 C-22,-215 -38,-208 -45,-188 Z", "$hair"))
    # --- antifaz del bandido
    if hat == "hood":
        sh.append(S(rrect(-43, -202, 86, 26, 11), "$mask"))
    # --- cejas (los ojos son un hueso aparte: `eyes_shapes`, para poder parpadear)
    brow = s.get("brows", "kind")
    bs = {"kind": ("M-24,-203 Q-16,-209 -8,-204", "M8,-204 Q16,-209 24,-203"),
          "grumpy": ("M-25,-209 L-8,-200", "M25,-209 L8,-200"),
          "determined": ("M-24,-204 L-8,-203", "M8,-203 L24,-204"),
          "sleepy": ("M-24,-202 Q-16,-199 -8,-202", "M8,-202 Q16,-199 24,-202"),
          "worried": ("M-25,-198 Q-16,-206 -8,-206", "M8,-206 Q16,-206 25,-198")}[brow]
    if hat != "helmet":
        for d in bs:
            sh.append(S(d, None, mix(s["palette"].get("hair", "#4a3426"), DARK, 0.2) if not hat == "hood" else "#f3e6c8", 3.4))
    # --- boca
    mouth = s.get("mouth", "smile")
    md = {"smile": "M-10,-168 Q0,-158 10,-168", "flat": "M-9,-166 L9,-166",
          "smirk": "M-10,-165 Q2,-162 10,-170", "frown": "M-10,-162 Q0,-170 10,-162",
          "open": None}[mouth]
    if md:
        sh.append(S(md, None, DARK, 3.2))
    else:
        sh.append(S("M-9,-170 Q0,-152 9,-170 Z", "#7a1f2e", DARK, 2.5))
    # --- barba / bigote
    if s.get("beard"):
        sh.append(S("M-43,-176 C-52,-118 52,-118 43,-176 C36,-166 20,-170 0,-160 C-20,-170 -36,-166 -43,-176 Z", "$beard"))
        sh.append(S(ell(-11, -171, 12, 6), "$beard"))
        sh.append(S(ell(11, -171, 12, 6), "$beard"))
        sh.append(shade("M10,-150 C30,-130 36,-150 43,-176 C36,-166 24,-166 14,-164 Z"))
    if s.get("goatee"):
        sh.append(S("M-9,-160 L9,-160 L0,-136 Z", "$beard"))
        sh.append(S("M-14,-170 Q-8,-175 -2,-170 Q-8,-166 -14,-170 Z", "$beard"))
        sh.append(S("M14,-170 Q8,-175 2,-170 Q8,-166 14,-170 Z", "$beard"))
    # --- sombrero
    if hat == "helmet":
        sh.append(S("M-47,-203 C-52,-256 52,-256 47,-203 Z", "$metal"))
        sh.append(shine("M-36,-228 C-34,-240 -20,-247 -8,-246 C-20,-240 -28,-234 -30,-222 Z"))
        sh.append(shade("M10,-250 C40,-244 50,-225 47,-203 L20,-203 C26,-220 22,-238 10,-250 Z"))
        sh.append(S(rrect(-50, -213, 100, 12, 6), mix(s["palette"]["metal"], DARK, 0.2)))
        sh.append(S(rrect(-4.5, -204, 9, 30, 4), "$metal"))
        sh.append(S("M-4,-246 C14,-290 58,-272 54,-232 C42,-258 20,-258 4,-244 Z", "$plume"))
    elif hat == "crown":
        sh.append(S(poly([(-28, -246), (-28, -274), (-14, -256), (0, -280), (14, -256), (28, -274), (28, -246)]), "$gold"))
        sh.append(S(rrect(-29, -250, 58, 17, 5), "$gold"))
        for gx, c in [(-16, "#e2405a"), (0, "#3fa7ff"), (16, "#e2405a")]:
            sh.append(S(ell(gx, -241.5, 4.2, 4.2), c, None))
        sh.append(shine("M-26,-247 L-26,-262 L-18,-254 Z"))
    elif hat == "wizard":
        sh.append(S(ell(0, -228, 66, 14), "$hat"))
        sh.append(S("M-47,-229 C-40,-270 -22,-302 8,-336 C16,-302 36,-266 47,-229 Z", "$hat"))
        sh.append(shade("M8,-336 C16,-302 36,-266 47,-229 L18,-229 C22,-262 18,-302 8,-336 Z"))
        sh.append(S(rrect(-47, -243, 94, 13, 5), "$accent"))
        for x, y, r in [(-12, -272, 7), (14, -296, 5), (10, -258, 4.5)]:
            sh.append(S(star(x, y, r, r * 0.45), "$gold", None))
    elif hat == "hood":
        sh.append(S("M-46,-203 C-34,-244 34,-244 46,-203 C32,-222 -32,-222 -46,-203 Z", "$cloak"))
    elif hat == "archer":
        sh.append(S("M-47,-202 C-52,-252 50,-258 47,-206 C30,-218 -30,-218 -47,-202 Z", "$hat"))
        sh.append(S("M30,-236 C58,-266 82,-258 90,-274 C76,-244 58,-232 38,-222 Z", "$plume"))
        sh.append(S("M32,-232 C56,-250 70,-250 84,-266", None, mix(s["palette"]["plume"], DARK, 0.5), 1.6))
    elif hat == "cap":
        sh.append(S("M-47,-204 C-52,-248 48,-250 47,-204 C30,-212 -30,-212 -47,-204 Z", "$hat"))
        sh.append(S(rrect(-50, -209, 100, 10, 5), mix(s["palette"]["hat"], DARK, 0.25)))
        sh.append(S(ell(0, -241, 4.5, 4.5), mix(s["palette"]["hat"], DARK, 0.25), None))
    elif hat == "baker":
        sh.append(S(rrect(-36, -230, 72, 28, 8), "$hat"))
        sh.append(S(ell(-18, -244, 24, 20), "$hat"))
        sh.append(S(ell(18, -244, 24, 20), "$hat"))
        sh.append(S(ell(0, -252, 26, 20), "$hat"))
        sh.append(shade("M10,-262 C40,-256 44,-232 36,-206 L16,-206 C22,-228 20,-248 10,-262 Z"))
    elif hat == "kerchief":
        sh.append(S("M-47,-200 C-54,-252 52,-252 47,-200 C36,-214 -36,-214 -47,-200 Z", "$hat"))
        sh.append(S(ell(50, -208, 11, 8), "$hat"))
        sh.append(S(ell(60, -198, 8, 11), "$hat"))
        for dx in (-26, -8, 12, 30):
            sh.append(S(ell(dx, -226, 3, 3), "$accent", None))
    elif hat == "straw":
        sh.append(S(ell(0, -214, 80, 14), "$hat"))
        sh.append(S("M-37,-216 C-36,-256 36,-256 37,-216 Z", "$hat"))
        sh.append(S(rrect(-37, -228, 74, 10, 3), "$accent"))
        sh.append(shade("M12,-253 C32,-246 38,-230 37,-216 L18,-216 C24,-230 22,-244 12,-253 Z"))
    elif hat == "beret":
        sh.append(S("M-52,-214 C-46,-254 40,-262 60,-234 C58,-214 -30,-204 -52,-214 Z", "$hat"))
        sh.append(S("M54,-238 C86,-266 104,-252 114,-228 C98,-246 82,-242 56,-228 Z", "$gold"))
    return sh


def eyes_shapes(s):
    sh = []
    if s.get("hat") == "hood":
        for sx in (-16, 16):
            sh.append(S(ell(sx, -189, 7.5, 6.5), "#fff6e0", None))
            sh.append(S(ell(sx, -189, 3.6, 4.6), DARK, None))
            sh.append(S(ell(sx - 1, -191, 1.3, 1.3), "#ffffff", None))
    else:
        for sx in (-16, 16):
            sh.append(S(ell(sx, -188, 5.5, 7.5), DARK, None))
            sh.append(S(ell(sx - 2, -191, 2.1, 2.1), "#ffffff", None))
    return sh


# ------------------------------------------------------------------ cuerpo
def torso_shapes(s):
    k = s.get("outfit", "tunic")
    sh = []
    if k == "tunic":
        sh += [S(rrect(-36, -150, 72, 84, 22), "$primary"), shade(rrect(12, -148, 22, 80, 14)),
               S("M-14,-150 L0,-132 L14,-150 Z", "$secondary"),
               S(rrect(-36, -104, 72, 11, 3), "$belt"), S(rrect(-7, -107, 14, 17, 3), "$gold")]
    elif k == "armor":
        sh += [S(rrect(-36, -150, 72, 84, 22), "$metal"), shade(rrect(12, -148, 22, 80, 14)),
               S("M-24,-150 L24,-150 L31,-80 Q0,-64 -31,-80 Z", "$primary"),
               S("M-3,-136 A15,15 0 1 0 12,-110 A12,12 0 1 1 -3,-136 Z", "$gold", None),
               S(rrect(-36, -104, 72, 11, 3), "$belt"), S(rrect(-7, -107, 14, 17, 3), "$gold")]
    elif k == "robe":
        sh += [S("M-37,-150 L37,-150 C46,-110 58,-50 66,-8 Q0,8 -66,-8 C-58,-50 -46,-110 -37,-150 Z", "$primary"),
               shade("M14,-148 L37,-150 C46,-110 58,-50 66,-8 Q40,2 26,2 C30,-50 24,-110 14,-148 Z"),
               S("M-66,-12 Q0,4 66,-12 L64,-2 Q0,14 -64,-2 Z", "$secondary"),
               S("M-14,-150 L0,-128 L14,-150 Z", "$secondary"),
               S(rrect(-37, -102, 74, 8, 4), "$gold")]
        for x, y, r in [(-22, -60, 6), (18, -40, 5), (-8, -26, 4.5), (28, -80, 4)]:
            sh.append(S(star(x, y, r, r * 0.45), "$gold", None))
    elif k == "royal":
        sh += [S(rrect(-44, -150, 88, 86, 24), "$primary"), shade(rrect(18, -148, 24, 82, 14)),
               S(rrect(-44, -104, 88, 12, 4), "$gold"), S(rrect(-8, -107, 16, 18, 4), "$gold"),
               S(ell(0, -148, 36, 12), "#fff3e0")]
        for x, y in [(-20, -148), (-6, -144), (8, -148), (22, -144), (-28, -142)]:
            sh.append(S(ell(x, y, 2.6, 4), DARK, None))
    elif k == "noble":
        sh += [S(rrect(-38, -150, 76, 92, 18), "$primary"), shade(rrect(14, -148, 22, 88, 12))]
        for y in (-128, -110, -92):
            sh.append(S(ell(0, y, 4.5, 4.5), "$gold"))
        sh += [S(rrect(-38, -100, 76, 9, 3), "$belt"), S(ell(0, -150, 30, 10), "#f3ead6"),
               S(ell(30, -80, 11, 13), "$sack"), S(rrect(26, -96, 8, 6, 2), "$gold")]
    elif k == "archer":
        sh += [S(rrect(-36, -150, 72, 84, 22), "$primary"), shade(rrect(12, -148, 22, 80, 14)),
               S("M-14,-150 L0,-134 L14,-150 Z", "$secondary"),
               S(rrect(-36, -104, 72, 11, 3), "$belt"), S(rrect(-6, -107, 12, 17, 3), "$gold"),
               S("M-36,-96 L36,-96 L44,-68 Q0,-56 -44,-68 Z", "$primary")]
    elif k == "bandit":
        sh += [S(rrect(-36, -150, 72, 84, 22), "$primary"), shade(rrect(12, -148, 22, 80, 14)),
               S(rrect(-36, -104, 72, 11, 3), "$belt"), S(rrect(-6, -107, 12, 17, 3), "$secondary")]
    if s.get("apron"):
        sh += [S("M-26,-136 L26,-136 L34,-64 Q0,-54 -34,-64 Z", "$apron"),
               S(poly([(-26, -136), (-18, -150), (-12, -136)]), "$apron"),
               S(poly([(26, -136), (18, -150), (12, -136)]), "$apron"),
               shade("M8,-134 L26,-136 L34,-64 Q18,-58 12,-60 Z"),
               S(rrect(-14, -98, 28, 20, 4), mix(s["palette"]["apron"], DARK, 0.12))]
    return sh


def back_shapes(s):
    """Cosas detrás del torso: capa, carcaj."""
    sh = []
    if s.get("cape"):
        sh.append(S("M-42,-152 L42,-152 C64,-112 74,-52 82,-12 Q0,10 -82,-12 C-74,-52 -64,-112 -42,-152 Z", "$cape"))
        sh.append(S("M-66,-20 Q0,0 66,-20 L68,-12 Q0,10 -68,-12 Z", "#fff3e0"))
        sh.append(shade("M20,-150 L42,-152 C64,-112 74,-52 82,-12 Q50,0 34,0 C40,-50 32,-110 20,-150 Z"))
    if s.get("cloak_back"):
        sh.append(S("M-40,-150 L40,-150 C54,-110 62,-50 68,-16 Q0,2 -68,-16 C-62,-50 -54,-110 -40,-150 Z", "$cloak"))
    if s.get("quiver"):
        sh.append(S(poly([(20, -176), (38, -170), (50, -100), (32, -96)]), "$belt"))
        for dx in (0, 6, 12):
            sh.append(S(poly([(22 + dx, -176), (26 + dx, -177), (27 + dx, -194), (23 + dx, -194)]), "$plume"))
    return sh


def leg_shapes(cx, s):
    pants = "$primary" if s.get("outfit") == "robe" else "$pants"
    return [S(rrect(cx - 11, -82, 22, 62, 10), pants), shade(rrect(cx + 2, -80, 9, 58, 5)),
            S(rrect(cx - 14, -26, 28, 26, 10), "$boots"), shine(rrect(cx - 10, -22, 6, 10, 3))]


def arm_shapes(side, s):
    sx = 36 * side  # +1 derecha del espectador
    sleeve = "$metal" if s.get("outfit") == "armor" else "$primary"
    sh = [S(rrect(sx - 10, -148, 20, 54, 10), sleeve), shade(rrect(sx + 2, -146, 8, 50, 4))]
    if s.get("outfit") == "armor":
        sh.append(S(ell(sx, -144, 14, 11), "$metal"))
        sh.append(shine(ell(sx - 4, -148, 5, 3)))
    sh.append(S(ell(sx, -92, 10, 10), "$skin"))
    it = []
    item = s.get("hold_r") if side > 0 else s.get("hold_l")
    sh, arm_only = it, sh
    if item == "sword":
        sh += [S(rrect(sx - 4.5, -196, 9, 100, 4), "#e8eef5"), shine(rrect(sx - 2, -190, 2.5, 80, 1)),
               S(rrect(sx - 16, -104, 32, 8, 4), "$gold"), S(ell(sx, -86, 5, 5), "$gold")]
        sh.append(S(ell(sx, -94, 10, 10), "$skin"))
    elif item == "staff":
        sh += [S(rrect(sx - 4, -258, 8, 262, 4), "$wood"), S(ell(sx, -270, 26, 26), "$glow", None, 0, 0.18),
               S(ell(sx, -270, 19, 19), "$glow", None, 0, 0.30), S(ell(sx, -270, 13, 13), "$glow"),
               S(ell(sx - 4, -274, 4, 4), "#ffffff", None, 0, 0.8)]
        sh.append(S(ell(sx, -94, 10, 10), "$skin"))
    elif item == "shield":
        sh += [S("M-76,-136 L-28,-136 L-28,-100 Q-28,-60 -52,-48 Q-76,-60 -76,-100 Z", "$metal"),
               S("M-70,-130 L-34,-130 L-34,-101 Q-34,-68 -52,-57 Q-70,-68 -70,-101 Z", "$shield", None),
               S("M-54,-118 A11,11 0 1 0 -42,-98 A8.5,8.5 0 1 1 -54,-118 Z", "$gold", None),
               shade("M-52,-130 L-34,-130 L-34,-101 Q-34,-68 -52,-57 Z")]
    elif item == "bow":
        sh += [S("M-36,-176 Q-78,-104 -36,-30", None, "$wood", 6),
               S("M-36,-176 L-36,-30", None, "#f3e6c8", 1.6)]
        sh.append(S(ell(sx, -94, 10, 10), "$skin"))
    elif item == "sack":
        sh += [S(ell(sx + 8, -66, 20, 23), "$sack"), S("M%s,-90 L%s,-86 L%s,-88 Z" % (n(sx - 4), n(sx + 4), n(sx + 12)), "$sack"),
               S(rrect(sx - 2, -92, 20, 6, 3), "$belt"), shade(ell(sx + 14, -62, 10, 16))]
        sh.append(S(ell(sx, -94, 10, 10), "$skin"))
    return arm_only, it


def build(spec):
    s = spec
    armL, itemL = arm_shapes(-1, s)
    armR, itemR = arm_shapes(+1, s)
    torso = node("torso", (0, -75),
                 pre=back_shapes(s) and [node("back", (0, -75), shapes=back_shapes(s))] or [],
                 shapes=torso_shapes(s),
                 post=[node("armL", (-36, -140), shapes=armL, post=[node("itemL", (-36, -92), shapes=itemL)]),
                       node("head", (0, -150), shapes=head_shapes(s),
                            post=[node("eyes", (0, -188), shapes=eyes_shapes(s))]),
                       node("armR", (36, -140), shapes=armR, post=[node("itemR", (36, -92), shapes=itemR)])])
    root = node("root", (0, -75),
                pre=[node("legL", (-14, -78), shapes=leg_shapes(-14, s)),
                     node("legR", (14, -78), shapes=leg_shapes(14, s))],
                post=[torso])
    return {"format": "caldero-rig", "version": 1, "id": s["id"], "name": s["name"], "rig": "humanoid",
            "viewBox": [-130, -350, 260, 370], "bodyScale": s.get("scale", 1.0),
            "rest": s.get("rest", REST), "itemUpright": s.get("hold_r") in ("sword", "staff"),
            "itemTilt": s.get("item_tilt", 0), "palette": s["palette"], "root": root}


REST = {"armL": 9, "armR": -9}


# ------------------------------------------------------------- render SVG
def color(rig, v):
    if v is None:
        return None
    if v.startswith("$"):
        return rig["palette"][v[1:]]
    if v.startswith("@"):  # degradado de escena
        return f"url(#{v[1:]})"
    return v


def svg_shape(rig, sh):
    fill = color(rig, sh["fill"])
    if sh["stroke"] == "auto":
        stroke = mix(fill, DARK, 0.62) if fill and fill.startswith("#") else None
    else:
        stroke = color(rig, sh["stroke"])
    a = [f'd="{sh["d"]}"', f'fill="{fill or "none"}"']
    if stroke and sh["sw"]:
        a += [f'stroke="{stroke}"', f'stroke-width="{n(sh["sw"])}"', 'stroke-linejoin="round"', 'stroke-linecap="round"']
    if sh["op"] < 1:
        a.append(f'opacity="{sh["op"]}"')
    return "<path " + " ".join(a) + "/>"


def node_transform(nd, p):
    """Transformación SVG de un hueso: traslación, rotación sobre su pivote y escala sobre su pivote."""
    i, (px, py) = nd["id"], nd["pivot"]
    dx, dy = p.get(i + ".dx", 0), p.get(i + ".dy", 0)
    ang, sx, sy = p.get(i, 0), p.get(i + ".sx", 1), p.get(i + ".sy", 1)
    parts = []
    if dx or dy:
        parts.append(f"translate({n(dx)} {n(dy)})")
    if ang:
        parts.append(f"rotate({n(ang)} {n(px)} {n(py)})")
    if sx != 1 or sy != 1:
        parts.append(f"translate({n(px)} {n(py)}) scale({n(sx)} {n(sy)}) translate({n(-px)} {n(-py)})")
    return f' transform="{" ".join(parts)}"' if parts else ""


def svg_node(rig, nd, p):
    out = [f'<g id="{nd["id"]}"{node_transform(nd, p)}>']
    out += [svg_node(rig, c, p) for c in nd["pre"]]
    out += [svg_shape(rig, sh) for sh in nd["shapes"]]
    out += [svg_node(rig, c, p) for c in nd["post"]]
    out.append("</g>")
    return "".join(out)


def svg_character(rig, p):
    sc = rig["bodyScale"]
    body = svg_node(rig, rig["root"], p)
    return f'<g transform="scale({sc} 1)">{body}</g>' if sc != 1 else body


# ------------------------------------------------------------- personajes
PIJAMA = {"aldo": {"primary": "#9ab8f0", "secondary": "#ffffff", "pants": "#9ab8f0", "boots": "#c9a06a"},
          "mara": {"primary": "#f0a8c8", "secondary": "#ffffff", "pants": "#f0a8c8", "boots": "#c9a06a"}}


def load_cast():
    """Los personajes del pack y sus variantes de actuación: `<id>_miedo` (ceño preocupado y boca hacia abajo, para
    miedo, frío, tristeza o culpa) y, para los protagonistas, `<id>_pijama` (sin armadura ni armas, para dormir)."""
    doc = json.loads((OUT / "specs" / "characters.json").read_text(encoding="utf-8"))
    base = doc["characters"]
    out = list(base)
    for c in base:
        if c.get("variant_of"):
            continue
        v = {**c, "id": f'{c["id"]}_miedo', "name": f'{c["name"]} (con miedo)', "mouth": "frown", "brows": "worried", "variant_of": c["id"]}
        if c["id"] == "aldo":  # con miedo no esgrime la espada ni el escudo (le taparían la cara al cruzar los brazos)
            for k in ("hold_r", "hold_l", "item_tilt"):
                v.pop(k, None)
            v["rest"] = {"armL": 9, "armR": -9}
        out.append(v)
    for c in base:
        if c["id"] in PIJAMA:
            v = {k: val for k, val in c.items() if k not in ("hat", "hold_r", "hold_l", "item_tilt", "rest", "quiver", "outfit")}
            v.update(id=f'{c["id"]}_pijama', name=f'{c["name"]} (en pijama)', outfit="tunic", brows="sleepy", mouth="smile",
                     variant_of=c["id"], palette={**c["palette"], **PIJAMA[c["id"]]})
            out.append(v)
    return out


# ------------------------------------------------------------------ hoja
def sheet(rigs):
    """Hoja de previsualización. Las poses salen de la biblioteca de clips (la misma que usará la app)."""
    clips = anim.load_clips("humanoid")
    by = {r["id"]: r for r in rigs}
    cw, ch, cols = 236, 330, 6
    humans = [r for r in rigs if r.get("rig") == "humanoid" and "_" not in r["id"]]
    rows = [[(r, "idle", 0.0) for r in humans[i:i + cols]] for i in range(0, len(humans), cols)]
    rows += [
        [(by["aldo"], c, tt) for c, tt in (("idle", 0), ("walk", 0.1), ("run", 0.12), ("wave", 0.9), ("cheer", 0.6), ("jump", 0.5))],
        [(by["mara"], "walk", 0.1), (by["zafiro"], "wave", 0.9), (by["bonifacio"], "bow", 1.2),
         (by["codicio"], "surprised", 0.6), (by["sombra"], "scared", 0.06), (by["mara"], "cheer", 0.6)],
    ]
    W, H = cw * cols, ch * len(rows) + 10
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
             'font-family="Helvetica, Arial, sans-serif">',
             '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#221a4a"/>'
             '<stop offset="1" stop-color="#0d0a1c"/></linearGradient>'
             '<radialGradient id="halo"><stop offset="0" stop-color="#ffd98a" stop-opacity="0.22"/>'
             '<stop offset="1" stop-color="#ffd98a" stop-opacity="0"/></radialGradient></defs>',
             f'<rect width="{W}" height="{H}" fill="url(#bg)"/>']
    for ri, row in enumerate(rows):
        for ci, (rig, pn, tt) in enumerate(row):
            ox, oy = ci * cw, ri * ch
            vb = rig["viewBox"]
            k = (ch - 60) / vb[3]
            tx = ox + cw / 2
            ty = oy + 14 + (-vb[1]) * k
            parts.append(f'<ellipse cx="{tx}" cy="{ty - 6}" rx="{110}" ry="{120}" fill="url(#halo)"/>')
            parts.append(f'<ellipse cx="{tx}" cy="{ty + 3}" rx="{62 * k * rig["bodyScale"] + 10}" ry="7" fill="#000" opacity="0.4"/>')
            parts.append(f'<g transform="translate({tx} {ty}) scale({k})">{svg_character(rig, anim.sample_pose(rig, clips[pn], tt))}</g>')
            label = rig["name"] if ri == 0 else f'{rig["name"].split(" · ")[0]} — {pn}'
            parts.append(f'<text x="{tx}" y="{oy + ch - 12}" fill="#f2e3c6" font-size="13" text-anchor="middle">{label}</text>')
    parts.append("</svg>")
    return "".join(parts)


def main():
    (OUT / "rigs").mkdir(parents=True, exist_ok=True)
    (OUT / "preview").mkdir(parents=True, exist_ok=True)
    rigs = [build(c) for c in load_cast()]
    import props  # objetos de la trama (campana, linterna, olla…) como rigs de una sola pieza
    rigs += props.build_all()
    for r in rigs:
        (OUT / "rigs" / f'{r["id"]}.json').write_text(json.dumps(r, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT / "preview" / "sheet.svg").write_text(sheet(rigs), encoding="utf-8")
    index = {"format": "caldero-art-index", "version": 1, "pack": "medieval", "rig": "humanoid",
             "rigs": [f"medieval/rigs/{r['id']}.json" for r in rigs],
             "scenes": ["medieval/scenes/castle_night.json"], "clips": "clips/humanoid.json",
             "extraClips": ["clips/props.json"],
             "sizes": {**{c["id"]: c["size"] for c in load_cast() if "size" in c}, "cabrita": 1.5}}
    (OUT / "index.json").write_text(json.dumps(index, indent=1) + "\n", encoding="utf-8")
    for r in rigs:
        size = (OUT / "rigs" / f'{r["id"]}.json').stat().st_size
        print(f'{r["id"]:10s} {size / 1024:5.1f} KB')


if __name__ == "__main__":
    main()
