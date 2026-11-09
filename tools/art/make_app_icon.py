#!/usr/bin/env python3
"""Icono de la app, dibujado por código (un libro de cuentos abierto bajo una luna con carita) y exportado a todos los tamaños.

Escribe:
  app/android/app/src/main/res/mipmap-*/ic_launcher.png            (icono clásico, cuadrado)
  app/android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (capa de primer plano del icono adaptativo)
  app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml   (icono adaptativo: fondo de color + primer plano)
  app/android/app/src/main/res/values/ic_launcher_background.xml
  app/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png          (todos los tamaños de Contents.json, sin transparencia)
  art/app_icon/icon-1024.png                                       (para las fichas de las tiendas)

Uso: python3 tools/art/make_app_icon.py     (requiere Pillow)
"""
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "app/android/app/src/main/res"
IOS = ROOT / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
OUT = ROOT / "art/app_icon"
BG_TOP, BG_BOTTOM = (40, 30, 104), (96, 72, 180)  # cielo de noche, más alegre que antes
S = 2048  # se dibuja al doble y se reduce


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    im = Image.new("RGB", (S, S))
    px = ImageDraw.Draw(im)
    for y in range(S):
        px.line([(0, y), (S, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / (S - 1)))
    return im


def glow(size, center, radius, color, alpha):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
                                  fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))


def star(draw, cx, cy, r, fill):
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else r * 0.38
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    draw.polygon(pts, fill=fill)


def star5(draw, cx, cy, r, fill):
    """Estrella de cinco puntas (la de los dibujos infantiles; sin simbolismo)."""
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = r if i % 2 == 0 else r * 0.5
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    draw.polygon(pts, fill=fill)


def foreground(zone=0.66):
    """Un libro de cuentos abierto, una luna llena con carita que asoma detrás y estrellas de colores, sobre fondo
    transparente. Cabe en el 66 % central (zona segura adaptativa). Sin calderos, fuego, coronas ni símbolos."""
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = S // 2
    k = zone * S / 1000  # 1000 unidades = la zona de dibujo

    def X(v):
        return cx + (v - 500) * k

    def Y(v):
        return S / 2 + (v - 500) * k

    # luna llena con halo y carita
    fg.alpha_composite(glow(S, (X(500), Y(330)), 260 * k, (255, 226, 150), 70))
    d = ImageDraw.Draw(fg)
    d.ellipse([X(330), Y(160), X(670), Y(500)], fill=(255, 231, 163, 255))
    for mx, my, mr in [(410, 235, 34), (600, 290, 22)]:
        d.ellipse([X(mx - mr), Y(my - mr), X(mx + mr), Y(my + mr)], fill=(245, 210, 122, 255))
    ink = (58, 42, 92, 255)
    for ex in (440, 560):
        d.ellipse([X(ex - 20), Y(315 - 20), X(ex + 20), Y(315 + 20)], fill=ink)
        d.ellipse([X(ex - 2), Y(303 - 8), X(ex + 12), Y(303 + 6)], fill=(255, 255, 255, 255))
    for chx in (395, 605):
        d.ellipse([X(chx - 30), Y(370 - 22), X(chx + 30), Y(370 + 22)], fill=(255, 168, 168, 230))
    d.arc([X(445), Y(320), X(555), Y(410)], 25, 155, fill=ink, width=int(18 * k))

    # estrellas de colores
    star5(d, X(195), Y(250), 58 * k, (142, 227, 200, 255))
    star5(d, X(815), Y(215), 50 * k, (255, 168, 210, 255))
    star5(d, X(800), Y(440), 36 * k, (255, 211, 110, 255))
    star5(d, X(215), Y(440), 30 * k, (111, 195, 255, 255))

    # libro abierto: tapa, dos páginas con renglones y lomo
    d.rounded_rectangle([X(90), Y(520), X(910), Y(900)], radius=46 * k, fill=(217, 83, 79, 255))
    for side in (-1, 1):
        x0, x1 = (X(130), X(500)) if side < 0 else (X(500), X(870))
        page = [(x0, Y(560)), (x1, Y(560)), (x1, Y(865)), (x0, Y(865))]
        d.polygon(page, fill=(255, 249, 236, 255))
        for i in range(5):
            y = Y(615 + i * 52)
            lx0 = X(175) if side < 0 else X(545)
            ln = (275 if i < 4 else 160) * k
            d.line([lx0, y, lx0 + ln, y], fill=(203, 184, 146, 255), width=int(14 * k))
    # curva superior de las páginas (se abomban hacia el lomo)
    d.ellipse([X(130), Y(530), X(500), Y(590)], fill=(255, 249, 236, 255))
    d.ellipse([X(500), Y(530), X(870), Y(590)], fill=(255, 249, 236, 255))
    d.line([X(500), Y(545), X(500), Y(870)], fill=(241, 227, 196, 255), width=int(14 * k))
    return fg


def compose_icon(fg, size):  # `fg` ya viene con la escala que toca
    """Icono clásico: cielo + estrellitas + primer plano, cuadrado y sin transparencia."""
    bg = background().convert("RGBA")
    d = ImageDraw.Draw(bg)
    rnd = random.Random(3)
    for _ in range(40):
        x, y, r = rnd.randrange(S), rnd.randrange(int(S * 0.8)), rnd.choice((4, 5, 6, 8))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 244, 214, rnd.choice((120, 170, 220))))
    bg.alpha_composite(fg)
    return bg.convert("RGB").resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fg = foreground()  # adaptativo: 66 % central
    fg_classic = foreground(0.86)  # clásico y iOS: llena el cuadrado
    master = compose_icon(fg_classic, 1024)
    master.save(OUT / "icon-1024.png")

    # Android: clásico + adaptativo
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        compose_icon(fg_classic, px).save(d / "ic_launcher.png")
        fgpx = round(px * 108 / 48)
        fg.resize((fgpx, fgpx), Image.LANCZOS).save(d / "ic_launcher_foreground.png")
    any26 = RES / "mipmap-anydpi-v26"
    any26.mkdir(parents=True, exist_ok=True)
    (any26 / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding="utf-8")
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#2A1F5C</color>\n</resources>\n',
        encoding="utf-8")

    # iOS: todos los tamaños de Contents.json
    contents = json.loads((IOS / "Contents.json").read_text(encoding="utf-8"))
    for img in contents["images"]:
        w = float(img["size"].split("x")[0])
        scale = int(img["scale"].rstrip("x"))
        px = round(w * scale)
        compose_icon(fg_classic, px).save(IOS / img["filename"])
    print("icono generado")


if __name__ == "__main__":
    main()
