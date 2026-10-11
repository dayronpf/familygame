#!/usr/bin/env python3
"""Genera «Holograma en casa» (PDF, tamaño carta): cómo hacer la pirámide invertida que refleja el modo holograma de
la app, con lista de materiales, aviso de adulto y plantillas a escala 100 % para recortar.

Uso:  python3 tools/guide/make_holograma_pdf.py [salida.pdf]
Por defecto escribe app/assets/guides/holograma-en-casa.pdf (la app lo ofrece para descargar).

Geometría (la misma que `HologramLayout` de la app): cada cara es un trapecio con la base chica de 1 cm (la que
descansa sobre la pantalla), la base grande de 6 cm y 3,5 cm de alto. Con esas medidas la cara queda a 45° y la
base chica es 1/6 del lado corto de un móvil de ~6,5 cm (en la app, el valor por defecto `gap = 0,16`).
La plantilla grande (×2,5) es para tabletas (lado corto ≈ 15–16 cm).
"""
import math
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, Flowable, Frame, KeepTogether, PageBreak, PageTemplate, Paragraph,
                                Spacer, Table, TableStyle)

APP_NAME = "Caldero de Cuentos"  # si el juego cambia de nombre, se cambia aquí y se vuelve a generar
FONTS = Path("/usr/share/fonts/truetype/dejavu")
pdfmetrics.registerFont(TTFont("Sans", str(FONTS / "DejaVuSans.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Bold", str(FONTS / "DejaVuSans-Bold.ttf")))
pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold", italic="Sans", boldItalic="Sans-Bold")

INDIGO = colors.HexColor("#241A5A")
VIOLET = colors.HexColor("#6B4FD8")
AMBER = colors.HexColor("#FFC857")
AMBER_DARK = colors.HexColor("#8A5A00")
SOFT = colors.HexColor("#F1EDFF")
WARN_BG = colors.HexColor("#FFF1D6")
WARN_LINE = colors.HexColor("#E08A00")
GREY = colors.HexColor("#5A5670")

BASE_SMALL, BASE_BIG, HEIGHT = 1.0, 6.0, 3.5  # cm, plantilla de teléfono
SCALE_L = 2.5  # tableta

H1 = ParagraphStyle("h1", fontName="Sans-Bold", fontSize=24, leading=28, textColor=INDIGO, spaceAfter=4)
SUB = ParagraphStyle("sub", fontName="Sans", fontSize=11.5, leading=16, textColor=GREY, spaceAfter=10)
H2 = ParagraphStyle("h2", fontName="Sans-Bold", fontSize=15, leading=19, textColor=VIOLET, spaceBefore=10, spaceAfter=5)
BODY = ParagraphStyle("body", fontName="Sans", fontSize=10.5, leading=15, textColor=colors.black, alignment=TA_LEFT)
SMALL = ParagraphStyle("small", parent=BODY, fontSize=9, leading=12.5, textColor=GREY)
BUL = ParagraphStyle("bul", parent=BODY, leftIndent=14, bulletIndent=2, spaceAfter=2)
STEP = ParagraphStyle("step", parent=BODY, leftIndent=0, spaceAfter=0)
WARN = ParagraphStyle("warn", parent=BODY, fontSize=10.5, leading=15)


def bullets(items):
    return [Paragraph(t, BUL, bulletText="•") for t in items]


class Box(Flowable):
    """Cuadro de color con contenido (lista de flowables) y borde."""

    def __init__(self, content, bg, line, width, pad=10):
        super().__init__()
        self.content, self.bg, self.line, self.w, self.pad = content, bg, line, width, pad
        self._h = 0

    def wrap(self, aw, ah):
        self.w = min(self.w, aw)
        h = self.pad * 2
        self._sizes = []
        for f in self.content:
            _, fh = f.wrap(self.w - self.pad * 2, ah)
            self._sizes.append(fh)
            h += fh
        self._h = h
        return self.w, h

    def draw(self):
        c = self.canv
        c.setFillColor(self.bg)
        c.setStrokeColor(self.line)
        c.setLineWidth(1.6)
        c.roundRect(0, 0, self.w, self._h, 8, fill=1, stroke=1)
        y = self._h - self.pad
        for f, fh in zip(self.content, self._sizes):
            y -= fh
            f.drawOn(c, self.pad, y)


# ------------------------------------------------------------------ dibujos
def trapezoid(c, cx, y0, small, big, h, fill=None, stroke=colors.black, width=1.2, dash=None):
    """Trapecio isósceles con la base grande arriba. (cx, y0) = centro de la base chica (abajo)."""
    p = c.beginPath()
    p.moveTo(cx - small / 2, y0)
    p.lineTo(cx + small / 2, y0)
    p.lineTo(cx + big / 2, y0 + h)
    p.lineTo(cx - big / 2, y0 + h)
    p.close()
    c.setLineWidth(width)
    c.setStrokeColor(stroke)
    if dash:
        c.setDash(*dash)
    if fill is not None:
        c.setFillColor(fill)
    c.drawPath(p, fill=1 if fill is not None else 0, stroke=1)
    c.setDash()


def arrow_h(c, x1, x2, y, label, size=8.5):
    c.setStrokeColor(GREY)
    c.setFillColor(GREY)
    c.setLineWidth(0.7)
    c.line(x1, y, x2, y)
    for x, d in ((x1, 1), (x2, -1)):
        p = c.beginPath()
        p.moveTo(x, y)
        p.lineTo(x + d * 5, y + 2.5)
        p.lineTo(x + d * 5, y - 2.5)
        p.close()
        c.drawPath(p, fill=1, stroke=0)
    c.setFont("Sans", size)
    c.drawCentredString((x1 + x2) / 2, y + 4, label)


def arrow_v(c, x, y1, y2, label, size=8.5):
    c.setStrokeColor(GREY)
    c.setFillColor(GREY)
    c.setLineWidth(0.7)
    c.line(x, y1, x, y2)
    for y, d in ((y1, 1), (y2, -1)):
        p = c.beginPath()
        p.moveTo(x, y)
        p.lineTo(x + 2.5, y + d * 5)
        p.lineTo(x - 2.5, y + d * 5)
        p.close()
        c.drawPath(p, fill=1, stroke=0)
    c.saveState()
    c.setFont("Sans", size)
    c.translate(x + 9, (y1 + y2) / 2)
    c.rotate(90)
    c.drawCentredString(0, 0, label)
    c.restoreState()


def scissors(c, x, y, s=1.0):
    """Tijeras sencillas (aviso de adulto)."""
    c.saveState()
    c.translate(x, y)
    c.scale(s, s)
    c.setStrokeColor(WARN_LINE)
    c.setLineWidth(2)
    c.line(-12, -8, 12, 10)
    c.line(-12, 10, 12, -8)
    c.circle(-14, -10, 5, stroke=1, fill=0)
    c.circle(-14, 12, 5, stroke=1, fill=0)
    c.restoreState()


class Sketch(Flowable):
    """Dibujos del paso a paso. `kind`: pyramid | plastic | assemble | setup."""

    def __init__(self, kind, width, height):
        super().__init__()
        self.kind, self.width, self.height = kind, width, height

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        getattr(self, "_" + self.kind)(self.canv)

    # pirámide truncada invertida, vista 3D sencilla
    def _pyramid(self, c):
        w, h = self.width, self.height
        cx = w / 2
        top_y, bot_y = h - 14, 16
        tw, bw = w * 0.74, w * 0.11
        # cara trasera (clara) y delantera
        c.setFillColor(colors.Color(0.78, 0.86, 0.98, 0.55))
        c.setStrokeColor(VIOLET)
        c.setLineWidth(1.4)
        p = c.beginPath()
        p.moveTo(cx - tw / 2, top_y)
        p.lineTo(cx + tw / 2, top_y)
        p.lineTo(cx + bw / 2, bot_y)
        p.lineTo(cx - bw / 2, bot_y)
        p.close()
        c.drawPath(p, fill=1, stroke=1)
        # abertura superior (elipse achatada)
        c.setFillColor(colors.Color(1, 1, 1, 0.5))
        c.ellipse(cx - tw / 2, top_y - 9, cx + tw / 2, top_y + 9, fill=1, stroke=1)
        # aristas
        c.line(cx - tw / 6, top_y - 9, cx - bw / 6, bot_y)
        c.line(cx + tw / 6, top_y - 9, cx + bw / 6, bot_y)
        c.setFillColor(AMBER)
        c.setStrokeColor(AMBER_DARK)
        c.rect(cx - bw / 2 - 2, bot_y - 6, bw + 4, 6, fill=1, stroke=1)
        c.setFillColor(GREY)
        c.setFont("Sans", 8.5)
        c.drawString(cx + tw / 2 - 4, top_y + 12, "base grande arriba")
        c.drawString(cx + bw / 2 + 24, bot_y - 5, "punta chica sobre la pantalla")

    # cuatro trapecios sobre el plástico, alternando boca arriba y boca abajo (encajan: ahorran plástico)
    def _plastic(self, c):
        w, h = self.width, self.height
        c.setFillColor(colors.Color(0.85, 0.93, 1, 1))
        c.setStrokeColor(colors.Color(0.45, 0.6, 0.85))
        c.setLineWidth(1)
        c.roundRect(0, 0, w, h, 6, fill=1, stroke=1)
        span = 3 * (BASE_BIG + BASE_SMALL) / 2 + BASE_BIG  # cm que ocupan los cuatro
        sc = (w - 24) / span
        tw, bw, th = BASE_BIG * sc, BASE_SMALL * sc, HEIGHT * sc
        step = (tw + bw) / 2
        x = 12 + tw / 2
        cy = h / 2 + 4
        for i in range(4):
            c.saveState()
            c.translate(x, cy)
            if i % 2:
                c.rotate(180)
            trapezoid(c, 0, -th / 2, bw, tw, th, fill=colors.white, stroke=VIOLET, width=1.2)
            c.restoreState()
            c.setFillColor(VIOLET)
            c.setFont("Sans-Bold", 9)
            c.drawCentredString(x, cy - 3, str(i + 1))
            x += step

    # los cuatro trapecios abiertos en abanico (se unen por las patas) y la cinta en cada unión
    def _assemble(self, c):
        w, h = self.width, self.height
        apex_d = HEIGHT * BASE_SMALL / (BASE_BIG - BASE_SMALL)  # cm desde el vértice hasta la base chica
        half = math.degrees(math.atan((BASE_BIG / 2) / (HEIGHT + apex_d)))  # medio ángulo de cada cara
        d0, d1 = apex_d, apex_d + HEIGHT
        faces = []
        for i in range(4):
            ang = math.radians((i - 1.5) * 2 * half)
            pts = [(-BASE_SMALL / 2, -d0), (BASE_SMALL / 2, -d0), (BASE_BIG / 2, -d1), (-BASE_BIG / 2, -d1)]
            faces.append([(x * math.cos(ang) - y * math.sin(ang), x * math.sin(ang) + y * math.cos(ang)) for x, y in pts])
        xs = [x for f in faces for x, _ in f]
        ys = [y for f in faces for _, y in f] + [0]
        sc = min((w - 20) / (max(xs) - min(xs)), (h - 20) / (max(ys) - min(ys)))
        ox = w / 2 - (max(xs) + min(xs)) / 2 * sc
        oy = h / 2 - (max(ys) + min(ys)) / 2 * sc
        P = lambda pt: (ox + pt[0] * sc, oy + pt[1] * sc)
        for i, f in enumerate(faces):
            p = c.beginPath()
            p.moveTo(*P(f[0]))
            for pt in f[1:]:
                p.lineTo(*P(pt))
            p.close()
            c.setFillColor(colors.Color(0.85, 0.93, 1, 1))
            c.setStrokeColor(VIOLET)
            c.setLineWidth(1.2)
            c.drawPath(p, fill=1, stroke=1)
            cx = sum(P(pt)[0] for pt in f) / 4
            cy = sum(P(pt)[1] for pt in f) / 4
            c.setFillColor(VIOLET)
            c.setFont("Sans-Bold", 10)
            c.drawCentredString(cx, cy - 3, str(i + 1))
            if i < 3:  # cinta en la pata que une con la siguiente
                (x1, y1), (x2, y2) = P(f[1]), P(f[2])
                c.setStrokeColor(colors.Color(1, 0.72, 0.1, 0.95))
                c.setLineWidth(4)
                c.line(x1 + (x2 - x1) * 0.12, y1 + (y2 - y1) * 0.12, x1 + (x2 - x1) * 0.88, y1 + (y2 - y1) * 0.88)
        # el vértice (donde se juntaría la punta): solo de referencia
        c.setFillColor(GREY)
        c.circle(*P((0, 0)), 1.6, fill=1, stroke=0)

    # el celular con la pirámide encima, vista lateral
    def _setup(self, c):
        w, h = self.width, self.height
        cx = w / 2
        # móvil
        c.setFillColor(INDIGO)
        c.setStrokeColor(colors.black)
        c.roundRect(cx - 62, 10, 124, 14, 4, fill=1, stroke=1)
        c.setFillColor(AMBER)
        c.rect(cx - 5, 24, 10, 3, fill=1, stroke=0)
        # pirámide
        c.setFillColor(colors.Color(0.78, 0.86, 0.98, 0.5))
        c.setStrokeColor(VIOLET)
        c.setLineWidth(1.4)
        p = c.beginPath()
        p.moveTo(cx - 5, 27)
        p.lineTo(cx + 5, 27)
        p.lineTo(cx + 46, 27 + 46)
        p.lineTo(cx - 46, 27 + 46)
        p.close()
        c.drawPath(p, fill=1, stroke=1)
        # figura flotando
        c.setFillColor(AMBER)
        c.circle(cx, 27 + 24, 7, fill=1, stroke=0)
        c.rect(cx - 5, 27 + 10, 10, 13, fill=1, stroke=0)
        # ojo
        c.setFillColor(GREY)
        c.setFont("Sans", 8.5)
        c.drawString(cx + 56, 27 + 22, "la figura «flota» dentro")
        c.drawString(cx + 56, 27 + 10, "de la pirámide")
        c.setStrokeColor(GREY)
        c.setDash(2, 2)
        c.line(cx + 90, 27 + 50, cx + 50, 27 + 34)
        c.setDash()
        c.drawString(cx + 70, 27 + 54, "tu mirada, de lado")


class TemplatePage(Flowable):
    """Una plantilla a escala real (1 pt = 1/72 in). Ocupa todo el marco."""

    def __init__(self, scale, title, subtitle, frame_w, frame_h, fan=False):
        super().__init__()
        self.scale, self.title, self.subtitle, self.fan = scale, title, subtitle, fan
        self.w, self.h = frame_w, frame_h

    def wrap(self, aw, ah):
        return self.w, self.h

    def draw(self):
        c = self.canv
        s = self.scale
        small, big, th = BASE_SMALL * s * cm, BASE_BIG * s * cm, HEIGHT * s * cm
        cx = self.w / 2
        # trapecio
        y0 = self.h - 2.4 * cm - th
        # sombra de papel: relleno suave para ver bien el contorno
        trapezoid(c, cx, y0, small, big, th, fill=SOFT, stroke=INDIGO, width=1.6, dash=(6, 3))
        # cotas
        arrow_h(c, cx - big / 2, cx + big / 2, y0 + th + 14, f"{BASE_BIG * s:g} cm")
        arrow_h(c, cx - small / 2, cx + small / 2, y0 - 14, f"{BASE_SMALL * s:g} cm")
        arrow_v(c, cx + big / 2 + 16, y0, y0 + th, f"{HEIGHT * s:g} cm")
        c.setFillColor(INDIGO)
        c.setFont("Sans-Bold", 9)
        c.drawCentredString(cx, y0 + th * 0.55, "PLANTILLA")
        c.setFont("Sans", 8)
        c.setFillColor(GREY)
        c.drawCentredString(cx, y0 + th * 0.55 - 11, "recorta por la línea de rayas")
        # tijeras
        scissors(c, cx - big / 2 - 22, y0 + th + 1, 0.9)
        if self.fan:  # cómo se arman las cuatro caras (paso 6) en el espacio libre de la página
            fw_, fh_ = 8.2 * cm, 6.6 * cm
            fx, fy = (self.w - fw_) / 2, 6.6 * cm
            c.setFillColor(VIOLET)
            c.setFont("Sans-Bold", 11)
            c.drawCentredString(self.w / 2, fy + fh_ + 24, "Así se arman las cuatro caras (paso 6)")
            c.setFillColor(GREY)
            c.setFont("Sans", 8.5)
            c.drawCentredString(self.w / 2, fy + fh_ + 11, "Unidas por las patas con cinta forman un abanico; al cerrarlo, la 4 se pega con la 1 (dibujo sin escala).")
            c.saveState()
            c.translate(fx, fy)
            sk = Sketch("assemble", fw_, fh_)
            sk.canv = c
            sk.draw()
            c.restoreState()
        # comprobación de escala
        ry = 3.2 * cm
        c.setStrokeColor(colors.black)
        c.setFillColor(colors.black)
        c.setLineWidth(0.8)
        L = 5 * cm
        x0 = (self.w - L) / 2
        c.line(x0, ry, x0 + L, ry)
        for i in range(6):
            c.line(x0 + i * cm, ry - 4, x0 + i * cm, ry + (8 if i in (0, 5) else 5))
        c.setFont("Sans", 8)
        for i in range(6):
            c.drawCentredString(x0 + i * cm, ry - 14, str(i))
        c.drawString(x0 + L + 8, ry - 3, "cm")
        c.setFillColor(GREY)
        c.setFont("Sans-Bold", 9.5)
        c.drawCentredString(self.w / 2, ry + 22, "¿Imprimiste bien? Esta regla debe medir exactamente 5 cm.")
        c.setFont("Sans", 8.5)
        c.drawCentredString(self.w / 2, ry + 10, "Si no: imprime en tamaño real («100 %» o «Tamaño real»), nunca «ajustar a la página».")
        # 1 cm de cuadrado de referencia
        c.setStrokeColor(colors.black)
        c.rect(self.w / 2 - 0.5 * cm, ry - 1.9 * cm, 1 * cm, 1 * cm, fill=0, stroke=1)
        c.setFont("Sans", 8)
        c.drawString(self.w / 2 + 0.7 * cm, ry - 1.9 * cm + 3, "= 1 cm × 1 cm de referencia")


# --------------------------------------------------------------- documento
def build(out: Path):
    doc = BaseDocTemplate(str(out), pagesize=letter, leftMargin=1.7 * cm, rightMargin=1.7 * cm, topMargin=1.5 * cm,
                          bottomMargin=1.6 * cm, title="Holograma en casa", author=APP_NAME,
                          subject="Cómo hacer una pirámide holográfica con plástico transparente (tamaño carta)")
    W, H = letter
    fw, fh = W - doc.leftMargin - doc.rightMargin, H - doc.topMargin - doc.bottomMargin
    frame = Frame(doc.leftMargin, doc.bottomMargin, fw, fh, id="f", leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)

    def page(c, d):
        c.saveState()
        c.setFillColor(AMBER)
        c.rect(0, H - 0.55 * cm, W, 0.55 * cm, fill=1, stroke=0)
        c.setFillColor(GREY)
        c.setFont("Sans", 8)
        c.drawString(doc.leftMargin, 0.8 * cm, f"Holograma en casa · {APP_NAME}")
        c.drawRightString(W - doc.rightMargin, 0.8 * cm, f"Página {d.page} · Imprimir en tamaño carta, al 100 %")
        c.restoreState()

    doc.addPageTemplates([PageTemplate(id="p", frames=[frame], onPage=page)])
    s = []

    # ------------------------------------------------ página 1
    s += [Paragraph("Holograma en casa", H1),
          Paragraph("Una pirámide de plástico transparente que hace «flotar» los cuentos sobre la pantalla de un teléfono o una tableta.", SUB)]
    s.append(Sketch("pyramid", fw * 0.46, 3.5 * cm))
    s.append(Spacer(1, 6))
    s.append(Box([
        Paragraph("<b>⚠ Solo con un adulto presente</b>", WARN),
        Paragraph("Para hacerla hay que usar <b>tijeras</b> y recortar plástico, que puede dejar bordes filosos. "
                  "Un adulto corta; los niños pueden ayudar a marcar, medir y pegar la cinta.", WARN),
        Paragraph("Edad sugerida para participar: desde 6 años, siempre acompañados. Cuida los dedos y las esquinas, "
                  "trabaja sobre una mesa despejada y guarda las tijeras al terminar.", WARN),
    ], WARN_BG, WARN_LINE, fw))
    s.append(Spacer(1, 4))
    s.append(Paragraph("Materiales", H2))
    mat = [
        ["Imprescindibles", "Para qué sirve"],
        ["<b>Plástico transparente y liso</b>: lámina de acetato (la de las transparencias para retroproyector), "
         "cubierta de carpeta o portada plástica transparente, o la tapa y la caja de un CD (sirven 2 cajas)",
         "Es lo que forma la pirámide. Que no tenga arrugas ni rayones; sin color. Grosor ideal: 0,15–0,30 mm"],
        ["<b>Esta plantilla impresa</b> en papel tamaño carta, al 100 % (página 4 para teléfono, página 5 para tableta)",
         "Es el molde: se recorta una vez y se repasa cuatro veces"],
        ["<b>Tijeras</b> (las usa el adulto)", "Para recortar el papel y el plástico"],
        ["<b>Marcador de punta fina</b> que escriba sobre plástico (permanente o de pizarra)", "Para repasar los trapecios en el plástico"],
        ["<b>Cinta adhesiva transparente</b> (la «mágica» o la de embalar fina)", "Para unir las cuatro caras. Mejor que el pegamento: no deja manchas"],
        ["<b>Regla</b>", "Para comprobar que la impresión salió a escala"],
    ]
    opt = [
        ["Recomendados", "Para qué sirve"],
        ["Paño de microfibra o de lentes", "Quitar huellas del plástico: una pirámide limpia se ve mucho mejor"],
        ["Cartón o tabla para cortar", "Proteger la mesa"],
        ["Habitación a media luz y pantalla con el brillo al máximo", "El holograma se ve mucho más nítido en la penumbra"],
    ]

    def tbl(rows, head_bg):
        data = [[Paragraph(f"<b>{c}</b>" if r == 0 else c, SMALL if r else BODY) for c in row] for r, row in enumerate(rows)]
        t = Table(data, colWidths=[fw * 0.58, fw * 0.42])
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), head_bg), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#C9C2E6")), ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, SOFT]),
        ]))
        return t

    # la cabecera de la tabla en blanco sobre violeta
    for rows in (mat, opt):
        rows[0] = [f'<font color="white">{rows[0][0]}</font>', f'<font color="white">{rows[0][1]}</font>']
    s += [tbl(mat, VIOLET), Spacer(1, 7), tbl(opt, colors.HexColor("#8A7BD8"))]
    s.append(Spacer(1, 6))
    s.append(Paragraph("<b>Tiempo:</b> 20–30 minutos. <b>Costo:</b> casi nulo si reutilizas plástico que ya tengas en casa.", SMALL))
    s.append(PageBreak())

    # ------------------------------------------------ página 2: paso a paso
    s.append(Paragraph("Paso a paso", H1))
    s.append(Paragraph("Léelo completo antes de empezar. Los pasos con tijeras los hace el adulto.", SUB))

    def step(n, title, text, extra=None):
        num = Table([[Paragraph(f'<font color="white"><b>{n}</b></font>', ParagraphStyle("n", fontName="Sans-Bold", fontSize=15, alignment=1, leading=18))]],
                    colWidths=[0.9 * cm], rowHeights=[0.9 * cm])
        num.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), VIOLET), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                                 ("ROUNDEDCORNERS", [8, 8, 8, 8])]))
        body = [Paragraph(f"<b>{title}</b>", STEP), Paragraph(text, SMALL if False else BODY)]
        if extra:
            body.append(extra)
        row = Table([[num, body]], colWidths=[1.3 * cm, fw - 1.3 * cm])
        row.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0),
                                 ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
        return KeepTogether([row])

    s += [
        step(1, "Prepara la mesa y llama a un adulto",
             "Mesa despejada y bien iluminada, el plástico limpio y las tijeras al alcance del adulto. "
             "Si el plástico trae una película protectora, retírala por las dos caras."),
        step(2, "Imprime la plantilla al tamaño real",
             "Elige papel <b>tamaño carta</b> (8,5 × 11 pulgadas) y, en la ventana de impresión, <b>escala 100 %</b> (o «Tamaño real»). "
             "<b>No</b> marques «Ajustar a la página». Comprueba con la regla que la barra de la plantilla mide <b>5 cm</b>. "
             "Teléfono: página 4. Tableta: página 5."),
        step(3, "Recorta la plantilla de papel",
             "El adulto recorta el trapecio por la línea de rayas. Ese papel es tu molde."),
        step(4, "Repasa cuatro trapecios en el plástico",
             "Apoya el molde sobre el plástico y repásalo con el marcador. Haz <b>cuatro</b>: uno boca arriba y el siguiente boca abajo "
             "para aprovechar el plástico. Deja medio centímetro entre ellos.",
             Sketch("plastic", fw * 0.78, 3.3 * cm)),
        step(5, "Recorta los cuatro trapecios",
             "El adulto corta por fuera de la línea del marcador, con pulso firme. Redondea apenas las puntas para que no pinchen "
             "y limpia el plástico con el paño."),
        step(6, "Une las caras con cinta",
             "Pon los trapecios de pie y junta dos lados inclinados: pega la cinta a todo lo largo del borde, por fuera. "
             "Une las cuatro caras haciendo un anillo. Queda una pirámide <b>sin punta ni base</b>: con una abertura chica "
             "(1 cm, la que irá sobre la pantalla) y otra grande arriba (6 cm). Comprueba que los cuatro lados queden parejos (dibujo en la página 4).",
             ),
        step(7, "Colócala sobre la pantalla",
             "Abre el cuento en la app, toca el icono de <b>holograma</b> (el cubito) y apaga las luces. Pon la pirámide con la "
             "abertura chica sobre el <b>cuadrado de guía</b> del centro de la pantalla. Ajusta el tamaño con <b>+</b> y <b>−</b> "
             "hasta que el cuadrado coincida con la abertura. Mira desde un costado, a la altura de la pirámide."),
    ]
    s.append(PageBreak())

    # ------------------------------------------------ página 3: ver y arreglar
    s.append(Paragraph("A mirar el holograma", H1))
    s.append(Paragraph("Cada cara de la pirámide refleja una de las cuatro copias del cuento que dibuja la app.", SUB))
    s.append(Sketch("setup", fw * 0.8, 3.4 * cm))
    s.append(Paragraph("Cómo se ve mejor", H2))
    s += bullets([
        "<b>Penumbra:</b> cuanto más oscura la habitación, más nítida la imagen. Brillo de la pantalla al máximo y, si puedes, desactiva el modo de ahorro de batería.",
        "<b>Pirámide centrada:</b> la abertura chica sobre el cuadrado de guía, sin inclinarse. Si se corre, se desdobla la figura.",
        "<b>Plástico limpio:</b> unas huellas se notan mucho. Límpialo con el paño antes de usarlo.",
        "<b>Distancia:</b> a unos 30–50 cm, con los ojos a la altura de la pirámide. Descansa la vista cada 10 minutos.",
        "<b>Con calma:</b> no dejes el aparato solo con niños pequeños ni apoyes nada pesado encima de la pirámide.",
    ])
    s.append(Paragraph("Si algo no se ve bien", H2))
    ts = [
        ["Qué ves", "Qué hacer"],
        ["La figura se ve <b>de cabeza</b>", "En la barra de controles del holograma pulsa «Pies hacia dentro o fuera»"],
        ["La figura sale <b>al revés</b> (izquierda y derecha cambiadas)", "Pulsa «Reflejar izquierda y derecha»"],
        ["Se ve <b>muy chica</b> o <b>cortada</b>", "Cambia el tamaño con + y −: la abertura de la pirámide debe quedar justo sobre el cuadrado central"],
        ["Se ve <b>borrosa</b>", "Limpia el plástico, quita la película protectora, sube el brillo y oscurece el cuarto"],
        ["Una cara se ve <b>distinta</b> o no se ve", "Revisa que los cuatro trapecios sean iguales y que las uniones con cinta no tapen la imagen"],
        ["Tu tableta o tu móvil es más grande o más chico", "Usa la plantilla de tableta (página 5), o mide el lado corto de la pantalla: la abertura chica debe medir <b>1/6</b> de ese lado"],
    ]
    data = [[Paragraph(f'<font color="white"><b>{c}</b></font>' if r == 0 else c, SMALL) for c in row] for r, row in enumerate(ts)]
    t = Table(data, colWidths=[fw * 0.42, fw * 0.58])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), VIOLET), ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#C9C2E6")),
                           ("VALIGN", (0, 0), (-1, -1), "TOP"), ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                           ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, SOFT])]))
    s.append(t)
    s.append(Spacer(1, 8))
    s.append(Spacer(1, 6))
    s.append(Paragraph("<b>Medidas de las plantillas</b> (trapecio con la base chica abajo): teléfono 1 × 6 cm, alto 3,5 cm · "
                       f"tableta {BASE_SMALL * SCALE_L:g} × {BASE_BIG * SCALE_L:g} cm, alto {HEIGHT * SCALE_L:g} cm. "
                       "Cada cara queda a 45° respecto a la pantalla.", SMALL))
    s.append(PageBreak())

    # ------------------------------------------------ páginas 4 y 5: plantillas
    s.append(Paragraph("Plantilla · teléfono", H1))
    s.append(Paragraph("Para móviles de hasta ~7 cm de ancho. Imprime al 100 %, recorta un trapecio de papel y repásalo cuatro veces.", SUB))
    s.append(TemplatePage(1.0, "", "", fw, fh - 3.4 * cm, fan=True))
    s.append(PageBreak())
    s.append(Paragraph("Plantilla · tableta", H1))
    s.append(Paragraph("Para tabletas con el lado corto de ~15 a 17 cm. Imprime al 100 %: es la plantilla del teléfono ×2,5.", SUB))
    s.append(TemplatePage(SCALE_L, "", "", fw, fh - 3.4 * cm))
    doc.build(s)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "app/assets/guides/holograma-en-casa.pdf"
    out.parent.mkdir(parents=True, exist_ok=True)
    build(out)
    print(out)
