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


def _semilla(cx, cy, k=1.0):
    """La semilla de luz: una gota dorada (de punta arriba) con su brillo."""
    return [S(f"M{cx},{cy - 15 * k} C{cx + 9 * k},{cy - 6 * k} {cx + 11 * k},{cy + 4 * k} {cx + 8 * k},{cy + 9 * k} "
              f"C{cx + 4 * k},{cy + 14 * k} {cx - 4 * k},{cy + 14 * k} {cx - 8 * k},{cy + 9 * k} "
              f"C{cx - 11 * k},{cy + 4 * k} {cx - 9 * k},{cy - 6 * k} {cx},{cy - 15 * k} Z", "$seed", "#a8801a", 2),
            shine(ell(cx - 3 * k, cy + 1 * k, 2.6 * k, 4 * k))]


def semilla_luz_mano():
    """La semilla de luz suelta, sin maceta: la que se regala y se lleva en la mano (luego se planta: `semilla_luz`)."""
    pal = {"seed": "#ffd84a", "glow": "#fff6c0"}
    glow = node("glow", (0, -22), shapes=[S(ell(0, -22, 24, 24), "$glow", None, 0, 0.45)])
    sh = _semilla(0, -22) + [S(star(12, -36, 4, 1.6, 4), "#ffffff", None, 0, 0.9)]
    return rig("semilla_luz_mano", "Semilla de luz (en la mano)", [-28, -50, 56, 52], pal, node("root", (0, 0), pre=[glow], shapes=sh))


def _maceta():
    return [S("M-24,-26 L24,-26 L19,0 L-19,0 Z", "$pot", "#6a3a1a", 2), S(rrect(-27, -32, 54, 9, 3), "$pot", "#6a3a1a", 2),
            S(ell(0, -32, 22, 3), "#6a4020", None)]


def brote_luz():
    """El brote de la semilla de luz: dos hojitas verdes en la maceta, con un botón dorado que apenas brilla."""
    pal = {"pot": "#c87a4a", "leaf": "#6ad06a", "leaf2": "#3a9a4a", "bud": "#ffd84a", "glow": "#fff6c0"}
    glow = node("glow", (0, -66), shapes=[S(ell(0, -66, 16, 16), "$glow", None, 0, 0.45)])
    leaves = node("leaves", (0, -32), shapes=[
        S("M0,-32 C-1,-44 1,-54 0,-62", None, "$leaf2", 3.5),
        S("M0,-46 C-8,-56 -22,-56 -26,-48 C-18,-42 -8,-42 0,-46 Z", "$leaf", "#2a7a3a", 2),
        S("M0,-50 C8,-62 22,-62 26,-54 C18,-46 8,-46 0,-50 Z", "$leaf", "#2a7a3a", 2),
        S(ell(0, -66, 5, 6), "$bud", "#a8801a", 1.5)], pre=[glow])
    return rig("brote_luz", "Brote de luz", [-34, -86, 68, 88], pal, node("root", (0, 0), shapes=_maceta(), post=[leaves]))


