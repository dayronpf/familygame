#!/usr/bin/env python3
"""Genera «Holograma en casa» (PDF, tamaño carta, 5 páginas): cómo hacer la pirámide transparente que refleja el modo
holograma de la app. Diseño infantil con los colores de la app y dibujos calculados (no a ojo).

Uso:  python3 tools/guide/make_holograma_pdf.py [salida.pdf]
Por defecto escribe app/assets/guides/holograma-en-casa.pdf (la app lo ofrece para descargar).

Geometría (la misma que `HologramLayout` de la app). Cada cara es un trapecio isósceles: base chica 1 cm (la que va sobre
la pantalla), base grande 6 cm y 3,5 cm de alto. Con esas medidas cada cara queda a 45° de la pantalla
(alto = 2,5 cm × √2 ≈ 3,54 cm) y la abertura chica es 1/6 del lado corto de un móvil de ~6,5 cm (`gap = 0,16` en la app).

Plantilla del teléfono = **una sola pieza** (el «desarrollo» de la pirámide): las cuatro caras unidas por los lados
inclinados forman un abanico alrededor del vértice del triángulo del que sale cada trapecio, más una pestaña para cerrar.
Se recorta una vez, se dobla por tres líneas y se cierra con cinta: más fácil y más exacto que unir cuatro piezas sueltas.
  · el vértice queda a 0,7 cm de la base chica y a 4,2 cm de la base grande (triángulos semejantes: 3,5 × 0,5 / 2,5);
  · cada cara abre 2·atan(3 / 4,2) ≈ 71,08°; las cuatro, ≈ 284,3°.
La de tableta (×2,5) no cabe en una hoja como una pieza: va una cara suelta para calcar cuatro veces.
"""
import math
import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas as rl_canvas
from reportlab.platypus import Paragraph

ROOT = Path(__file__).resolve().parents[2]


def _app_name():
    """El nombre del juego sale de un solo sitio: `app/lib/src/brand.dart` (lo cambia `tools/rename_app.py`)."""
    brand = ROOT / "app/lib/src/brand.dart"
    m = re.search(r"const String appName = '([^']+)';", brand.read_text(encoding="utf-8"))
    return m.group(1) if m else "la app"


APP_NAME = _app_name()
ICON = ROOT / "art/app_icon/icon-1024.png"

FONTS = Path("/usr/share/fonts/truetype/dejavu")
if (FONTS / "DejaVuSans.ttf").exists():  # Linux (CI)
    REGULAR, BOLD = FONTS / "DejaVuSans.ttf", FONTS / "DejaVuSans-Bold.ttf"
else:  # macOS: Arial viene con el sistema
    MAC = Path("/System/Library/Fonts/Supplemental")
    REGULAR, BOLD = MAC / "Arial.ttf", MAC / "Arial Bold.ttf"
pdfmetrics.registerFont(TTFont("Sans", str(REGULAR)))
pdfmetrics.registerFont(TTFont("Sans-Bold", str(BOLD)))
pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold", italic="Sans", boldItalic="Sans-Bold")

# Colores de la app
NIGHT = colors.HexColor("#2A1F5C")
NIGHT2 = colors.HexColor("#4B3A9E")
VIOLET = colors.HexColor("#6B4FD8")
CORAL = colors.HexColor("#FF7A6B")
CORAL_DARK = colors.HexColor("#D9534F")
MINT = colors.HexColor("#8EE3C8")
MINT_DARK = colors.HexColor("#2E9C7B")
SUN = colors.HexColor("#FFD36E")
SUN_LIGHT = colors.HexColor("#FFF3CF")
PINK = colors.HexColor("#FFA8D2")
SKY = colors.HexColor("#6FC3FF")
SKY_LIGHT = colors.HexColor("#E3F3FF")
CREAM = colors.HexColor("#FFF9EC")
LILAC = colors.HexColor("#F1EDFF")
INK = colors.HexColor("#2B2340")
GREY = colors.HexColor("#6A6480")
MOON = colors.HexColor("#FFE7A3")
CHEEK = colors.HexColor("#FFA8A8")

W, H = letter  # 612 × 792 pt
M = 1.4 * cm  # margen

# Geometría de la cara (cm) — teléfono
SMALL, BIG, FACE_H = 1.0, 6.0, 3.5
TABLET = 2.5

BODY = ParagraphStyle("body", fontName="Sans", fontSize=10.5, leading=14.5, textColor=INK, alignment=TA_LEFT)
SMALLP = ParagraphStyle("small", parent=BODY, fontSize=9, leading=12, textColor=GREY)
CENTER = ParagraphStyle("center", parent=BODY, alignment=TA_CENTER)


def fmt(v):
    """Números a la española: 2,5 en vez de 2.5."""
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return s.replace(".", ",")


# ------------------------------------------------------------------ geometría


def net_geometry(scale=1.0):
    """Datos del desarrollo: distancias del vértice a las bases y ángulo de cada cara."""
    hs, hb, h = SMALL / 2 * scale, BIG / 2 * scale, FACE_H * scale
    d_small = h * hs / (hb - hs)  # vértice → base chica, por el eje de la cara
    d_big = d_small + h
    theta = 2 * math.atan(hb / d_big)
    r1 = math.hypot(d_small, hs)  # vértice → esquina chica
    r2 = math.hypot(d_big, hb)  # vértice → esquina grande
    return d_small, d_big, theta, r1, r2


def net_faces(ax, ay, start_deg, scale=1.0):
    """Las cuatro caras del desarrollo (en puntos), con el vértice en (ax, ay). Devuelve (caras, ángulos de los lados)."""
    _, _, theta, r1, r2 = net_geometry(scale)
    angs = [math.radians(start_deg) + i * theta for i in range(5)]

    def p(r, a):
        return (ax + r * cm * math.cos(a), ay + r * cm * math.sin(a))

    faces = [[p(r1, angs[i]), p(r1, angs[i + 1]), p(r2, angs[i + 1]), p(r2, angs[i])] for i in range(4)]
    return faces, angs, r1, r2


