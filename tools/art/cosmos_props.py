#!/usr/bin/env python3
"""Objetos de la trama del pack «Aldea de las Nubes» (docs/27), como rigs de una sola pieza.

Mismas convenciones que `props.py` y `mar_props.py`. Los huesos `glow` sirven al gesto `shimmer` (la estrellita, la flor
de cristal y la semilla de luz brillan); el globo y el cohete de juguete usan `bob` (flotan). Los escribe `cosmos_kit.py`.
"""
import math

from medieval_kit import DARK, S, ell, mix, n, node, poly, rrect, shade, shine, star
from mar_kit import prop_rig as rig


def telescopio():
    pal = {"tube": "#4a6ab0", "tube2": "#2a3a6a", "brass": "#e0b040", "wood": "#8a5a2b"}
    legs = [S("M0,-60 L-30,0", None, "$wood", 5), S("M0,-60 L30,0", None, "$wood", 5), S("M0,-60 L0,0", None, "$wood", 5)]
    tube = node("tube", (0, -64), shapes=[S(poly([(-56, -48), (40, -96), (48, -80), (-48, -32)]), "$tube", "#1a2a4a", 2.5),
                                           S(rrect(-6, -76, 16, 20, 4), "$brass", "#7a5a1a", 2),
                                           S(ell(46, -88, 6, 10), "#9ad8ff", "#2a6a9a", 2), shine("M-48,-44 L36,-88 L38,-84 L-46,-40 Z")])
    return rig("telescopio", "Telescopio", [-66, -110, 132, 114], pal, node("root", (0, 0), shapes=legs, post=[tube]))


def estrella_caida():
    pal = {"star": "#ffe46a", "glow": "#fff6c0"}
    glow = node("glow", (0, -40), shapes=[S(ell(0, -40, 46, 46), "$glow", None, 0, 0.35)])
    face = [S(star(0, -40, 32, 14), "$star", "#c8a020", 2.5), S(ell(-8, -42, 3, 4), DARK, None), S(ell(8, -42, 3, 4), DARK, None),
            S("M-6,-32 Q0,-27 6,-32", None, DARK, 2), S(ell(-14, -34, 4, 2.5), "#ff9aa8", None, 0, 0.6), S(ell(14, -34, 4, 2.5), "#ff9aa8", None, 0, 0.6)]
    return rig("estrella_caida", "Estrellita caída", [-50, -90, 100, 94], pal, node("root", (0, 0), pre=[glow], shapes=face))


def cohete_juguete():
    pal = {"body": "#f0f2f8", "red": "#e84a5f", "win": "#7ad0ff", "flame": "#ffb040"}
    sh = [S("M0,-110 C18,-90 20,-50 16,-24 L-16,-24 C-20,-50 -18,-90 0,-110 Z", "$body", "#5a6a8a", 2.5),
          S("M0,-110 C10,-100 14,-90 15,-82 L-15,-82 C-14,-90 -10,-100 0,-110 Z", "$red", None),
          S(ell(0, -64, 8, 8), "$win", "#2a5a8a", 2), S(poly([(-16, -44), (-30, -14), (-14, -24)]), "$red", "#7a1a2a", 2),
          S(poly([(16, -44), (30, -14), (14, -24)]), "$red", "#7a1a2a", 2), S("M-8,-24 L0,-6 L8,-24 Z", "$flame", None)]
    return rig("cohete_juguete", "Cohete de juguete", [-36, -116, 72, 120], pal, node("root", (0, -50), shapes=sh))


def casco():
    pal = {"glass": "#d8f4ff", "ring": "#9aa8c0"}
    sh = [S(ell(0, -44, 40, 38), "$glass", "#9ac0d8", 3, 0.5), shine("M-26,-58 C-20,-74 -6,-80 6,-80 C-8,-74 -18,-66 -22,-52 Z"),
          S(rrect(-34, -12, 68, 12, 6), "$ring", "#5a6a8a", 2)]
    return rig("casco", "Casco", [-46, -88, 92, 92], pal, node("root", (0, 0), shapes=sh))


