#!/usr/bin/env python3
"""Genera la web estática con la política de privacidad y los términos de uso (las tiendas piden una dirección pública).

Los textos son los mismos que lee la app (`content/legal/*.md`), con los datos de la marca puestos desde
`app/lib/src/brand.dart` (nombre, titular, correo, fecha). Sin dependencias: un convertidor mínimo de Markdown
(títulos, listas, citas, negritas, cursivas, enlaces y párrafos).

Uso: python3 tools/legal/build_site.py [carpeta_de_salida=site]
Se publica con `.github/workflows/pages.yml` (GitHub Pages).
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRAND = (ROOT / "app/lib/src/brand.dart").read_text(encoding="utf-8")


def const(name):
    m = re.search(rf"const (?:String|bool) {name} = ([^;]+);", BRAND)
    if not m:
        sys.exit(f"no encuentro {name} en brand.dart")
    v = m.group(1).strip()
    return v[1:-1] if v[0] in "'\"" else v


APP, OWNER, EMAIL, DATE = const("appName"), const("legalOwner"), const("contactEmail"), const("legalDate")
SERVER_LIVE = const("feedbackServerLive") == "true"
PENDING = OWNER.startswith("[") or EMAIL.startswith("[")


def fill(raw):
    return (raw.replace("{{APP}}", APP).replace("{{TITULAR}}", OWNER).replace("{{CORREO}}", EMAIL).replace("{{FECHA}}", DATE)
            .replace("{{ESTADO_SERVIDOR}}", "" if SERVER_LIVE else
                     "Hoy la app todavía no tiene servidor de valoraciones: las notas se guardan en el teléfono y no se envían a ningún sitio."))


def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    return t


def convert(md):
    out, para, items, quote = [], [], [], []

    def flush():
        nonlocal para, items, quote
        if para:
            out.append("<p>" + " ".join(inline(p) for p in para) + "</p>")
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
        if quote:
            out.append("<blockquote>" + inline(" ".join(quote)) + "</blockquote>")
        para, items, quote = [], [], []

    for line in md.split("\n"):
        s = line.rstrip()
        if not s.strip():
            flush()
        elif s.startswith("#"):
            flush()
            n = len(s) - len(s.lstrip("#"))
            out.append(f"<h{n}>{inline(s[n:].strip())}</h{n}>")
        elif s.lstrip().startswith(("- ", "* ")):
            if para or quote:
                flush()
            items.append(s.lstrip()[2:])
        elif s.startswith(">"):
            if para or items:
                flush()
            quote.append(s[1:].strip())
        else:
            if items or quote:
                flush()
            para.append(s.strip())
    flush()
    return "\n".join(out)


CSS = """body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:46rem;margin:0 auto;padding:1.5rem 1rem 4rem;
line-height:1.6;color:#1d1b2e;background:#fbfaff}h1{color:#3b2a8a}h2{margin-top:2rem;color:#3b2a8a}blockquote{margin:1rem 0;padding:.6rem 1rem;
background:#fff4d6;border-left:4px solid #f0b429}a{color:#5b3fd8}nav a{margin-right:1rem}footer{margin-top:3rem;color:#777;font-size:.85rem}
@media(prefers-color-scheme:dark){body{background:#14102e;color:#ece8ff}h1,h2{color:#c9b8ff}a{color:#b9a3ff}blockquote{background:#3a2f12}}"""


def page(title, body, nav=True):
    banner = ""
    if PENDING:
        banner = "<blockquote><strong>Borrador:</strong> faltan el titular y el correo de contacto (véase docs/22 del proyecto).</blockquote>"
    links = '<nav><a href="../">Inicio</a><a href="../privacidad/">Privacidad</a><a href="../terminos/">Términos</a></nav>' if nav else ""
    return (f'<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f"<title>{html.escape(title)} · {html.escape(APP)}</title><style>{CSS}</style></head><body>{links}{banner}{body}"
            f"<footer>{html.escape(APP)} · actualizado el {html.escape(DATE)}</footer></body></html>")


def main():
    out = ROOT / (sys.argv[1] if len(sys.argv) > 1 else "site")
    for slug, src, title in [("privacidad", "politica-de-privacidad.es.md", "Política de privacidad"),
                             ("terminos", "terminos-de-uso.es.md", "Términos de uso")]:
        body = convert(fill((ROOT / "content/legal" / src).read_text(encoding="utf-8")))
        (out / slug).mkdir(parents=True, exist_ok=True)
        (out / slug / "index.html").write_text(page(title, body), encoding="utf-8")
    index = (f"<h1>{html.escape(APP)}</h1><p>Cuentos para dormir, originales y sin anuncios.</p><ul>"
             '<li><a href="privacidad/">Política de privacidad</a></li><li><a href="terminos/">Términos de uso</a></li></ul>')
    (out / "index.html").write_text(page(APP, index, nav=False), encoding="utf-8")
    print(f"web en {out}: privacidad/, terminos/ (borrador: {PENDING})")


if __name__ == "__main__":
    main()