def poly(c, pts, fill=None, stroke=None, width=1, dash=None, close=True):
    path = c.beginPath()
    path.moveTo(*pts[0])
    for q in pts[1:]:
        path.lineTo(*q)
    if close:
        path.close()
    c.saveState()
    if dash:
        c.setDash(*dash)
    c.setLineWidth(width)
    if stroke is not None:
        c.setStrokeColor(stroke)
    if fill is not None:
        c.setFillColor(fill)
    c.drawPath(path, stroke=1 if stroke is not None else 0, fill=1 if fill is not None else 0)
    c.restoreState()


def draw_net(c, ax, ay, start_deg, scale=1.0, real=True, numbers=True, tab=True, mini=False):
    """Dibuja el desarrollo: caras de colores, corte por fuera (línea continua), dobleces (puntos) y pestaña."""
    faces, angs, r1, r2 = net_faces(ax, ay, start_deg, scale)
    fills = [SKY_LIGHT, colors.HexColor("#E6FAF3"), colors.HexColor("#FFF0F7"), SUN_LIGHT]
    for f, col in zip(faces, fills):
        poly(c, f, fill=col)
    # Pestaña de pegar en el último lado (por fuera de la cara 4)
    tab_pts = None
    if tab:
        a = angs[4]
        w = 0.75 * scale * cm
        nx, ny = math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)  # hacia fuera del abanico
        p1 = (ax + r1 * cm * math.cos(a), ay + r1 * cm * math.sin(a))
        p2 = (ax + r2 * cm * math.cos(a), ay + r2 * cm * math.sin(a))
        ux, uy = math.cos(a), math.sin(a)
        inset = 0.35 * scale * cm
        tab_pts = [p1, p2,
                   (p2[0] + nx * w - ux * inset, p2[1] + ny * w - uy * inset),
                   (p1[0] + nx * w + ux * inset, p1[1] + ny * w + uy * inset)]
        poly(c, tab_pts, fill=colors.HexColor("#EEEEEE"))
    # Línea de corte: el contorno exterior (bases chicas, bases grandes, primer lado y pestaña)
    lw = 1.6 if real else 1.1
    cut = CORAL_DARK
    for f in faces:
        poly(c, [f[0], f[1]], stroke=cut, width=lw, close=False)  # base chica
        poly(c, [f[2], f[3]], stroke=cut, width=lw, close=False)  # base grande
    poly(c, [faces[0][0], faces[0][3]], stroke=cut, width=lw, close=False)  # primer lado
    if tab_pts:
        poly(c, [tab_pts[1], tab_pts[2], tab_pts[3], tab_pts[0]], stroke=cut, width=lw, close=False)
    else:
        poly(c, [faces[3][1], faces[3][2]], stroke=cut, width=lw, close=False)
    # Dobleces: los tres lados compartidos (y el de la pestaña)
    folds = [(faces[i][1], faces[i][2]) for i in range(3 if not tab_pts else 4)]
    for a_, b_ in folds:
        poly(c, [a_, b_], stroke=VIOLET, width=1.1 if real else 0.8, dash=(2, 2.5), close=False)
    if numbers:
        for i, f in enumerate(faces):
            cx = sum(q[0] for q in f) / 4
            cy = sum(q[1] for q in f) / 4
            rad = (0.42 if not mini else 0.22) * cm
            c.setFillColor(colors.white)
            c.setStrokeColor(VIOLET)
            c.setLineWidth(1)
            c.circle(cx, cy, rad, fill=1, stroke=1)
            c.setFillColor(VIOLET)
            c.setFont("Sans-Bold", 13 if not mini else 7.5)
            c.drawCentredString(cx, cy - (4.5 if not mini else 2.6), str(i + 1))
        if tab_pts and not mini:
            tx = sum(q[0] for q in tab_pts) / 4
            ty = sum(q[1] for q in tab_pts) / 4
            c.saveState()
            c.translate(tx, ty)
            c.rotate(math.degrees(angs[4]))
            c.setFillColor(GREY)
            c.setFont("Sans-Bold", 7.5)
            c.drawCentredString(0, -2.5, "PESTAÑA · cinta aquí")
            c.restoreState()
    return faces, angs, tab_pts


NET_START = None  # se calcula abajo: ángulo con el hueco del abanico hacia abajo


def net_start():
    _, _, theta, _, _ = net_geometry()
    return 270 + (360 - math.degrees(4 * theta)) / 2


def draw_net_fit(c, x, y, w, h, **kw):
    """Dibuja el desarrollo entero (con pestaña) encajado y centrado en la caja (x, y, w, h)."""
    start = net_start()
    faces, angs, r1, r2 = net_faces(0, 0, start, 1.0)
    pts = [q for f in faces for q in f]
    a = angs[4]
    wtab = 0.75 * cm
    pts += [(r2 * cm * math.cos(a) + wtab * math.cos(a + math.pi / 2), r2 * cm * math.sin(a) + wtab * math.sin(a + math.pi / 2))]
    minx, maxx = min(q[0] for q in pts), max(q[0] for q in pts)
    miny, maxy = min(q[1] for q in pts), max(q[1] for q in pts)
    k = min(w / (maxx - minx), h / (maxy - miny))
    ax = x + w / 2 - (minx + maxx) / 2 * k
    ay = y + h / 2 - (miny + maxy) / 2 * k
    return draw_net(c, ax, ay, start, scale=k, real=False, **kw)


# ------------------------------------------------------------------ dibujos sueltos


def star5(c, x, y, r, col):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.5
        pts.append((x + rr * math.cos(a), y - rr * math.sin(a)))
    poly(c, pts, fill=col)


