#!/usr/bin/env python3
"""Escena de prueba «Castillo bajo la luna»: fondo por capas + personajes animados.

Demuestra que los fondos también salen del código y que cada capa es independiente
(en la app se moverán a distinta velocidad para el efecto parallax).

Uso: python3 tools/art/scene_castle.py   → art/medieval/preview/scene_castle.svg
"""
import json
from pathlib import Path

import medieval_kit as kit
from medieval_kit import S, crescent, ell, n, poly, rrect, star

W, H = 600, 800
OUT = kit.OUT / "preview"


def lcg(seed):
    s = seed
    while True:
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        yield s / 0xFFFFFFFF


def twinkle(delay, dur="3s", lo=0.25, hi=1.0):
    return (f'<animate attributeName="opacity" values="{lo};{hi};{lo}" dur="{dur}" begin="{-delay:.2f}s" '
            'repeatCount="indefinite"/>')


def layer_sky():
    r = lcg(7)
    o = ['<g id="sky"><rect width="600" height="800" fill="url(#sky)"/>']
    for i in range(70):
        x, y, rad = next(r) * W, next(r) * 430, 0.8 + next(r) * 1.6
        anim = twinkle(next(r) * 3) if i % 3 == 0 else ""
        o.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rad:.1f}" fill="#fff6d8" opacity="0.8">{anim}</circle>')
    o.append('<circle cx="470" cy="150" r="95" fill="url(#moonhalo)"/>')
    o.append('<circle cx="470" cy="150" r="46" fill="#fff3c4"/>')
    for cx, cy, r_ in [(455, 138, 9), (488, 162, 7), (466, 172, 5)]:
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r_}" fill="#f1dc9a" opacity="0.7"/>')
    o.append("</g>")
    return "".join(o)


def layer_far():
    return ('<g id="far"><path d="M0,500 C90,455 170,490 270,468 C380,445 470,490 600,455 L600,800 L0,800 Z" fill="#2a2260"/>'
            '<path d="M0,540 C120,500 200,540 320,512 C430,488 520,530 600,505 L600,800 L0,800 Z" fill="#332a78"/></g>')


