#!/usr/bin/env python3
"""Cambia el nombre del juego en todos los sitios que lo escriben a mano.

Uso:
  python3 tools/rename_app.py "Nombre nuevo" [--tagline "Frase corta"]   → cambia y regenera la guía en PDF
  python3 tools/rename_app.py --check                                      → dice si todo coincide (CI y pruebas)

Qué toca:
  * app/lib/src/brand.dart            (el nombre y la frase que ve la familia: todo el código lo lee de aquí)
  * app/android/.../AndroidManifest.xml  (la etiqueta bajo el icono en Android)
  * app/ios/Runner/Info.plist            (CFBundleDisplayName: el nombre bajo el icono en iOS)
  * app/assets/guides/holograma-en-casa.pdf (se vuelve a generar si hay ReportLab)

Qué NO toca (decisiones que se toman con calma, ver docs/19 y el final de este mensaje):
  el id técnico de la app (`applicationId` en Android, `PRODUCT_BUNDLE_IDENTIFIER` en iOS, el paquete `caldero_app`),
  el dominio, la URL de descarga, el icono y los textos de las tiendas.
"""
import argparse
import html
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "app/lib/src/brand.dart"
MANIFEST = ROOT / "app/android/app/src/main/AndroidManifest.xml"
PLIST = ROOT / "app/ios/Runner/Info.plist"
GUIDE = ROOT / "tools/guide/make_holograma_pdf.py"

_STR = r"((?:\\.|[^'\\])*)"  # una cadena de Dart entre comillas simples (con \' y \$ escapados)
NAME_RE = re.compile(r"(const String appName = ')" + _STR + r"(';)")
TAG_RE = re.compile(r"(const String appTagline = ')" + _STR + r"(';)")
LABEL_RE = re.compile(r'(android:label=")([^"]*)(")')
PLIST_RE = re.compile(r"(<key>CFBundleDisplayName</key>\s*<string>)([^<]*)(</string>)")


def dart(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def undart(s):
    return re.sub(r"\\(.)", r"\1", s)


def current():
    t = BRAND.read_text(encoding="utf-8")
    return undart(NAME_RE.search(t).group(2)), undart(TAG_RE.search(t).group(2))


def check():
    name, _ = current()
    problems = []
    label = LABEL_RE.search(MANIFEST.read_text(encoding="utf-8")).group(2)
    if html.unescape(label) != name:
        problems.append(f"AndroidManifest: «{label}» ≠ «{name}»")
    plist = PLIST_RE.search(PLIST.read_text(encoding="utf-8")).group(2)
    if html.unescape(plist) != name:
        problems.append(f"Info.plist: «{plist}» ≠ «{name}»")
    return name, problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name", nargs="?", help="el nombre nuevo")
    ap.add_argument("--tagline", help="la frase corta de la pantalla de bienvenida")
    ap.add_argument("--check", action="store_true", help="solo comprobar que todo coincide")
    ap.add_argument("--no-pdf", action="store_true", help="no regenerar la guía en PDF")
    a = ap.parse_args()

    if a.check or not a.name:
        name, problems = check()
        for p in problems:
            print("✗", p)
        print(("✓ " if not problems else "✗ ") + f"nombre: «{name}»")
        sys.exit(1 if problems else 0)

    name = a.name.strip()
    if not name or len(name) > 30:
        sys.exit("El nombre debe tener entre 1 y 30 letras (en el teléfono se corta si es más largo).")
    t = BRAND.read_text(encoding="utf-8")
    t = NAME_RE.sub(lambda m: m.group(1) + dart(name) + m.group(3), t)
    if a.tagline:
        t = TAG_RE.sub(lambda m: m.group(1) + dart(a.tagline.strip()) + m.group(3), t)
    BRAND.write_text(t, encoding="utf-8")
    esc = html.escape(name, quote=True)
    MANIFEST.write_text(LABEL_RE.sub(lambda m: m.group(1) + esc + m.group(3), MANIFEST.read_text(encoding="utf-8")), encoding="utf-8")
    PLIST.write_text(PLIST_RE.sub(lambda m: m.group(1) + html.escape(name, quote=False) + m.group(3), PLIST.read_text(encoding="utf-8")), encoding="utf-8")
    print(f"✓ nombre cambiado a «{name}» en brand.dart, AndroidManifest.xml e Info.plist")
    if not a.no_pdf:
        try:
            subprocess.run([sys.executable, str(GUIDE)], check=True, cwd=GUIDE.parent)
            print("✓ guía «Holograma en casa» regenerada")
        except Exception as e:  # sin ReportLab o sin fuentes
            print(f"! no se pudo regenerar el PDF ({e}); ejecuta tools/guide/make_holograma_pdf.py")
    print("""
Queda por hacer a mano (no se cambia solo):
  [ ] README.md y docs/00-vision.md: el título (hoy dicen «nombre provisional»)
  [ ] el id técnico de la app (applicationId / bundle id): hay que decidirlo ANTES de la primera publicación en tiendas
  [ ] el dominio, la URL de descarga del APK y el nombre del archivo (hoy caldero-de-cuentos.apk)
  [ ] el icono y la ficha de las tiendas (título, descripción, capturas)
  [ ] la marca: registro/búsqueda de marca en las clases que correspondan (docs/19)
  [ ] volver a compilar el APK""")


if __name__ == "__main__":
    main()