def moon_face(c, x, y, r):
    c.setFillColor(MOON)
    c.circle(x, y, r, fill=1, stroke=0)
    c.setFillColor(colors.HexColor("#F5D27A"))
    c.circle(x - r * 0.45, y + r * 0.42, r * 0.16, fill=1, stroke=0)
    c.setFillColor(INK)
    for dx in (-0.33, 0.33):
        c.circle(x + dx * r, y + r * 0.02, r * 0.09, fill=1, stroke=0)
    c.setFillColor(CHEEK)
    for dx in (-0.55, 0.55):
        c.circle(x + dx * r, y - r * 0.25, r * 0.12, fill=1, stroke=0)
    c.setStrokeColor(INK)
    c.setLineWidth(max(0.8, r * 0.08))
    c.arc(x - r * 0.25, y - r * 0.42, x + r * 0.25, y - r * 0.02, 200, 140)


def rounded(c, x, y, w, h, r=10, fill=None, stroke=None, width=1):
    c.saveState()
    if fill is not None:
        c.setFillColor(fill)
    if stroke is not None:
        c.setStrokeColor(stroke)
        c.setLineWidth(width)
    c.roundRect(x, y, w, h, r, fill=1 if fill is not None else 0, stroke=1 if stroke is not None else 0)
    c.restoreState()


def para(c, text, x, y_top, w, style=BODY):
    """Escribe un párrafo con su esquina superior izquierda en (x, y_top). Devuelve la altura usada."""
    p = Paragraph(text, style)
    _, h = p.wrap(w, 1000)
    p.drawOn(c, x, y_top - h)
    return h


def header(c, title, subtitle=None, big=False):
    """Franja de noche con estrellas, una luna con carita y el título."""
    hh = (4.6 if big else 2.6) * cm
    y = H - hh
    c.setFillColor(NIGHT)
    c.rect(0, y, W, hh, fill=1, stroke=0)
    # borde ondulado abajo
    c.setFillColor(colors.white)
    path = c.beginPath()
    path.moveTo(0, y)
    for i in range(0, 13):
        x0 = i * W / 12
        path.curveTo(x0 + W / 48, y + 8, x0 + W / 16, y + 8, x0 + W / 12, y)
    path.lineTo(W, y - 2)
    path.lineTo(0, y - 2)
    path.close()
    c.drawPath(path, fill=1, stroke=0)
    for sx, sy, sr, col in [(0.80, 0.80, 6, SUN), (0.84, 0.28, 4, PINK), (0.88, 0.86, 3.5, MINT),
                            (0.78, 0.45, 3, SKY), (0.97, 0.30, 4.5, SUN), (0.92, 0.62, 2.5, colors.white)]:
        star5(c, W * sx, y + hh * sy, sr, col)
    moon_face(c, W - 2.2 * cm, y + hh * 0.6, (0.9 if big else 0.62) * cm)
    tx = M
    if big and ICON.exists():
        c.drawImage(str(ICON), M, y + 0.75 * cm, 3.1 * cm, 3.1 * cm, mask="auto")
        tx = M + 3.6 * cm
    c.setFillColor(colors.white)
    c.setFont("Sans-Bold", 30 if big else 22)
    c.drawString(tx, y + hh - (2.0 if big else 1.35) * cm, title)
    if subtitle:
        c.setFillColor(SUN)
        c.setFont("Sans", 12 if big else 10.5)
        c.drawString(tx, y + hh - (2.75 if big else 2.0) * cm, subtitle)
    return y - 0.5 * cm


def footer(c, page):
    c.setFillColor(GREY)
    c.setFont("Sans", 8.5)
    c.drawString(M, 0.9 * cm, f"Holograma en casa · {APP_NAME}")
    c.drawRightString(W - M, 0.9 * cm, f"Página {page} · Imprime en tamaño carta, al 100 %")
    for i, col in enumerate([CORAL, SUN, MINT, SKY, PINK]):
        c.setFillColor(col)
        c.circle(W / 2 - 2 * 9 + i * 9, 0.98 * cm, 2.6, fill=1, stroke=0)


def project(x, y, z, s, ox, oy):
    """Proyección oblicua sencilla (para los dibujos 3D): x a la derecha, y hacia el fondo, z hacia arriba."""
    return (ox + (x + 0.55 * y) * s, oy + (z + 0.35 * y) * s)


def draw_phone_and_pyramid(c, ox, oy, s, figure=True):
    """Un teléfono acostado y la pirámide encima, boca abajo (la abertura chica sobre la pantalla), en 3D."""
    # teléfono: 7 × 14 (x por y), grosor 0.4
    pw, pl = 7.0, 12.0
    cx, cy = pw / 2, pl / 2
    body = [project(0, 0, 0, s, ox, oy), project(pw, 0, 0, s, ox, oy), project(pw, pl, 0, s, ox, oy), project(0, pl, 0, s, ox, oy)]
    side = [project(0, 0, 0, s, ox, oy), project(pw, 0, 0, s, ox, oy), project(pw, 0, -0.45, s, ox, oy), project(0, 0, -0.45, s, ox, oy)]
    poly(c, side, fill=colors.HexColor("#1B1438"))
    side2 = [project(pw, 0, 0, s, ox, oy), project(pw, pl, 0, s, ox, oy), project(pw, pl, -0.45, s, ox, oy), project(pw, 0, -0.45, s, ox, oy)]
    poly(c, side2, fill=colors.HexColor("#120D28"))
    poly(c, body, fill=NIGHT, stroke=colors.HexColor("#120D28"), width=1)
    screen = [project(0.35, 0.6, 0.01, s, ox, oy), project(pw - 0.35, 0.6, 0.01, s, ox, oy),
              project(pw - 0.35, pl - 0.6, 0.01, s, ox, oy), project(0.35, pl - 0.6, 0.01, s, ox, oy)]
    poly(c, screen, fill=colors.HexColor("#120B2E"))
    # las cuatro copias del cuento en la pantalla (lunitas alrededor del centro)
    for dx, dy in [(0, -3.4), (0, 3.4), (-2.3, 0), (2.3, 0)]:
        px, py = project(cx + dx, cy + dy, 0.02, s, ox, oy)
        c.setFillColor(MOON)
        c.circle(px, py, 0.45 * s, fill=1, stroke=0)
    # pirámide: base chica (1) en z=0, base grande (6) en z=2.5
    hs, hb, hz = 0.5, 3.0, 2.5
    lo = [(cx - hs, cy - hs), (cx + hs, cy - hs), (cx + hs, cy + hs), (cx - hs, cy + hs)]
    hi = [(cx - hb, cy - hb), (cx + hb, cy - hb), (cx + hb, cy + hb), (cx - hb, cy + hb)]
    L = [project(x, y, 0.02, s, ox, oy) for x, y in lo]
    U = [project(x, y, hz, s, ox, oy) for x, y in hi]
    glass = colors.Color(0.75, 0.88, 1.0, alpha=0.35)
    edge = colors.HexColor("#5B8FD6")
    # caras traseras primero
    for i in (2, 3):
        j = (i + 1) % 4
        poly(c, [L[i], L[j], U[j], U[i]], fill=glass)
    if figure:
        fx, fy = project(cx, cy, 1.45, s, ox, oy)
        c.setFillColor(colors.Color(1, 0.93, 0.7, alpha=0.35))
        c.circle(fx, fy, 1.05 * s, fill=1, stroke=0)
        moon_face(c, fx, fy, 0.62 * s)
    for i in (0, 1):
        j = (i + 1) % 4
        poly(c, [L[i], L[j], U[j], U[i]], fill=glass)
    for i in range(4):
        poly(c, [L[i], U[i]], stroke=edge, width=1.2, close=False)
    poly(c, U, stroke=edge, width=1.4)
    poly(c, L, stroke=edge, width=1.2)
    return U, L


