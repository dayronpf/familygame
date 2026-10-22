#!/usr/bin/env python3
"""Icono de la app, dibujado por código (el caldero de los cuentos bajo la luna) y exportado a todos los tamaños.

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
BG_TOP, BG_BOTTOM = (22, 16, 62), (66, 44, 128)
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


def foreground(zone=0.66):
    """El caldero, la luna y las estrellas sobre fondo transparente. Cabe en el 66 % central (zona segura adaptativa)."""
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = S // 2
    k = zone * S / 1000  # 1000 unidades = la zona de dibujo (0,66 = zona segura del icono adaptativo)

    def X(v):
        return cx + (v - 500) * k

    def Y(v):
        return S / 2 + (v - 500) * k

    # luna creciente con halo
    moon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(moon).ellipse([X(640), Y(190), X(760), Y(310)], fill=(255, 241, 194, 255))
    cut = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cut).ellipse([X(676), Y(176), X(796), Y(296)], fill=255)
    moon.putalpha(ImageChops.subtract(moon.getchannel("A"), cut))
    fg.alpha_composite(glow(S, (X(700), Y(250)), 170 * k, (255, 226, 150), 80))
    fg.alpha_composite(moon)
    d = ImageDraw.Draw(fg)

    # estrellas
    for sx, sy, sr, col in [(300, 190, 34, (255, 214, 120, 255)), (160, 330, 22, (255, 245, 214, 255)),
                            (850, 470, 24, (255, 245, 214, 255)), (430, 90, 20, (255, 245, 214, 255))]:
        star(d, X(sx), Y(sy), sr * k, col)

    # llamas
    for fx, fh, col in [(350, 130, (255, 120, 30, 255)), (430, 160, (255, 160, 50, 255)), (500, 180, (255, 205, 80, 255)),
                        (570, 160, (255, 160, 50, 255)), (650, 130, (255, 120, 30, 255))]:
        d.polygon([(X(fx - 50), Y(900)), (X(fx), Y(900 - fh * 1.5)), (X(fx + 50), Y(900))], fill=col)
    # patas
    for lx in (330, 670):
        d.rounded_rectangle([X(lx - 40), Y(740), X(lx + 40), Y(850)], radius=30 * k, fill=(12, 8, 30, 255))
    # cuerpo del caldero
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.ellipse([X(200), Y(420), X(800), Y(830)], fill=(30, 22, 70, 255), outline=(10, 7, 28, 255), width=int(14 * k))
    bd.rectangle([X(150), Y(300), X(850), Y(600)], fill=(0, 0, 0, 0))
    # recorta la mitad superior de la elipse del cuerpo (el borde va encima)
    top_cut = Image.new("L", (S, S), 255)
    ImageDraw.Draw(top_cut).rectangle([0, 0, S, Y(560)], fill=0)
    mask = ImageChops.multiply(body.getchannel("A"), top_cut)
    body.putalpha(mask)
    # relleno entre el borde y la mitad de la elipse
    bd2 = ImageDraw.Draw(body)
    bd2.rectangle([X(200), Y(540), X(800), Y(640)], fill=(30, 22, 70, 255))
    fg.alpha_composite(body)
    d = ImageDraw.Draw(fg)
    # brillo del cuerpo
    d.arc([X(250), Y(520), X(440), Y(780)], 95, 165, fill=(150, 130, 225, 255), width=int(24 * k))
    # borde y poción
    d.ellipse([X(190), Y(430), X(810), Y(590)], fill=(10, 7, 28, 255))
    d.ellipse([X(215), Y(445), X(785), Y(575)], fill=(66, 186, 214, 255))
    d.ellipse([X(260), Y(470), X(740), Y(550)], fill=(120, 226, 236, 255))
    # burbujas y objetos que salen de la poción
    for bx, by, br in [(350, 500, 18), (470, 520, 13), (600, 495, 20), (680, 515, 12)]:
        d.ellipse([X(bx - br), Y(by - br), X(bx + br), Y(by + br)], fill=(235, 252, 255, 220))
    star(d, X(500), Y(380), 62 * k, (255, 220, 110, 255))
    d.ellipse([X(455), Y(300), X(470), Y(315)], fill=(235, 252, 255, 200))
    d.ellipse([X(570), Y(330), X(590), Y(350)], fill=(235, 252, 255, 200))
    # corona pequeña
    pts = [(420, 330), (440, 270), (470, 310), (500, 250), (530, 310), (560, 270), (580, 330)]
    d.polygon([(X(a), Y(b)) for a, b in pts], fill=(255, 205, 80, 255), outline=(160, 110, 20, 255))
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
