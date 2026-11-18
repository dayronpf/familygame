#!/usr/bin/env python3
"""Publica el contenido de un idioma para que la app lo baje sin actualizarse (docs/34, paso B1).

Hace, en este orden:

1. valida los paquetes que usa el catálogo con el motor (`dart run bin/validate_pack.dart`, desde
   packages/caldero_engine);
2. comprueba que el audio esté listo: que `tools/voice/export_app.py` ya escribió el manifiesto de la versión del
   catálogo y que existe cada audio que nombra (con `--exportar`, lo ejecuta antes);
3. arma la carpeta publicable:
       contenido/<idioma>/indice.json          versión, motor, versión del catálogo y huella sha256 de cada archivo
       contenido/<idioma>/paquetes/<id>.json   los paquetes que usa el catálogo (content/packs/<id>/pack.json)
       contenido/<idioma>/catalogo.json        el catálogo fijo (content/catalogo/lanzamiento-<idioma>.json)
       contenido/<idioma>/voz.json             el manifiesto de voz (app/assets/voz/<idioma>/manifiesto.json)
       voz/<idioma>/<huella>.m4a               todo el audio, también el de los cuentos gratis
4. con `--en-carpeta` (lo normal) la deja en builds/publicar/ para probar sin subir nada; con `--subir` la sube a un
   almacén compatible con S3 (Cloudflare R2): primero el audio que falta (el nombre ya es la huella, así que lo que
   ya está no se vuelve a subir), luego los paquetes, el catálogo y la voz, y AL FINAL indice.json, para que la app
   nunca vea un índice que apunte a archivos que todavía no existen.

La versión es la fecha y hora de la publicación (AAAAMMDDhhmmss, UTC): un número que solo crece. El motor es
`contentEngineVersion` de packages/caldero_engine/lib/src/catalog.dart.

Credenciales para `--subir` (nunca en el código): variables de entorno o un archivo .env (`--env ruta`):
    S3_ENDPOINT_URL        https://<cuenta>.r2.cloudflarestorage.com
    S3_BUCKET              el nombre del almacén
    AWS_ACCESS_KEY_ID      clave de la API de R2
    AWS_SECRET_ACCESS_KEY
Las variables del entorno mandan sobre las del archivo. Necesita boto3 (pip install boto3).

Uso (desde la raíz del repositorio):
    python3 tools/content/publish.py                     # arma builds/publicar/ (no sube nada)
    python3 tools/content/publish.py --exportar          # antes prepara el audio con export_app.py
    python3 tools/content/publish.py --subir --env ~/.config/mininoches/r2.env
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "packages" / "caldero_engine"
INDEX_FORMAT = 1


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 16), b""):
            h.update(block)
    return h.hexdigest()


def engine_version():
    src = (ENGINE / "lib" / "src" / "catalog.dart").read_text(encoding="utf-8")
    m = re.search(r"const int contentEngineVersion = (\d+);", src)
    if not m:
        sys.exit("No encuentro contentEngineVersion en packages/caldero_engine/lib/src/catalog.dart")
    return int(m.group(1))


def validate_packs(paths):
    """Valida con el motor. Sale si algún paquete tiene problemas."""
    if shutil.which("dart") is None:
        sys.exit("Falta dart en el PATH (hace falta para validar los paquetes)")
    print(f"Validando {len(paths)} paquetes con el motor…", flush=True)
    r = subprocess.run(["dart", "run", "bin/validate_pack.dart", *[str(p.resolve()) for p in paths]], cwd=ENGINE)
    if r.returncode != 0:
        sys.exit("Hay paquetes con problemas: corrígelos antes de publicar")


def check_voice(manifest_path, catalog, audio_dir, cdn_dir):
    """El manifiesto de voz es el de esta versión del catálogo y existe cada audio. Devuelve {nombre: ruta}."""
    if not manifest_path.exists():
        sys.exit(f"Falta {manifest_path}: ejecuta tools/voice/export_app.py (o usa --exportar)")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != catalog.get("version"):
        sys.exit(f"El manifiesto de voz es de la versión {manifest.get('version')!r} y el catálogo de la "
                 f"{catalog.get('version')!r}: ejecuta tools/voice/export_app.py (o usa --exportar)")
    files, missing = {}, []
    for sid, story in manifest.get("cuentos", {}).items():
        folder = audio_dir if story.get("incluido") else cdn_dir
        clips = [story.get("titulo"), story.get("ensenanza"), *story.get("escenas", [])]
        for c in clips:
            if not c:
                continue
            path = folder / c["archivo"]
            if path.exists() and path.stat().st_size > 0:
                files[c["archivo"]] = path
            else:
                missing.append(f"{sid}: {path}")
    if missing:
        sys.exit(f"Faltan {len(missing)} audios (ejecuta tools/voice/export_app.py):\n  " + "\n  ".join(missing[:20]))
    ids = [c["id"] for c in catalog["cuentos"]]
    unvoiced = [i for i in ids if i not in manifest.get("cuentos", {})]
    if unvoiced:
        print(f"Aviso: {len(unvoiced)} cuentos sin voz grabada (los dirá la voz del teléfono): "
              + ", ".join(unvoiced[:10]) + (" …" if len(unvoiced) > 10 else ""))
    return files


def build(out, lang, catalog_path, catalog, packs, manifest_path, audio, version, motor):
    """Escribe la carpeta publicable en [out]. Devuelve el índice."""
    content = out / "contenido" / lang
    if content.exists():
        shutil.rmtree(content)
    (content / "paquetes").mkdir(parents=True)
    shutil.copyfile(catalog_path, content / "catalogo.json")
    shutil.copyfile(manifest_path, content / "voz.json")
    for pid, path in packs.items():
        shutil.copyfile(path, content / "paquetes" / f"{pid}.json")

    # El audio: se copia solo lo que falta (el nombre es la huella) y se quita lo que ya no se usa
    voice = out / "voz" / lang
    voice.mkdir(parents=True, exist_ok=True)
    for name, src in audio.items():
        dst = voice / name
        if not (dst.exists() and dst.stat().st_size == src.stat().st_size):
            shutil.copyfile(src, dst)
    for f in voice.glob("*.m4a"):
        if f.name not in audio:
            f.unlink()

    files = {}
    for f in sorted(content.rglob("*.json")):
        rel = f.relative_to(content).as_posix()
        files[rel] = {"sha256": sha256(f), "bytes": f.stat().st_size}
    index = {
        "formato": INDEX_FORMAT,
        "version": version,
        "motor": motor,
        "idioma": lang,
        "catalogo": catalog.get("version", ""),
        "publicado": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "archivos": files,
    }
    (content / "indice.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return index


def read_env(path):
    """KEY=VALOR por línea (sin comillas ni `export`). Solo llena las variables que el entorno no tiene."""
    values = {}
    for line in Path(path).expanduser().read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.removeprefix("export ").split("=", 1)
        values[key.strip()] = value.strip().strip("'\"")
    return {**values, **os.environ}


def upload(out, lang, env):
    try:
        import boto3
    except ImportError:
        sys.exit("Para --subir hace falta boto3: python3 -m pip install boto3")
    need = ["S3_ENDPOINT_URL", "S3_BUCKET", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
    lack = [k for k in need if not env.get(k)]
    if lack:
        sys.exit(f"Faltan credenciales: {', '.join(lack)} (en el entorno o en el archivo de --env)")
    s3 = boto3.client(
        "s3",
        endpoint_url=env["S3_ENDPOINT_URL"],
        aws_access_key_id=env["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=env["AWS_SECRET_ACCESS_KEY"],
        region_name=env.get("AWS_REGION", "auto"),
    )
    bucket = env["S3_BUCKET"]

    def put(path, key, kind, cache):
        s3.upload_file(str(path), bucket, key, ExtraArgs={"ContentType": kind, "CacheControl": cache})

    # 1. El audio que falta (lo que ya está tiene el mismo nombre, que es su huella)
    prefix = f"voz/{lang}/"
    there = set()
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
        there.update(o["Key"] for o in page.get("Contents", []))
    new = [f for f in sorted((out / "voz" / lang).glob("*.m4a")) if prefix + f.name not in there]
    print(f"Audio: {len(new)} nuevos por subir, {len(there)} ya estaban")
    for i, f in enumerate(new, 1):
        put(f, prefix + f.name, "audio/mp4", "public, max-age=31536000, immutable")
        if i % 50 == 0:
            print(f"  {i}/{len(new)}")

    # 2. Los paquetes, el catálogo y la voz; 3. al final, el índice
    content = out / "contenido" / lang
    files = [f for f in sorted(content.rglob("*.json")) if f.name != "indice.json" or f.parent != content]
    for f in files:
        put(f, f"contenido/{lang}/{f.relative_to(content).as_posix()}", "application/json; charset=utf-8",
            "public, max-age=300")
    put(content / "indice.json", f"contenido/{lang}/indice.json", "application/json; charset=utf-8",
        "public, max-age=60")
    print(f"Subido a {bucket}: {len(files)} archivos de contenido y, al final, contenido/{lang}/indice.json")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--idioma", default="es")
    ap.add_argument("--catalogo", type=Path, default=None, help="por defecto content/catalogo/lanzamiento-<idioma>.json")
    ap.add_argument("--paquetes", type=Path, default=ROOT / "content" / "packs")
    ap.add_argument("--voz-app", type=Path, default=None, help="por defecto app/assets/voz/<idioma>")
    ap.add_argument("--cdn", type=Path, default=None, help="por defecto builds/voz/cdn/<idioma>")
    ap.add_argument("--exportar", action="store_true", help="ejecuta antes tools/voice/export_app.py")
    ap.add_argument("--salida", type=Path, default=ROOT / "builds" / "publicar")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--en-carpeta", action="store_true", help="solo arma la carpeta (lo que se hace por defecto)")
    mode.add_argument("--subir", action="store_true", help="arma la carpeta y la sube al almacén S3 (R2)")
    ap.add_argument("--env", type=Path, default=None, help="archivo .env con las credenciales para --subir")
    ap.add_argument("--version", type=int, default=None, help="versión a mano (por defecto, la fecha y hora UTC)")
    a = ap.parse_args()

    lang = a.idioma
    catalog_path = a.catalogo or ROOT / "content" / "catalogo" / f"lanzamiento-{lang}.json"
    voice_app = a.voz_app or ROOT / "app" / "assets" / "voz" / lang
    cdn = a.cdn or ROOT / "builds" / "voz" / "cdn" / lang
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("idioma", "es") != lang:
        sys.exit(f"{catalog_path} es de «{catalog.get('idioma')}», no de «{lang}»")

    pack_ids = sorted({c["id"].split(":")[0] for c in catalog["cuentos"]})
    packs = {pid: a.paquetes / pid / "pack.json" for pid in pack_ids}
    for pid, path in packs.items():
        if not path.exists():
            sys.exit(f"El catálogo usa el paquete «{pid}» y no existe {path}")
        premises = {p["id"] for p in json.loads(path.read_text(encoding="utf-8")).get("premises", [])}
        lost = [c["id"] for c in catalog["cuentos"] if c["id"].startswith(pid + ":")
                and c["id"].split(":")[1] not in premises]
        if lost:
            sys.exit(f"Cuentos del catálogo que no están en {path}: {', '.join(lost)}")

    validate_packs(list(packs.values()))
    if a.exportar:
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "voice" / "export_app.py"),
                            "--catalogo", str(catalog_path)], cwd=ROOT)
        if r.returncode != 0:
            sys.exit("export_app.py falló")
    audio = check_voice(voice_app / "manifiesto.json", catalog, voice_app / "audio", cdn)

    version = a.version or int(datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S"))
    index = build(a.salida, lang, catalog_path, catalog, packs, voice_app / "manifiesto.json", audio, version,
                  engine_version())
    news = [c["id"] for c in catalog["cuentos"] if c.get("desde") == catalog.get("version")]
    mb = sum(p.stat().st_size for p in audio.values()) / 1e6
    print(f"Listo en {a.salida}: versión {version}, motor {index['motor']}, catálogo {index['catalogo']} "
          f"({len(catalog['cuentos'])} cuentos, {len(news)} nuevos con «desde»), {len(packs)} paquetes, "
          f"{len(audio)} audios ({mb:.1f} MB)")
    if not news:
        print("Aviso: ningún cuento tiene «desde» igual a la versión del catálogo; ninguno llevará «Nuevo»")
    if a.subir:
        upload(a.salida, lang, read_env(a.env) if a.env else dict(os.environ))


if __name__ == "__main__":
    main()