def ruler(c, x, y):
    """Regla de 5 cm y un cuadrado de 1 cm para comprobar la escala."""
    rounded(c, x - 0.5 * cm, y - 0.9 * cm, 7.0 * cm, 1.75 * cm, r=8, fill=SUN_LIGHT, stroke=SUN, width=1)
    c.setStrokeColor(INK)
    c.setLineWidth(1.2)
    c.line(x, y, x + 5 * cm, y)
    c.setFont("Sans", 8)
    c.setFillColor(INK)
    for i in range(6):
        c.line(x + i * cm, y - 4, x + i * cm, y + 4)
        c.drawCentredString(x + i * cm, y - 13, str(i))
    c.setLineWidth(0.6)
    for i in range(5):
        c.line(x + (i + 0.5) * cm, y - 2, x + (i + 0.5) * cm, y + 2)
    c.drawString(x + 5.2 * cm, y - 3, "cm")
    c.setFont("Sans-Bold", 8.5)
    c.drawString(x - 0.2 * cm, y + 0.5 * cm, "¿Imprimiste bien? Esta regla mide 5 cm.")


def dim_h(c, x1, x2, y, label):
    c.setStrokeColor(GREY)
    c.setFillColor(GREY)
    c.setLineWidth(0.8)
    c.line(x1, y, x2, y)
    for x, d in ((x1, 1), (x2, -1)):
        poly(c, [(x, y), (x + d * 6, y + 3), (x + d * 6, y - 3)], fill=GREY)
    c.setFont("Sans-Bold", 9)
    w = c.stringWidth(label, "Sans-Bold", 9)
    c.setFillColor(colors.white)
    c.rect((x1 + x2) / 2 - w / 2 - 3, y - 5, w + 6, 10, fill=1, stroke=0)
    c.setFillColor(INK)
    c.drawCentredString((x1 + x2) / 2, y - 3.2, label)


def dim_v(c, x, y1, y2, label):
    c.setStrokeColor(GREY)
    c.setLineWidth(0.8)
    c.line(x, y1, x, y2)
    for y, d in ((y1, 1), (y2, -1)):
        poly(c, [(x, y), (x + 3, y + d * 6), (x - 3, y + d * 6)], fill=GREY)
    c.saveState()
    c.translate(x, (y1 + y2) / 2)
    c.rotate(90)
    c.setFont("Sans-Bold", 9)
    w = c.stringWidth(label, "Sans-Bold", 9)
    c.setFillColor(colors.white)
    c.rect(-w / 2 - 3, -5, w + 6, 10, fill=1, stroke=0)
    c.setFillColor(INK)
    c.drawCentredString(0, -3.2, label)
    c.restoreState()


def scissors(c, x, y, s=1.0, col=CORAL_DARK):
    c.setStrokeColor(col)
    c.setLineWidth(1.6 * s)
    c.circle(x, y + 5 * s, 3.6 * s, fill=0, stroke=1)
    c.circle(x, y - 5 * s, 3.6 * s, fill=0, stroke=1)
    c.line(x + 3 * s, y + 3 * s, x + 18 * s, y - 6 * s)
    c.line(x + 3 * s, y - 3 * s, x + 18 * s, y + 6 * s)


# ------------------------------------------------------------------ iconos de materiales


def icon_sheet(c, x, y):
    poly(c, [(x - 16, y - 14), (x + 12, y - 18), (x + 16, y + 14), (x - 12, y + 18)],
         fill=colors.Color(0.75, 0.88, 1, alpha=0.6), stroke=colors.HexColor("#5B8FD6"), width=1.2)
    c.setStrokeColor(colors.white)
    c.setLineWidth(2)
    c.line(x - 6, y + 8, x + 4, y + 10)


def icon_scissors(c, x, y):
    scissors(c, x - 9, y, 1.0)


