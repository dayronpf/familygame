#!/usr/bin/env python3
"""Objetos de la trama del pack «Mar de las Estrellas» (docs/26), como rigs de una sola pieza.

Mismo formato y convenciones que `props.py` (origen en la base del objeto, y hacia abajo). Los huesos con nombre
sirven a los gestos de objetos que ya existen: `flame`/`glow` (`glow`: el farol encendido), `glow` (`shimmer`: la
perla, el cofre abierto) y la raíz entera (`bob`: la botella flota). Los escribe `mar_kit.py` con los personajes.
"""
import math

from medieval_kit import S, ell, mix, n, node, poly, rrect, shade, shine, star
from mar_kit import DARK, prop_rig as rig


def caracola():
    pal = {"shell": "#ffb0a0", "shell2": "#ffd8c8", "lip": "#ff7a8a"}
    body = [S("M-46,-8 C-50,-40 -20,-70 14,-70 C40,-70 54,-50 50,-30 C46,-12 20,-4 -6,-2 C-24,0 -40,2 -46,-8 Z", "$shell"),
            S("M14,-70 C34,-60 40,-40 30,-28 C20,-38 10,-50 14,-70 Z", "$shell2"),
            S("M-46,-8 C-30,-20 -20,-24 -6,-2 C-24,0 -40,2 -46,-8 Z", "$lip")]
    for k in range(4):
        x = -30 + k * 18
        body.append(S(f"M{x},-10 C{x + 6},-30 {x + 14},-46 {x + 22},-58", None, mix("#ffb0a0", DARK, 0.3), 2))
    body += [shine("M-20,-50 C-6,-62 10,-64 20,-62 C4,-56 -8,-50 -16,-40 Z")]
    return rig("caracola", "Caracola", [-60, -80, 120, 90], pal, node("root", (0, 0), shapes=body))


def mapa(roto=False):
    pal = {"paper": "#f3e2b4", "paper2": "#e0c890", "ink": "#8a4a2a", "x": "#d8463a"}
    sh = [S("M-60,-80 L60,-80 L58,-6 L-58,-6 Z" if not roto else "M-60,-80 L10,-80 L0,-50 L14,-30 L4,-6 L-58,-6 Z", "$paper", "#8a6a3a", 2.5),
          S(rrect(-66, -86, 12, 84, 6), "$paper2", "#8a6a3a", 2), S(rrect(54, -86, 12, 84, 6), "$paper2", "#8a6a3a", 2)]
    if roto:
        sh = sh[:2] + [S("M20,-80 L60,-80 L58,-6 L18,-6 L30,-30 L16,-50 Z", "$paper", "#8a6a3a", 2.5, 0.0)]
    sh += [S("M-44,-60 C-30,-70 -10,-56 -18,-44 C-26,-32 -6,-24 10,-34", None, "$ink", 2.4),
           S(ell(-36, -30, 12, 9), "#9ac87a", "#5a7a3a", 1.5)]
    if not roto:
        sh += [S("M10,-34 C22,-40 30,-30 34,-22", None, "$ink", 2.4),
               S("M30,-30 L42,-18 M42,-30 L30,-18", None, "$x", 4)]
    sh.append(S(star(-42, -66, 6, 2.5, 4), "$ink", None))
    rid = "mapa_roto" if roto else "mapa"
    return rig(rid, "Mapa roto" if roto else "Mapa del tesoro", [-72, -96, 144, 100], pal, node("root", (0, 0), shapes=sh))


def cofre(abierto=False):
    pal = {"wood": "#a0602a", "wood2": "#7a4a20", "metal": "#f4c542", "gold": "#ffd85a"}
    base = [S(rrect(-60, -56, 120, 56, 6), "$wood", "#3a1a0e", 2.5),
            S(rrect(-60, -56, 120, 8, 3), "$metal", "#7a5a1a", 1.5), S(rrect(-6, -48, 12, 18, 3), "$metal", "#7a5a1a", 1.5),
            S(rrect(-46, -56, 8, 56, 2), "$wood2", None, 0), S(rrect(38, -56, 8, 56, 2), "$wood2", None, 0)]
    post = []
    if abierto:
        glow = node("glow", (0, -56), shapes=[S(ell(0, -60, 70, 34), "#fff3a0", None, 0, 0.35)])
        coins = [S(ell(x, -58 - (abs(x) < 20) * 6, 9, 5), "$gold", "#a8801a", 1.5) for x in (-40, -24, -8, 8, 24, 40)]
        coins += [S(star(-14, -70, 7, 3), "#ffffff", None, 0, 0.9), S(ell(18, -68, 6, 6), "#8ad0ff", "#2a6a9a", 1.5)]
        lid = [S("M-60,-58 L-56,-110 C-30,-124 30,-124 56,-110 L60,-58 Z", "$wood2", "#3a1a0e", 2.5),
               S("M-56,-110 C-30,-124 30,-124 56,-110", None, "$metal", 5)]
        base = lid + base + coins
        post.append(glow)
    else:
        base = [S("M-60,-56 C-60,-90 60,-90 60,-56 Z", "$wood", "#3a1a0e", 2.5),
                S("M-60,-56 C-60,-90 60,-90 60,-56", None, "$metal", 5)] + base
    rid = "cofre_abierto" if abierto else "cofre"
    return rig(rid, "Cofre abierto" if abierto else "Cofre", [-74, -130, 148, 136], pal, node("root", (0, 0), shapes=base, post=post))