def mapa_estelar():
    pal = {"paper": "#2a2a6a", "edge": "#f4c542", "dot": "#fff6c0"}
    sh = [S(rrect(-60, -82, 120, 76, 6), "$paper", "$edge", 3)]
    pts = [(-40, -60), (-20, -42), (4, -56), (24, -30), (44, -50)]
    sh.append(S("M" + " L".join(f"{x},{y}" for x, y in pts), None, "#9ab0ff", 1.6))
    sh += [S(star(x, y, 5, 2.2), "$dot", None) for x, y in pts]
    sh += [S(ell(x, y, 1.6, 1.6), "$dot", None, 0, 0.7) for x, y in ((-50, -20), (-10, -70), (30, -70), (50, -18), (-30, -24))]
    return rig("mapa_estelar", "Mapa de estrellas", [-66, -90, 132, 92], pal, node("root", (0, 0), shapes=sh))


def piedra_lunar():
    pal = {"rock": "#c8c8d8", "dark": "#8a8aa0"}
    sh = [S("M-34,-4 C-40,-30 -20,-48 2,-46 C26,-46 40,-30 34,-4 Z", "$rock", "#5a5a70", 2.5),
          S(ell(-12, -26, 7, 5), "$dark", None), S(ell(14, -18, 5, 4), "$dark", None), S(ell(4, -36, 4, 3), "$dark", None),
          shine("M-24,-30 C-18,-40 -6,-44 4,-44 C-8,-40 -16,-34 -20,-24 Z")]
    return rig("piedra_lunar", "Piedra lunar", [-44, -54, 88, 56], pal, node("root", (0, 0), shapes=sh))


def flor_cristal():
    pal = {"petal": "#a8f0ff", "stem": "#7ad8c8", "glow": "#e8fffc"}
    glow = node("glow", (0, -70), shapes=[S(ell(0, -70, 34, 34), "$glow", None, 0, 0.35)])
    sh = [S("M0,0 L0,-56", None, "$stem", 4), S(poly([(0, -30), (18, -42), (4, -24)]), "$stem", None)]
    for a in range(6):
        r = math.radians(a * 60)
        x, y = math.cos(r) * 16, -70 + math.sin(r) * 16
        sh.append(S(poly([(0, -70), (x + math.cos(r + 0.5) * 8, y + math.sin(r + 0.5) * 8), (x * 1.6, -70 + (y + 70) * 1.6),
                         (x + math.cos(r - 0.5) * 8, y + math.sin(r - 0.5) * 8)]), "$petal", "#3a9ab0", 1.5, 0.9))
    sh.append(S(ell(0, -70, 6, 6), "#fff6c0", None))
    return rig("flor_cristal", "Flor de cristal", [-40, -110, 80, 114], pal, node("root", (0, 0), pre=[glow], shapes=sh))


def llave_inglesa():
    pal = {"metal": "#9aa8c0"}
    sh = [S(rrect(-6, -70, 12, 60, 5), "$metal", "#4a5a6a", 2), S("M-16,-90 L-16,-70 L16,-70 L16,-90 L6,-90 L6,-78 L-6,-78 L-6,-90 Z", "$metal", "#4a5a6a", 2),
          S(ell(0, -10, 10, 10), "$metal", "#4a5a6a", 2), S(ell(0, -10, 4, 4), "#2a2a3a", None)]
    return rig("llave_inglesa", "Llave inglesa", [-22, -96, 44, 100], pal, node("root", (0, 0), shapes=sh))


def globo():
    pal = {"balloon": "#ff6a9a", "string": "#8a8a9a"}
    sh = [S("M0,0 C-6,-30 6,-50 0,-70", None, "$string", 1.8), S(ell(0, -100, 28, 34), "$balloon", "#a02a5a", 2.5),
          S(poly([(-5, -66), (5, -66), (0, -72)]), "$balloon", None), shine(ell(-10, -112, 6, 10))]
    return rig("globo", "Globo", [-34, -140, 68, 144], pal, node("root", (0, -60), shapes=sh))


def semilla_luz():
    pal = {"seed": "#ffd84a", "glow": "#fff6c0", "pot": "#c87a4a"}
    glow = node("glow", (0, -40), shapes=[S(ell(0, -40, 26, 26), "$glow", None, 0, 0.4)])
    sh = [S(rrect(-22, -24, 44, 24, 6), "$pot", "#6a3a1a", 2), S(ell(0, -40, 10, 13), "$seed", "#a8801a", 2), shine(ell(-3, -44, 3, 4))]
    return rig("semilla_luz", "Semilla de luz", [-30, -70, 60, 72], pal, node("root", (0, 0), pre=[glow], shapes=sh))


def build_all():
    return [telescopio(), estrella_caida(), cohete_juguete(), casco(), mapa_estelar(), piedra_lunar(), flor_cristal(),
            llave_inglesa(), globo(), semilla_luz()]