def icon_tape(c, x, y):
    c.setFillColor(SUN)
    c.circle(x, y, 13, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.circle(x, y, 6, fill=1, stroke=0)
    poly(c, [(x + 8, y - 10), (x + 22, y - 14), (x + 22, y - 8), (x + 10, y - 4)], fill=SUN)


def icon_marker(c, x, y):
    c.saveState()
    c.translate(x, y)
    c.rotate(35)
    rounded(c, -18, -5, 30, 10, r=3, fill=VIOLET)
    rounded(c, 10, -4, 6, 8, r=2, fill=INK)
    poly(c, [(16, -2), (21, 0), (16, 2)], fill=INK)
    c.restoreState()


def icon_ruler(c, x, y):
    c.saveState()
    c.translate(x, y)
    c.rotate(-20)
    rounded(c, -20, -6, 40, 12, r=2, fill=MINT, stroke=MINT_DARK, width=1)
    c.setStrokeColor(MINT_DARK)
    for i in range(-16, 18, 5):
        c.line(i, 6, i, 1)
    c.restoreState()


def icon_template(c, x, y):
    rounded(c, x - 14, y - 18, 28, 36, r=2, fill=colors.white, stroke=GREY, width=0.8)
    draw_net_fit(c, x - 12, y - 14, 24, 26, numbers=False)


def icon_cloth(c, x, y):
    poly(c, [(x - 16, y - 10), (x + 14, y - 14), (x + 16, y + 10), (x - 12, y + 14)], fill=PINK)
    c.setStrokeColor(colors.white)
    c.setLineWidth(1)
    for i in range(-10, 14, 6):
        c.line(x + i, y - 11, x + i + 2, y + 11)


def icon_lamp(c, x, y):
    c.setFillColor(NIGHT)
    c.circle(x, y, 15, fill=1, stroke=0)
    moon_face(c, x, y, 8)


# ------------------------------------------------------------------ páginas


def page_cover(c):
    y = header(c, "¡Haz tu holograma!", f"Una pirámide transparente que hace flotar los cuentos de {APP_NAME}", big=True)
    # Ilustración grande
    draw_phone_and_pyramid(c, M + 0.2 * cm, y - 6.4 * cm, 0.6 * cm)
    para(c, "<b>Así queda:</b> una pirámide de plástico transparente, <b>boca abajo</b>, con la abertura chica "
            "apoyada en el centro de la pantalla. Las cuatro copias del cuento que dibuja la app se reflejan en sus caras "
            "y el personaje parece flotar dentro.", W * 0.60, y - 1.2 * cm, W * 0.40 - M, BODY)
    # Aviso de adulto
    by = y - 8.3 * cm
    rounded(c, M, by - 2.3 * cm, W - 2 * M, 2.3 * cm, r=14, fill=colors.HexColor("#FFE9E5"), stroke=CORAL, width=1.5)
    poly(c, [(M + 0.55 * cm, by - 1.75 * cm), (M + 1.55 * cm, by - 1.75 * cm), (M + 1.05 * cm, by - 0.75 * cm)], fill=CORAL)
    c.setFillColor(colors.white)
    c.setFont("Sans-Bold", 14)
    c.drawCentredString(M + 1.05 * cm, by - 1.6 * cm, "!")
    para(c, "<b>Con un adulto, siempre.</b> Hay que usar <b>tijeras</b> y el plástico recortado puede tener bordes filosos. "
            "El adulto corta; los niños (desde 6 años) pueden marcar, doblar y pegar la cinta. Trabajen sobre una mesa "
            "despejada y guarden las tijeras al terminar.", M + 2.0 * cm, by - 0.35 * cm, W - 2 * M - 2.4 * cm, BODY)
    # Materiales
    my = by - 3.0 * cm
    c.setFillColor(VIOLET)
    c.setFont("Sans-Bold", 16)
    c.drawString(M, my, "Qué necesitas")
    items = [
        (icon_sheet, "Plástico transparente", "Acetato, cubierta de carpeta o la tapa de una caja de CD. Liso, sin color."),
        (icon_template, "Esta plantilla", "Impresa en papel carta, al 100 % (página 4 o 5)."),
        (icon_scissors, "Tijeras", "Las usa el adulto."),
        (icon_marker, "Marcador fino", "Que escriba sobre plástico."),
        (icon_tape, "Cinta transparente", "La «mágica» o una fina de embalar."),
        (icon_ruler, "Regla", "Para comprobar la escala."),
        (icon_cloth, "Un paño suave", "Recomendado: quita las huellas."),
        (icon_lamp, "Cuarto a media luz", "Y la pantalla con el brillo al máximo."),
    ]
    cols, cw, ch = 2, (W - 2 * M - 0.5 * cm) / 2, 1.6 * cm
    for i, (ico, name, note) in enumerate(items):
        col, row = i % cols, i // cols
        x = M + col * (cw + 0.5 * cm)
        yy = my - 0.45 * cm - (row + 1) * (ch + 0.25 * cm)
        rounded(c, x, yy, cw, ch, r=12, fill=[SKY_LIGHT, LILAC, SUN_LIGHT, colors.HexColor("#E6FAF3")][(i + row) % 4])
        ico(c, x + 0.95 * cm, yy + ch / 2)
        c.setFillColor(INK)
        c.setFont("Sans-Bold", 10.5)
        c.drawString(x + 1.9 * cm, yy + ch - 0.55 * cm, name)
        para(c, note, x + 1.9 * cm, yy + ch - 0.72 * cm, cw - 2.1 * cm, SMALLP)
    c.setFillColor(GREY)
    c.setFont("Sans", 9.5)
    c.drawString(M, 2.0 * cm, "Tiempo: 20–30 minutos.  Costo: casi nada si reutilizas plástico que ya tengas en casa.")
    footer(c, 1)


def step_card(c, x, y, w, h, n, title, text, draw, col):
    rounded(c, x, y, w, h, r=14, fill=col)
    c.setFillColor(VIOLET)
    c.circle(x + 0.75 * cm, y + h - 0.75 * cm, 0.45 * cm, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("Sans-Bold", 14)
    c.drawCentredString(x + 0.75 * cm, y + h - 0.92 * cm, str(n))
    c.setFillColor(INK)
    c.setFont("Sans-Bold", 11.5)
    c.drawString(x + 1.45 * cm, y + h - 0.88 * cm, title)
    para(c, text, x + 0.4 * cm, y + h - 1.4 * cm, w * 0.52, SMALLP)
    draw(c, x + w * 0.56, y + 0.35 * cm, w * 0.42, h - 1.55 * cm)


def page_steps(c):
    y = header(c, "Paso a paso", "Léanlo completo antes de empezar")
    gx, gw = M, (W - 2 * M - 0.4 * cm) / 2
    ch = 5.3 * cm

    def d_print(c, x, y, w, h):
        pw = min(w * 0.7, h * 0.78)
        px = x + (w - pw) / 2
        rounded(c, px, y, pw, h, r=4, fill=colors.white, stroke=GREY, width=0.8)
        draw_net_fit(c, px + 4, y + 0.55 * cm, pw - 8, h - 0.75 * cm, numbers=False)
        c.setFillColor(CORAL_DARK)
        c.setFont("Sans-Bold", 10)
        c.drawCentredString(px + pw / 2, y + 0.18 * cm, "100 %")

    def d_cut_paper(c, x, y, w, h):
        draw_net_fit(c, x + 0.5 * cm, y, w - 0.5 * cm, h, numbers=False)
        scissors(c, x + 0.2 * cm, y + h - 0.3 * cm, 1.0)

    def d_trace(c, x, y, w, h):
        poly(c, [(x, y + 0.1 * cm), (x + w - 0.2 * cm, y), (x + w, y + h - 0.1 * cm), (x + 0.2 * cm, y + h)],
             fill=colors.Color(0.75, 0.88, 1, alpha=0.5), stroke=colors.HexColor("#5B8FD6"), width=1)
        draw_net_fit(c, x + 0.3 * cm, y + 0.2 * cm, w - 0.6 * cm, h - 0.4 * cm, numbers=False)
        icon_marker(c, x + w - 0.5 * cm, y + h - 0.6 * cm)

    def d_fold(c, x, y, w, h):
        faces, angs, _ = draw_net_fit(c, x, y, w, h, numbers=True, mini=True)
        c.setStrokeColor(VIOLET)
        c.setLineWidth(1.2)
        for i in range(3):
            mx = (faces[i][1][0] + faces[i][2][0]) / 2
            my = (faces[i][1][1] + faces[i][2][1]) / 2
            c.arc(mx - 6, my - 6, mx + 6, my + 6, 20, 250)

    def d_close(c, x, y, w, h):
        x, y = x + w / 2, y + h / 2
        # pirámide boca abajo con la cinta en la última unión
        s = 0.42 * cm
        hs, hb, hz = 0.5, 3.0, 2.5
        lo = [(-hs, -hs), (hs, -hs), (hs, hs), (-hs, hs)]
        hi = [(-hb, -hb), (hb, -hb), (hb, hb), (-hb, hb)]
        ox, oy = x - 0.4 * cm, y - 1.0 * cm
        Lp = [project(a, b, 0, s, ox, oy) for a, b in lo]
        Up = [project(a, b, hz, s, ox, oy) for a, b in hi]
        glass = colors.Color(0.75, 0.88, 1.0, alpha=0.45)
        for i in range(4):
            j = (i + 1) % 4
            poly(c, [Lp[i], Lp[j], Up[j], Up[i]], fill=glass, stroke=colors.HexColor("#5B8FD6"), width=0.9)
        a, b = Lp[1], Up[1]
        c.setStrokeColor(SUN)
        c.setLineWidth(6)
        c.line(a[0], a[1], b[0], b[1])

    def d_place(c, x, y, w, h):
        k = min(w / 13.8, h / 6.9)
        draw_phone_and_pyramid(c, x + (w - 13.6 * k) / 2, y + 0.45 * k + (h - 6.9 * k) / 2, k)

    steps = [
        ("Imprime la plantilla", "Papel <b>carta</b>, escala <b>100 %</b> («tamaño real»), nunca «ajustar a la página». "
         "Mide la regla: debe dar <b>5 cm</b>. Teléfono: página 4. Tableta: página 5.", d_print, SKY_LIGHT),
        ("Recorta el molde de papel", "El adulto recorta la pieza de papel por la <b>línea roja</b>, con la pestaña gris incluida.",
         d_cut_paper, LILAC),
        ("Cálcala en el plástico", "Quita la película protectora del plástico. Pon el molde encima y repasa el contorno "
         "y las <b>líneas de puntos</b> con el marcador.", d_trace, SUN_LIGHT),
        ("Recorta y dobla", "El adulto corta por la línea del marcador y redondea apenas las puntas. Dobla por las "
         "<b>tres líneas de puntos</b>, siempre hacia el mismo lado.", d_fold, colors.HexColor("#E6FAF3")),
        ("Cierra con cinta", "Junta la cara 1 con la pestaña y pégala con <b>cinta por fuera</b>, a todo lo largo. "
         "Queda una pirámide sin punta: abertura chica de 1 cm y grande de 6 cm.", d_close, colors.HexColor("#FFF0F7")),
        ("Ponla sobre la pantalla", "En el cuento, toca el <b>holograma</b> (el cubito) y apaga la luz. Apoya la abertura "
         "chica sobre el <b>cuadrado del centro</b> y ajusta con + y −.", d_place, SKY_LIGHT),
    ]
    for i, (t, txt, d, col) in enumerate(steps):
        colx = gx + (i % 2) * (gw + 0.4 * cm)
        row = i // 2
        yy = y - (row + 1) * (ch + 0.35 * cm)
        step_card(c, colx, yy, gw, ch, i + 1, t, txt, d, col)
    yb = y - 3 * (ch + 0.35 * cm) - 0.4 * cm
    rounded(c, M, yb - 1.6 * cm, W - 2 * M, 1.6 * cm, r=12, fill=SUN_LIGHT, stroke=SUN, width=1)
    para(c, "<b>¿Sin impresora?</b> Dibuja un trapecio a mano: base de <b>6 cm</b>, base de <b>1 cm</b> centrada debajo y "
            "<b>3,5 cm</b> de alto. Cálcalo cuatro veces en el plástico y une las caras con cinta por los lados inclinados.",
         M + 0.4 * cm, yb - 0.3 * cm, W - 2 * M - 0.8 * cm, BODY)
    footer(c, 2)


def page_watch(c):
    y = header(c, "A mirar el holograma", "Cada cara refleja una de las cuatro copias del cuento")
    # Corte de lado, a escala (cara a 45°)
    s = 0.95 * cm
    ox, oy = W / 2 - 1.0 * cm, y - 3.6 * cm
    rounded(c, ox - 5.2 * s, oy - 0.55 * s, 10.4 * s, 0.55 * s, r=4, fill=NIGHT)
    c.setFillColor(MOON)
    for dx in (-2.4, 2.4):
        c.circle(ox + dx * s, oy - 0.1 * s, 0.25 * s, fill=1, stroke=0)
    sec = [(ox - 0.5 * s, oy), (ox + 0.5 * s, oy), (ox + 3.0 * s, oy + 2.5 * s), (ox - 3.0 * s, oy + 2.5 * s)]
    poly(c, sec, fill=colors.Color(0.75, 0.88, 1.0, alpha=0.45), stroke=colors.HexColor("#5B8FD6"), width=1.6)
    moon_face(c, ox, oy + 1.35 * s, 0.5 * s)
    # mirada
    c.setStrokeColor(GREY)
    c.setDash(3, 3)
    c.setLineWidth(1)
    c.line(ox + 0.5 * s, oy + 1.35 * s, ox + 6.0 * s, oy + 1.35 * s)
    c.setDash()
    c.setFillColor(INK)
    c.circle(ox + 6.4 * s, oy + 1.35 * s, 0.32 * s, fill=0, stroke=1)
    c.circle(ox + 6.33 * s, oy + 1.35 * s, 0.12 * s, fill=1, stroke=0)
    c.setFont("Sans-Bold", 9)
    c.drawString(ox + 5.6 * s, oy + 2.0 * s, "tus ojos, de lado")
    c.drawRightString(ox - 3.4 * s, oy + 1.25 * s, "el cuento «flota» dentro")
    c.setStrokeColor(GREY)
    c.line(ox - 3.3 * s, oy + 1.35 * s, ox - 0.6 * s, oy + 1.35 * s)
    c.setFont("Sans", 8.5)
    c.setFillColor(GREY)
    c.drawCentredString(ox, oy - 1.1 * s, "Vista de lado, a escala: cada cara forma 45° con la pantalla")
    # consejos
    ty = oy - 1.8 * s
    c.setFillColor(VIOLET)
    c.setFont("Sans-Bold", 16)
    c.drawString(M, ty, "Para que se vea mejor")
    tips = [
        (NIGHT, "A media luz", "Cuanto más oscuro el cuarto, más nítido. Brillo de la pantalla al máximo."),
        (SKY, "Centrada", "La abertura chica justo sobre el cuadrado del centro. Si se corre, la figura se desdobla."),
        (PINK, "Limpia", "Las huellas se notan mucho: pásale el paño antes de mirar."),
        (MINT_DARK, "A la altura de los ojos", "A unos 30–50 cm, mirando de lado. Descansen la vista cada 10 minutos."),
    ]
    cw = (W - 2 * M - 0.4 * cm) / 2
    for i, (col, t, d) in enumerate(tips):
        x = M + (i % 2) * (cw + 0.4 * cm)
        yy = ty - 0.4 * cm - (i // 2 + 1) * 1.75 * cm
        rounded(c, x, yy, cw, 1.55 * cm, r=12, fill=LILAC)
        c.setFillColor(col)
        c.circle(x + 0.7 * cm, yy + 0.78 * cm, 0.35 * cm, fill=1, stroke=0)
        c.setFillColor(INK)
        c.setFont("Sans-Bold", 10.5)
        c.drawString(x + 1.3 * cm, yy + 1.05 * cm, t)
        para(c, d, x + 1.3 * cm, yy + 0.92 * cm, cw - 1.5 * cm, SMALLP)
    # problemas
    py = ty - 0.4 * cm - 2 * 1.75 * cm - 0.8 * cm
    c.setFillColor(VIOLET)
    c.setFont("Sans-Bold", 16)
    c.drawString(M, py, "Si algo no se ve bien")
    rows = [
        ("Se ve de cabeza", "En los controles del holograma, toca «Pies hacia dentro o fuera»."),
        ("Izquierda y derecha al revés", "Toca «Reflejar izquierda y derecha»."),
        ("Muy chica o cortada", "Ajusta con + y − hasta que el cuadrado coincida con la abertura chica."),
        ("Borrosa", "Limpia el plástico, quita la película protectora, sube el brillo y apaga la luz."),
        ("Una cara se ve distinta", "Revisa que la cinta no tape la imagen y que los dobleces estén parejos."),
        ("Mi pantalla es más grande", "Usa la plantilla de tableta (página 5). La abertura chica = 1/6 del lado corto."),
    ]
    yy = py - 0.35 * cm
    for i, (a, b) in enumerate(rows):
        rh = 0.95 * cm
        yy -= rh
        rounded(c, M, yy, W - 2 * M, rh - 0.12 * cm, r=8, fill=SKY_LIGHT if i % 2 == 0 else colors.white,
                stroke=colors.HexColor("#D6E6F5"), width=0.6)
        c.setFillColor(INK)
        c.setFont("Sans-Bold", 9.5)
        c.drawString(M + 0.35 * cm, yy + 0.3 * cm, a)
        c.setFont("Sans", 9.5)
        c.drawString(M + 5.9 * cm, yy + 0.3 * cm, b)
    footer(c, 3)


def page_template_phone(c):
    y = header(c, "Plantilla · teléfono", "Para móviles de hasta ~7 cm de ancho · una sola pieza")
    para(c, "Recorta por la <b><font color='#D9534F'>línea roja</font></b>, dobla por las "
            "<b><font color='#6B4FD8'>líneas de puntos</font></b> y cierra pegando la cara 1 sobre la "
            "<b>pestaña gris</b>. Cada cara mide <b>6 cm</b> arriba, <b>1 cm</b> abajo y <b>3,5 cm</b> de alto.",
         M, y - 0.1 * cm, W - 2 * M, BODY)
    # El abanico centrado: vértice y ángulo de inicio para que el hueco quede abajo
    _, _, theta, r1, r2 = net_geometry()
    span = 4 * theta
    start = 270 + (360 - math.degrees(span)) / 2
    ax, ay = W / 2, y - 7.4 * cm
    faces, angs, tab_pts = draw_net(c, ax, ay, start)
    scissors(c, faces[3][2][0] - 0.9 * cm, faces[3][2][1] + 0.1 * cm, 1.1)
    # Cotas de la cara 2 (arriba)
    f = faces[1]
    a_top = (angs[1] + angs[2]) / 2
    c.saveState()
    c.translate(ax, ay)
    c.rotate(math.degrees(a_top) - 90)
    d_small, d_big, _, _, _ = net_geometry()
    dim_h(c, -BIG / 2 * cm, BIG / 2 * cm, (d_big + 0.45) * cm, "6 cm")
    dim_v(c, (BIG / 2 + 0.7) * cm, d_small * cm, d_big * cm, "3,5 cm")
    c.restoreState()
    # leyenda
    ly = 6.2 * cm
    rounded(c, M, ly - 0.2 * cm, 7.6 * cm, 1.4 * cm, r=10, fill=LILAC)
    c.setStrokeColor(CORAL_DARK)
    c.setLineWidth(1.6)
    c.line(M + 0.4 * cm, ly + 0.8 * cm, M + 1.4 * cm, ly + 0.8 * cm)
    c.setFillColor(INK)
    c.setFont("Sans", 9)
    c.drawString(M + 1.6 * cm, ly + 0.7 * cm, "recortar")
    c.setStrokeColor(VIOLET)
    c.setLineWidth(1.1)
    c.setDash(2, 2.5)
    c.line(M + 0.4 * cm, ly + 0.25 * cm, M + 1.4 * cm, ly + 0.25 * cm)
    c.setDash()
    c.drawString(M + 1.6 * cm, ly + 0.15 * cm, "doblar")
    c.setFillColor(colors.HexColor("#EEEEEE"))
    c.rect(M + 3.6 * cm, ly + 0.55 * cm, 1 * cm, 0.5 * cm, fill=1, stroke=0)
    c.setFillColor(INK)
    c.drawString(M + 4.8 * cm, ly + 0.7 * cm, "pestaña (cinta)")
    ruler(c, W - M - 7.0 * cm, 2.6 * cm)
    c.setStrokeColor(INK)
    c.setLineWidth(1)
    c.rect(M, 2.2 * cm, 1 * cm, 1 * cm, fill=0, stroke=1)
    c.setFont("Sans", 8.5)
    c.drawString(M + 1.25 * cm, 2.55 * cm, "= 1 cm × 1 cm")
    footer(c, 4)


def page_template_tablet(c):
    y = header(c, "Plantilla · tableta", "Lado corto de la pantalla de ~15 a 17 cm · es la del teléfono ×2,5")
    para(c, "La pieza entera no cabe en una hoja: recorta esta <b>cara</b> en papel, cálcala <b>cuatro veces</b> en el "
            "plástico y une las caras con cinta por los lados inclinados (paso 5). Mide "
            f"<b>{fmt(BIG * TABLET)} cm</b> arriba, <b>{fmt(SMALL * TABLET)} cm</b> abajo y "
            f"<b>{fmt(FACE_H * TABLET)} cm</b> de alto.", M, y - 0.1 * cm, W - 2 * M, BODY)
    big, small, h = BIG * TABLET * cm, SMALL * TABLET * cm, FACE_H * TABLET * cm
    cx, top = W / 2, y - 2.6 * cm
    pts = [(cx - big / 2, top), (cx + big / 2, top), (cx + small / 2, top - h), (cx - small / 2, top - h)]
    poly(c, pts, fill=SKY_LIGHT, stroke=CORAL_DARK, width=1.6)
    moon_face(c, cx, top - h * 0.42, 1.0 * cm)
    star5(c, cx - 3.2 * cm, top - 1.6 * cm, 9, SUN)
    star5(c, cx + 3.4 * cm, top - 1.9 * cm, 7, PINK)
    star5(c, cx + 1.8 * cm, top - 5.3 * cm, 6, MINT_DARK)
    dim_h(c, cx - big / 2, cx + big / 2, top + 0.5 * cm, f"{fmt(BIG * TABLET)} cm")
    dim_h(c, cx - small / 2, cx + small / 2, top - h - 0.5 * cm, f"{fmt(SMALL * TABLET)} cm")
    dim_v(c, cx + big / 2 + 0.6 * cm, top - h, top, f"{fmt(FACE_H * TABLET)} cm")
    scissors(c, cx - big / 2 - 0.9 * cm, top + 0.1 * cm, 1.1)
    c.setFillColor(GREY)
    c.setFont("Sans-Bold", 10)
    c.drawCentredString(cx, top - h + 1.0 * cm, "CARA · haz 4 iguales")
    ruler(c, W - M - 7.0 * cm, 2.6 * cm)
    c.setStrokeColor(INK)
    c.setLineWidth(1)
    c.rect(M, 2.2 * cm, 1 * cm, 1 * cm, fill=0, stroke=1)
    c.setFont("Sans", 8.5)
    c.drawString(M + 1.25 * cm, 2.55 * cm, "= 1 cm × 1 cm")
    footer(c, 5)


def build(out: Path):
    c = rl_canvas.Canvas(str(out), pagesize=letter)
    c.setTitle(f"Holograma en casa · {APP_NAME}")
    c.setAuthor(APP_NAME)
    c.setSubject("Cómo hacer la pirámide del holograma, con plantillas a escala real")
    for page in (page_cover, page_steps, page_watch, page_template_phone, page_template_tablet):
        page(c)
        c.showPage()
    c.save()


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "app/assets/guides/holograma-en-casa.pdf"
    out.parent.mkdir(parents=True, exist_ok=True)
    build(out)
    print(out)