def catalejo():
    pal = {"brass": "#e0b040", "brass2": "#a8801a", "lens": "#9ad8ff"}
    sh = [S(poly([(-60, -18), (40, -30), (40, -6), (-60, -12)]), "$brass", "#6a4a10", 2),
          S(rrect(10, -34, 14, 32, 4), "$brass2", "#6a4a10", 2), S(rrect(-24, -24, 10, 18, 3), "$brass2", "#6a4a10", 2),
          S(ell(42, -18, 6, 14), "$lens", "#2a6a9a", 2), shine("M-50,-17 L30,-27 L30,-24 L-50,-15 Z")]
    return rig("catalejo", "Catalejo", [-70, -44, 124, 50], pal, node("root", (0, 0), shapes=sh))


def brujula():
    pal = {"case": "#e0b040", "face": "#fff6e0", "needle": "#d8463a"}
    needle = node("needle", (0, -36), shapes=[S(poly([(0, -64), (6, -36), (0, -30), (-6, -36)]), "$needle", None),
                                              S(poly([(0, -8), (6, -36), (0, -42), (-6, -36)]), "#3a3a4a", None)])
    sh = [S(ell(0, -36, 36, 36), "$case", "#6a4a10", 3), S(ell(0, -36, 28, 28), "$face", "#a8801a", 1.5),
          S(rrect(-6, -80, 12, 12, 4), "$case", "#6a4a10", 2)]
    for k, a in enumerate((0, 90, 180, 270)):
        x, y = math.sin(math.radians(a)) * 22, -36 - math.cos(math.radians(a)) * 22
        sh.append(S(ell(x, y, 2.4, 2.4), "#6a4a10", None))
    return rig("brujula", "Brújula", [-44, -86, 88, 92], pal, node("root", (0, 0), shapes=sh, post=[needle, node("cap", (0, -36), shapes=[S(ell(0, -36, 4, 4), "$case", None)])]))


def botella():
    pal = {"glass": "#8ad8c0", "cork": "#b0804a", "paper": "#f3e2b4"}
    sh = [S("M-40,-20 C-40,-36 -24,-40 0,-40 L22,-36 L34,-34 L34,-22 L22,-20 L0,-14 C-24,-12 -40,-8 -40,-20 Z", "$glass", "#2a7a6a", 2.5, 0.85),
          S(rrect(32, -36, 12, 14, 3), "$cork", "#5a3a1a", 2),
          S("M-26,-30 L4,-32 L4,-20 L-26,-18 Z", "$paper", "#8a6a3a", 1.5),
          S("M-26,-26 L4,-27", None, "#d8463a", 1.6), shine("M-30,-34 C-18,-38 -2,-38 10,-36 L-28,-30 Z")]
    return rig("botella_mensaje", "Botella con un mensaje", [-50, -50, 100, 50], pal, node("root", (0, -24), shapes=sh))


def farol_barco(encendido=True):
    pal = {"metal": "#4a4a56", "glass": "#ffe08a" if encendido else "#c8c0a8", "flame": "#ffb040"}
    post = []
    if encendido:
        post = [node("glow", (0, -40), shapes=[S(ell(0, -40, 46, 46), "#fff3c4", None, 0, 0.25)]),
                node("flame", (0, -30), shapes=[S("M0,-56 C10,-44 8,-30 0,-28 C-8,-30 -10,-44 0,-56 Z", "$flame", None)])]
    sh = [S("M-4,-92 C-4,-104 4,-104 4,-92", None, "$metal", 3),
          S(rrect(-22, -76, 44, 60, 8), "$glass", None, 0, 0.9),
          S(rrect(-26, -84, 52, 10, 4), "$metal", "#1a1a2a", 2), S(rrect(-26, -18, 52, 18, 4), "$metal", "#1a1a2a", 2),
          S(poly([(-20, -84), (20, -84), (0, -94)]), "$metal", "#1a1a2a", 2)]
    for x in (-22, -7, 7, 22):
        sh.append(S(rrect(x - 2, -76, 4, 58, 1), "$metal", None))
    rid = "farol_barco" if encendido else "farol_barco_apagado"
    return rig(rid, "Farol" if encendido else "Farol apagado", [-40, -110, 80, 114], pal,
               node("root", (0, 0), shapes=sh[:2], post=post + [node("frame", (0, 0), shapes=sh[2:])]))


