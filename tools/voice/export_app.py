#!/usr/bin/env python3
"""Prepara para la app la voz grabada del catálogo (docs/31, paso A6).

Lee lo que dejó la grabación (`builds/voz/manifiesto.json` y sus mp3, ver render_catalog.py) y:

1. convierte cada audio a AAC (.m4a) mono de 64 kbps, que pesa la mitad y suena igual de bien para una voz;
2. pone los audios de los cuentos gratis (la lista «gratis» del catálogo) dentro de la app, en
   `app/assets/voz/<idioma>/audio/`;
3. pone los demás en `builds/voz/cdn/<idioma>/`: es la carpeta que se sube tal cual al servidor (Cloudflare R2, A8);
4. escribe `app/assets/voz/<idioma>/manifiesto.json`, el que lee la app (RecordedVoice.parse):
       cuentos → {incluido, titulo: {texto, archivo, segundos}, ensenanza: {…}, escenas: [{texto, archivo, segundos}]}
   con archivo = <huella>.m4a.

Se puede lanzar las veces que haga falta: solo convierte los audios nuevos o cambiados, y borra de las dos carpetas
los .m4a que ya no se usan (por ejemplo, si un cuento dejó de ser gratis pasa de la app a la carpeta del servidor).

Uso (desde la raíz del repositorio; necesita ffmpeg):
    python3 tools/voice/export_app.py
    python3 tools/voice/export_app.py --catalogo content/catalogo/lanzamiento-es.json --voz builds/voz
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

KBPS = 64


def convert(src, dst, kbps):
    """mp3 → m4a mono. Escribe primero a un archivo aparte, para no dejar uno a medias si se corta."""
    tmp = dst.with_name(dst.stem + ".parcial.m4a")
    subprocess.run(
        ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", str(src),
         "-vn", "-ac", "1", "-c:a", "aac", "-b:a", f"{kbps}k", "-movflags", "+faststart", str(tmp)],
        check=True,
    )
    tmp.replace(dst)


def fresh(src, dst):
    return dst.exists() and dst.stat().st_size > 0 and dst.stat().st_mtime >= src.stat().st_mtime


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--catalogo", type=Path, default=Path("content/catalogo/lanzamiento-es.json"))
    ap.add_argument("--voz", type=Path, default=Path("builds/voz"), help="carpeta de la grabación (manifiesto.json)")
    ap.add_argument("--app", type=Path, default=None, help="por defecto app/assets/voz/<idioma>")
    ap.add_argument("--cdn", type=Path, default=None, help="por defecto builds/voz/cdn/<idioma>")
    ap.add_argument("--kbps", type=int, default=KBPS)
    a = ap.parse_args()

    if shutil.which("ffmpeg") is None:
        sys.exit("Falta ffmpeg (brew install ffmpeg)")
    catalog = json.loads(a.catalogo.read_text(encoding="utf-8"))
    lang = catalog.get("idioma", "es")
    free = set(catalog.get("gratis", []))
    ids = [c["id"] for c in catalog["cuentos"]]
    source = json.loads((a.voz / "manifiesto.json").read_text(encoding="utf-8"))
    recorded = source["cuentos"]
    app_dir = a.app or Path("app/assets/voz") / lang
    cdn_dir = a.cdn or a.voz / "cdn" / lang
    audio_dir = app_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    cdn_dir.mkdir(parents=True, exist_ok=True)

    missing = [i for i in ids if i not in recorded]
    extra = sorted(set(recorded) - set(ids))
    if missing:
        print(f"Sin grabar ({len(missing)}), sonarán con la voz del teléfono: {', '.join(missing)}")
    if extra:
        print(f"Grabados pero fuera del catálogo (no se exportan): {', '.join(extra)}")

    jobs = {}  # destino → origen
    out = {}
    for sid in ids:
        story = recorded.get(sid)
        if story is None:
            continue
        bundled = sid in free
        dest_dir = audio_dir if bundled else cdn_dir

        def clip(raw):
            src = a.voz / raw["archivo"]
            if not src.exists():
                sys.exit(f"{sid}: falta el audio {src}")
            name = (raw.get("huella") or Path(raw["archivo"]).stem) + ".m4a"
            jobs[dest_dir / name] = src
            return {"texto": raw["texto"], "archivo": name, "segundos": raw.get("segundos", 0)}

        entry = {"incluido": bundled}
        if story.get("titulo_audio"):
            entry["titulo"] = clip(story["titulo_audio"])
        if story.get("ensenanza_audio"):
            entry["ensenanza"] = clip(story["ensenanza_audio"])
        entry["escenas"] = [clip(s) for s in story.get("escenas", [])]
        out[sid] = entry

    todo = [(src, dst) for dst, src in jobs.items() if not fresh(src, dst)]
    print(f"{len(jobs)} audios, {len(todo)} por convertir a AAC mono {a.kbps} kbps…")
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        list(pool.map(lambda job: convert(*job, a.kbps), todo))

    # Lo que ya no se usa (o se movió de carpeta) se borra, para que la app no cargue audios de más
    removed = 0
    for folder in (audio_dir, cdn_dir):
        for f in folder.glob("*.m4a"):
            if f not in jobs:
                f.unlink()
                removed += 1

    manifest = {
        "version": catalog.get("version", ""),
        "idioma": lang,
        "voz": source.get("voz"),
        "cuentos": out,
    }
    (app_dir / "manifiesto.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    def size(folder):
        return sum(f.stat().st_size for f in folder.glob("*.m4a")) / 1e6

    n_app = sum(1 for v in out.values() if v["incluido"])
    print(f"{len(out)} cuentos en {app_dir / 'manifiesto.json'}"
          f" · en la app: {n_app} cuentos, {size(audio_dir):.1f} MB ({audio_dir})"
          f" · para el servidor: {len(out) - n_app} cuentos, {size(cdn_dir):.1f} MB ({cdn_dir})"
          + (f" · {removed} audios viejos borrados" if removed else ""))


if __name__ == "__main__":
    main()