def tower(x, w, top, base, roof_h, roof="#c0455f", wins=1):
    stone, side = "#b4abd8", "#9188c0"
    o = [S(rrect(x, top, w, base - top, 3), stone, "#4a3f86", 2.5),
         S(rrect(x + w * 0.62, top + 2, w * 0.36, base - top - 4, 3), "#000", None, 0, 0.12),
         S(rrect(x - 4, top - 8, w + 8, 12, 3), side, "#4a3f86", 2.5)]
    for i in range(int((w + 8) // 12)):
        o.append(S(rrect(x - 4 + i * 12 + 1, top - 15, 8, 9, 1.5), side, "#4a3f86", 2))
    o.append(S(poly([(x - 8, top - 8), (x + w + 8, top - 8), (x + w / 2, top - 8 - roof_h)]), roof, "#5a2036", 2.5))
    o.append(S(poly([(x + w / 2, top - 8 - roof_h), (x + w + 8, top - 8), (x + w / 2 + 3, top - 8)]), "#000", None, 0, 0.18))
    o.append(S(rrect(x + w / 2 - 1, top - 8 - roof_h - 22, 2.4, 24, 1), "#6a5a8a", None))
    o.append(S(poly([(x + w / 2 + 1, top - 8 - roof_h - 22), (x + w / 2 + 17, top - 8 - roof_h - 16), (x + w / 2 + 1, top - 8 - roof_h - 10)]), "#f4c542", "#5a4410", 1.5))
    for i in range(wins):
        wy = top + 24 + i * 38
        o.append(S(f"M{n(x + w / 2 - 6)},{n(wy + 18)} L{n(x + w / 2 - 6)},{n(wy + 6)} A6,6 0 0 1 {n(x + w / 2 + 6)},{n(wy + 6)} L{n(x + w / 2 + 6)},{n(wy + 18)} Z", "#ffd27a", "#5a3a14", 2))
    return o


def shapes_svg(shapes, palette=None):
    rig = {"palette": palette or {}}
    return "".join(kit.svg_shape(rig, s) for s in shapes)


def layer_mid():
    sh = [S("M180,600 C230,540 300,530 420,538 C520,545 570,570 640,600 L640,800 L180,800 Z", "#3d3288", "#251c5a", 2.5)]
    # muralla y torres
    sh.append(S(rrect(318, 500, 200, 60, 3), "#a69dcc", "#4a3f86", 2.5))
    sh += tower(300, 46, 440, 565, 44, wins=2)
    sh += tower(494, 46, 440, 565, 44, wins=2)
    sh.append(S(rrect(356, 380, 126, 185, 4), "#b4abd8", "#4a3f86", 2.5))
    sh.append(S(rrect(432, 382, 48, 181, 3), "#000", None, 0, 0.12))
    sh += tower(380, 78, 330, 400, 62, roof="#7a4fd0")
    # puerta con luz
    sh.append(S("M390,565 L390,520 A29,29 0 0 1 448,520 L448,565 Z", "#ffcf70", "#4a2f2a", 3))
    sh.append(S("M404,565 L404,526 A15,15 0 0 1 434,526 L434,565 Z", "#5a3a2a", "#2a1a14", 2))
    for wx, wy in [(392, 440), (428, 440)]:
        sh.append(S(f"M{wx},{wy + 22} L{wx},{wy + 8} A9,9 0 0 1 {wx + 18},{wy + 8} L{wx + 18},{wy + 22} Z", "#ffd27a", "#5a3a14", 2))
    # molino
    sh.append(S("M70,590 C90,570 120,572 150,590 L150,800 L70,800 Z", "#3d3288", "#251c5a", 2.5))
    sh.append(S(poly([(98, 585), (142, 585), (134, 490), (106, 490)]), "#8f84c4", "#4a3f86", 2.5))
    sh.append(S(poly([(104, 490), (136, 490), (120, 458)]), "#7a4fd0", "#3a2670", 2.5))
    sh.append(S(rrect(114, 540, 12, 45, 5), "#5a3a2a", "#2a1a14", 2))
    sh.append(S(ell(120, 520, 5, 7), "#ffd27a", "#5a3a14", 1.5))
    out = ['<g id="mid">', shapes_svg(sh)]
    # aspas del molino: giran (simetría de 4 aspas ⇒ 90° = bucle sin costuras)
    blades = "".join(f'<g transform="rotate({a})">' + shapes_svg([
        S(rrect(-4, -62, 8, 62, 2), "#8a5a2b", "#3a2412", 2),
        S(rrect(-16, -60, 14, 34, 2), "#efe4c8", "#6a5a3a", 2),
    ]) + "</g>" for a in (0, 90, 180, 270))
    out.append(f'<g transform="translate(120 482)"><g>{blades}'
               '<animateTransform attributeName="transform" type="rotate" values="0;90" dur="3s" repeatCount="indefinite"/></g>'
               + shapes_svg([S(ell(0, 0, 6, 6), "#8a5a2b", "#3a2412", 2)]) + "</g>")
    out.append("</g>")
    return "".join(out)


def layer_near():
    o = ['<g id="near">',
         shapes_svg([S("M0,650 C150,620 300,660 600,625 L600,800 L0,800 Z", "#2c6b5e", "#1b3f3a", 3),
                     S("M0,700 C160,676 330,712 600,684 L600,800 L0,800 Z", "#245a50", None, 0)])]
    # árboles
    for tx, ty, s_ in [(46, 650, 1.0), (560, 640, 0.9)]:
        o.append(f'<g transform="translate({tx} {ty}) scale({s_})">' + shapes_svg([
            S(rrect(-7, -50, 14, 56, 4), "#6a4426", "#2a180c", 2.5),
            S(ell(0, -92, 38, 36), "#2f8f66", "#16463a", 3), S(ell(-22, -66, 28, 24), "#2a7d5b", "#16463a", 3),
            S(ell(24, -68, 28, 24), "#2a7d5b", "#16463a", 3), shade_el(14, -96)]) + "</g>")
    # luciérnagas
    r = lcg(21)
    for i in range(16):
        x, y = next(r) * W, 560 + next(r) * 220
        d = next(r) * 3
        o.append(f'<g><circle cx="{x:.0f}" cy="{y:.0f}" r="9" fill="#fff59d" opacity="0.25">{twinkle(d, "3s", 0.05, 0.4)}</circle>'
                 f'<circle cx="{x:.0f}" cy="{y:.0f}" r="2.6" fill="#fffde0">{twinkle(d, "3s", 0.3, 1)}</circle></g>')
    o.append("</g>")
    return "".join(o)


def shade_el(cx, cy):
    return S(ell(cx, cy, 14, 26), "#000", None, 0, 0.12)


def character(rig, x, y, k):
    sh = (f'<ellipse cx="{x}" cy="{y + 4}" rx="{58 * k * rig["bodyScale"] + 8:.0f}" ry="8" fill="#000" opacity="0.38"/>')
    body = kit.svg_character(rig, kit.pose("idle", rig), idle=True)
    return f'{sh}<g transform="translate({x} {y}) scale({k})">{body}</g>'


def main():
    rigs = {r["id"]: json.loads((kit.OUT / "rigs" / f'{r["id"]}.json').read_text(encoding="utf-8")) for r in kit.CAST}
    chars = "".join([character(rigs["mara"], 345, 706, 0.62), character(rigs["aldo"], 235, 748, 0.8),
                     character(rigs["zafiro"], 515, 752, 0.76)])
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
           '<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0c0922"/>'
           '<stop offset="0.55" stop-color="#2b2063"/><stop offset="1" stop-color="#6b4aa0"/></linearGradient>'
           '<radialGradient id="moonhalo"><stop offset="0" stop-color="#fff3c4" stop-opacity="0.5"/>'
           '<stop offset="1" stop-color="#fff3c4" stop-opacity="0"/></radialGradient></defs>'
           + layer_sky() + layer_far() + layer_mid() + layer_near() + f'<g id="actors">{chars}</g></svg>')
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "scene_castle.svg").write_text(svg, encoding="utf-8")
    print(f"scene_castle.svg  {len(svg) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