def flor_luz():
    """La flor de luz: una flor dorada como una lamparita (corola de campana), con su halo de luz."""
    pal = {"petal": "#ffcf3a", "petal2": "#ffe98a", "stem": "#4ab45a", "glow": "#fff3b0", "core": "#fffbe0"}
    glow = node("glow", (0, -84), shapes=[S(ell(0, -84, 50, 50), "$glow", None, 0, 0.35),
                                          S(ell(0, -84, 30, 30), "$glow", None, 0, 0.35)])
    leaves = node("leaves", (0, -20), shapes=[
        S("M0,-24 C-12,-34 -30,-32 -34,-22 C-22,-16 -8,-18 0,-24 Z", "$stem", "#2a7a3a", 2),
        S("M0,-36 C12,-48 30,-46 34,-36 C22,-30 8,-30 0,-36 Z", "$stem", "#2a7a3a", 2)])
    sh = [S("M0,0 C-2,-24 2,-48 0,-70", None, "$stem", 4.5)]
    sh += [S("M-26,-82 C-28,-104 -12,-112 0,-112 C12,-112 28,-104 26,-82 C20,-76 12,-80 8,-74 C4,-80 -4,-80 -8,-74 "
             "C-12,-80 -20,-76 -26,-82 Z", "$petal", "#b8860b", 2.5),
           S("M-8,-74 C-6,-92 -2,-106 0,-110 C2,-106 6,-92 8,-74 C4,-80 -4,-80 -8,-74 Z", "$petal2", None, 0, 0.9),
           S(ell(0, -76, 7, 5), "$core", "#e0b040", 1.5), shine("M-18,-92 C-18,-102 -12,-106 -6,-106 C-12,-100 -14,-94 -14,-86 Z")]
    sh += [S(star(x, y, 4, 1.6, 4), "#ffffff", None, 0, 0.9) for x, y in ((-34, -108), (32, -118), (38, -70))]
    return rig("flor_luz", "Flor de luz", [-54, -138, 108, 142], pal, node("root", (0, 0), pre=[glow, leaves], shapes=sh))


def piedra_violeta():
    """La piedra violeta de la luna (como un caramelo de uva): brilla, con un hueso `glow` para `shimmer`."""
    pal = {"rock": "#9a5ae0", "rock2": "#c89aff", "dark": "#5a2a9a", "glow": "#e6d0ff"}
    glow = node("glow", (0, -24), shapes=[S(ell(0, -24, 46, 38), "$glow", None, 0, 0.4)])
    sh = [S("M-30,-4 C-38,-24 -24,-44 0,-46 C24,-46 38,-28 32,-6 C28,2 -24,2 -30,-4 Z", "$rock", "#3a1a6a", 2.5),
          S("M-6,-44 L4,-26 L30,-14 M4,-26 L-24,-10", None, "$dark", 1.6),
          S("M-24,-30 C-20,-40 -8,-44 0,-44 L-4,-28 Z", "$rock2", None, 0, 0.8),
          shine("M-22,-32 C-18,-40 -10,-42 -4,-42 C-10,-38 -14,-34 -16,-28 Z")]
    sh += [S(star(x, y, 5, 2, 4), "#ffffff", None, 0, 0.9) for x, y in ((22, -40), (-34, -36))]
    return rig("piedra_violeta", "Piedra violeta", [-50, -64, 100, 68], pal, node("root", (0, 0), pre=[glow], shapes=sh))


def _globo(rid, name, color, stroke, carta=False):
    pal = {"balloon": color, "string": "#8a8a9a", "paper": "#fff6e0", "seal": "#e84a5f"}
    sh = [S("M0,0 C-6,-30 6,-50 0,-70", None, "$string", 1.8), S(ell(0, -100, 28, 34), "$balloon", stroke, 2.5),
          S(poly([(-5, -66), (5, -66), (0, -72)]), "$balloon", None), shine(ell(-10, -112, 6, 10))]
    if carta:  # la carta atada al hilo
        sh += [S(rrect(-16, -30, 32, 22, 3), "$paper", "#8a6a3a", 2), S("M-16,-30 L0,-17 L16,-30", None, "#8a6a3a", 1.6),
               S(ell(0, -18, 3.4, 3.4), "$seal", None), S("M0,-30 C-3,-34 3,-38 0,-42", None, "$string", 2)]
    return rig(rid, name, [-34, -140, 68, 144], pal, node("root", (0, -60), shapes=sh))


def globo_rojo():
    return _globo("globo_rojo", "Globo rojo", "#e8323c", "#8a1a22")


def globo_azul_carta():
    return _globo("globo_azul_carta", "Globo azul con carta", "#4a8ae8", "#1a4a8a", carta=True)