def perla():
    pal = {"pearl": "#f6f2ff", "shell": "#c8a0d8"}
    glow = node("glow", (0, -26), shapes=[S(ell(0, -26, 30, 30), "#ffffff", None, 0, 0.35)])
    sh = [S("M-40,-6 C-40,-30 -20,-40 0,-40 C20,-40 40,-30 40,-6 Z", "$shell", "#6a4a7a", 2.5),
          S("M-40,-6 C-20,0 20,0 40,-6 C20,-14 -20,-14 -40,-6 Z", mix("#c8a0d8", DARK, 0.2), None),
          S(ell(0, -18, 12, 12), "$pearl", "#a8a0c0", 1.5), shine(ell(-4, -22, 4, 3))]
    return rig("perla", "Perla", [-50, -60, 100, 64], pal, node("root", (0, 0), shapes=sh[:2], post=[glow, node("pearl", (0, -18), shapes=sh[2:])]))


def llave():
    pal = {"metal": "#f4c542"}
    sh = [S(ell(-26, -20, 16, 16), None, "$metal", 6), S(rrect(-12, -23, 52, 7, 3), "$metal", "#7a5a1a", 1.5),
          S(rrect(26, -18, 6, 12, 2), "$metal", "#7a5a1a", 1.5), S(rrect(36, -18, 6, 9, 2), "$metal", "#7a5a1a", 1.5)]
    return rig("llave", "Llave", [-46, -40, 92, 44], pal, node("root", (0, 0), shapes=sh))


def galleta():
    pal = {"cookie": "#e0b070", "dot": "#a8703a"}
    sh = [S(rrect(-28, -34, 56, 34, 6), "$cookie", "#8a5a2a", 2.5)]
    for x in (-16, 0, 16):
        for y in (-24, -10):
            sh.append(S(ell(x, y, 2.4, 2.4), "$dot", None))
    return rig("galleta_barco", "Galleta de barco", [-36, -42, 72, 46], pal, node("root", (0, 0), shapes=sh))


def monedas():
    pal = {"gold": "#f4c542", "gold2": "#ffe08a"}
    sh = []
    for x, y in ((-20, 0), (0, 0), (20, 0), (-10, -8), (10, -8), (0, -16)):
        sh += [S(ell(x, y - 6, 14, 6), "$gold", "#a8801a", 2), S(ell(x - 3, y - 8, 4, 1.6), "$gold2", None)]
    return rig("monedas", "Montón de monedas", [-40, -34, 80, 40], pal, node("root", (0, 0), shapes=sh))


def ancla():
    pal = {"iron": "#5a5a66"}
    sh = [S(ell(0, -100, 12, 12), None, "$iron", 6), S(rrect(-5, -90, 10, 80, 4), "$iron", "#2a2a36", 2),
          S(rrect(-28, -80, 56, 9, 4), "$iron", "#2a2a36", 2),
          S("M-46,-34 C-40,-4 40,-4 46,-34 L38,-34 C30,-16 -30,-16 -38,-34 Z", "$iron", "#2a2a36", 2),
          S(poly([(-52, -30), (-38, -42), (-36, -26)]), "$iron", "#2a2a36", 2), S(poly([(52, -30), (38, -42), (36, -26)]), "$iron", "#2a2a36", 2)]
    return rig("ancla", "Ancla", [-60, -118, 120, 122], pal, node("root", (0, 0), shapes=sh))


def estrella_mar():
    pal = {"star": "#ff8a5a"}
    sh = [S(star(0, -26, 28, 12), "$star", "#a04a2a", 2.5)] + [S(ell(math.sin(a) * 12, -26 - math.cos(a) * 12, 2, 2), "#ffd0a8", None)
                                                             for a in [i * 2 * math.pi / 5 for i in range(5)]]
    return rig("estrella_mar", "Estrella de mar", [-34, -58, 68, 62], pal, node("root", (0, 0), shapes=sh))


def build_all():
    return [caracola(), mapa(), mapa(roto=True), cofre(), cofre(abierto=True), catalejo(), brujula(), botella(), farol_barco(),
            farol_barco(encendido=False), perla(), llave(), galleta(), monedas(), ancla(), estrella_mar()]
