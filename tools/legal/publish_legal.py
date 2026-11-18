#!/usr/bin/env python3
"""Publica la política de privacidad, los términos y una página de soporte en https://audio.tuvendor.com/legal/
(las tiendas piden URLs públicas). Lee content/legal/*.md, rellena {{APP}}, {{TITULAR}}, {{CORREO}} y {{FECHA}}
con los valores de app/lib/src/brand.dart y sube HTML sencillo al bucket R2 con las credenciales de credenciales/.env.

    python3 tools/legal/publish_legal.py            # arma builds/publicar/legal/ y lo sube
    python3 tools/legal/publish_legal.py --en-carpeta
Necesita los paquetes `markdown` y `boto3`.
"""
import argparse, html, re
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[2]


def brand(name):
    src = (ROOT / "app/lib/src/brand.dart").read_text(encoding="utf-8")
    return re.search(rf"const String {name} = '([^']*)';", src).group(1)


PAGE = """<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{title} · {app}</title>
<style>body{{font-family:system-ui,sans-serif;max-width:720px;margin:0 auto;padding:24px 16px;line-height:1.6;color:#1f1a3a;background:#f6f3fb}}
h1,h2{{color:#2a2160}}a{{color:#5b3fd0}}footer{{margin-top:48px;font-size:.9em;color:#5d5878}}</style></head>
<body>{body}<footer><a href="privacidad.html">Política de privacidad</a> · <a href="terminos.html">Términos de uso</a> ·
<a href="soporte.html">Soporte</a></footer></body></html>"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--en-carpeta", action="store_true", help="solo armar builds/publicar/legal/, sin subir")
    a = ap.parse_args()
    app, owner, mail, date = brand("appName"), brand("legalOwner"), brand("contactEmail"), brand("legalDate")
    out = ROOT / "builds/publicar/legal"
    out.mkdir(parents=True, exist_ok=True)

    def fill(t):
        return t.replace("{{APP}}", app).replace("{{TITULAR}}", owner).replace("{{CORREO}}", mail).replace("{{FECHA}}", date)

    pages = {
        "privacidad.html": ("Política de privacidad", fill((ROOT / "content/legal/politica-de-privacidad.es.md").read_text(encoding="utf-8"))),
        "terminos.html": ("Términos de uso", fill((ROOT / "content/legal/terminos-de-uso.es.md").read_text(encoding="utf-8"))),
        "soporte.html": ("Soporte", f"# Soporte de {app}\n\n¿Dudas, problemas con la suscripción o sugerencias de cuentos?\n\n"
                                    f"Escríbenos a **{mail}** y te respondemos lo antes posible.\n\n"
                                    "Para cancelar la suscripción: en Android, Google Play → Pagos y suscripciones; "
                                    "en iPhone, Ajustes → tu nombre → Suscripciones."),
    }
    for name, (title, md) in pages.items():
        body = markdown.markdown(md, extensions=["tables"])
        (out / name).write_text(PAGE.format(title=html.escape(title), app=html.escape(app), body=body), encoding="utf-8")
    print(f"Armado en {out}")
    if a.en_carpeta:
        return
    import boto3
    env = {}
    for line in (ROOT / "credenciales/.env").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    s3 = boto3.client("s3", endpoint_url=env["S3_ENDPOINT_URL"], aws_access_key_id=env["AWS_ACCESS_KEY_ID"],
                      aws_secret_access_key=env["AWS_SECRET_ACCESS_KEY"], region_name="auto")
    for f in out.glob("*.html"):
        s3.put_object(Bucket=env.get("S3_BUCKET", "mininoches"), Key=f"legal/{f.name}", Body=f.read_bytes(),
                      ContentType="text/html; charset=utf-8", CacheControl="public, max-age=3600")
        print(f"subido legal/{f.name}")


if __name__ == "__main__":
    main()