def globo_grande_estrella():
    """El globo grande de la aldea (de aire caliente, con su cesta) con la estrellita atada debajo."""
    pal = {"a": "#ffcf5a", "b": "#5a8ae0", "basket": "#b07a3a", "rope": "#7a5a3a", "star": "#ffe46a", "glow": "#fff6c0"}
    env = "M0,-250 C46,-250 74,-214 70,-176 C66,-140 34,-112 18,-96 L-18,-96 C-34,-112 -66,-140 -70,-176 C-74,-214 -46,-250 0,-250 Z"
    sh = [S(env, "$a", "#9a6a10", 3),
          S("M0,-250 C-26,-246 -40,-210 -38,-176 C-36,-140 -22,-112 -10,-96 L-18,-96 C-34,-112 -66,-140 -70,-176 C-74,-214 -46,-250 0,-250 Z", "$b", None),
          S("M0,-250 C26,-246 40,-210 38,-176 C36,-140 22,-112 10,-96 L18,-96 C34,-112 66,-140 70,-176 C74,-214 46,-250 0,-250 Z", "$b", None),
          S(env, None, "#2a3a6a", 3),
          shine("M-50,-210 C-44,-232 -28,-242 -14,-244 C-30,-232 -40,-216 -44,-196 Z"),
          S("M-16,-96 L-14,-70 M16,-96 L14,-70", None, "$rope", 2),
          S(rrect(-18, -72, 36, 24, 4), "$basket", "#5a3a14", 2.5), S("M-18,-62 L18,-62", None, "#5a3a14", 1.6),
          S("M0,-48 L0,-38", None, "$rope", 2)]
    star_n = node("star", (0, -34), pre=[node("glow", (0, -12), shapes=[S(ell(0, -12, 34, 34), "$glow", None, 0, 0.4)])],
                  shapes=[S(star(0, -12, 26, 11), "$star", "#c8a020", 2.5), S(ell(-6, -14, 2.4, 3.2), DARK, None),
                          S(ell(6, -14, 2.4, 3.2), DARK, None), S("M-5,-6 Q0,-2 5,-6", None, DARK, 1.8)])
    return rig("globo_grande_estrella", "Globo grande con la estrellita", [-80, -260, 160, 284], pal,
               node("root", (0, -100), shapes=sh, post=[star_n]))


def frasco():
    """Frasco de cristal con tapa: se dibuja delante de la estrellita (`estrella_caida`, a la misma x, lift y escala)
    para que se vea dentro, apagadita detrás del cristal."""
    pal = {"glass": "#bfe6ff", "lid": "#c8a040", "label": "#ffe08a"}
    sh = [S("M-40,-92 C-50,-88 -54,-80 -54,-66 L-54,-10 C-54,-2 -48,4 -40,4 L40,4 C48,4 54,-2 54,-10 L54,-66 C54,-80 50,-88 40,-92 Z",
            "$glass", "#6a9ac0", 3, 0.45),
          S("M-54,-10 C-54,-2 -48,4 -40,4 L40,4 C48,4 54,-2 54,-10 L54,-4 C40,6 -40,6 -54,-4 Z", "#d8f0ff", None, 0, 0.7),
          S(rrect(-42, -104, 84, 16, 5), "$lid", "#6a4a10", 2.5), S("M-42,-96 L42,-96", None, "#8a6a20", 1.5),
          S(rrect(-18, -13, 36, 11, 3), "$label", "#a8801a", 1.5),
          S("M-44,-80 C-46,-60 -46,-36 -44,-16", None, "#ffffff", 5, 0.6), S("M-36,-80 L-36,-70", None, "#ffffff", 3, 0.5)]
    return rig("frasco", "Frasco de cristal", [-60, -110, 120, 116], pal, node("root", (0, 0), shapes=sh))


def build_all():
    return [telescopio(), estrella_caida(), cohete_juguete(), casco(), mapa_estelar(), piedra_lunar(), flor_cristal(),
            llave_inglesa(), globo(), semilla_luz(),
            semilla_luz_mano(), brote_luz(), flor_luz(), piedra_violeta(), globo_rojo(), globo_azul_carta(),
            globo_grande_estrella(), frasco()]
