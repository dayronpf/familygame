#!/usr/bin/env python3
"""Graba con ElevenLabs las escenas de un catálogo de cuentos fijos (docs/31, paso A5).

1. Primero se saca el texto de cada cuento con el motor (el mismo que mostrará la app):
       cd packages/caldero_engine
       dart run bin/catalog_texts.dart ../../content/catalogo/lanzamiento-es.json ../../builds/voz/textos-es.json
2. Luego se graba (se puede cortar y volver a lanzar: lo ya grabado no se repite ni se paga dos veces):
       python3 tools/voice/render_catalog.py builds/voz/textos-es.json --solo builds/voz/tanda1.json

Cada escena se pide con el texto de la escena anterior y de la siguiente (previous_text / next_text), para que la
entonación siga el hilo del cuento. Cada audio se llama por la huella de su texto y de la voz: si el texto cambia, solo
esa escena se vuelve a grabar. Escribe `manifiesto.json` (cuento → escenas → archivo, caracteres y duración).

Con --revisar, un transcriptor (mlx-whisper) escucha cada escena y la compara con el texto; las que no coinciden se
graban otra vez una sola vez y, si siguen mal, quedan en la lista para revisarlas a oído.

La clave sale de la variable ELEVENLABS_API_KEY o de un archivo .env (--env); nunca se escribe en el código ni se muestra.
"""
import argparse
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

VOICE = "1BxAZWANeDIxeyHKSJF2"  # Isabela (biblioteca de ElevenLabs, uso comercial)
MODEL = "eleven_multilingual_v2"
SETTINGS = {"stability": 0.55, "similarity_boost": 0.8, "style": 0.15, "speed": 0.92}
FORMAT = "mp3_44100_128"


def api_key(env_file):
    if os.environ.get("ELEVENLABS_API_KEY"):
        return os.environ["ELEVENLABS_API_KEY"]
    for line in Path(env_file).read_text(encoding="utf-8").splitlines():
        if line.startswith("ELEVENLABS_API_KEY="):
            return line.split("=", 1)[1].strip().strip("\"'")
    sys.exit(f"No encontré ELEVENLABS_API_KEY en el entorno ni en {env_file}")


def fingerprint(text):
    raw = json.dumps([VOICE, MODEL, SETTINGS, FORMAT, text], ensure_ascii=False, sort_keys=True)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:16]


class QuotaExceeded(Exception):
    pass


def tts(key, text, prev, nxt):
    body = {"text": text, "model_id": MODEL, "language_code": "es", "voice_settings": SETTINGS}
    if prev:
        body["previous_text"] = prev
    if nxt:
        body["next_text"] = nxt
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE}?output_format={FORMAT}",
        data=json.dumps(body).encode(),
        headers={"xi-api-key": key, "Content-Type": "application/json", "User-Agent": "mininoches-render"},
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")
            if e.code in (401, 402) and ("quota" in detail or "credits" in detail):
                raise QuotaExceeded(detail[:300])
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            raise RuntimeError(f"ElevenLabs {e.code}: {detail[:300]}")
    raise RuntimeError("ElevenLabs no respondió")


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True)
    try:
        return round(float(out.stdout.strip()), 2)
    except ValueError:
        return None


def words(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.findall(r"[a-zñ]+", s)


def mismatch(text, heard):
    a, b = words(text), words(heard)
    ok = sum(m.size for m in difflib.SequenceMatcher(None, a, b).get_matching_blocks())
    return 1 - ok / max(len(a), 1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("textos", type=Path, help="JSON de bin/catalog_texts.dart")
    ap.add_argument("--solo", type=Path, help="JSON con la lista de ids de cuentos a grabar (una tanda)")
    ap.add_argument("--salida", type=Path, default=Path("builds/voz"), help="carpeta de audio y manifiesto")
    ap.add_argument("--env", default="/Users/vida/Documents/proyectos/canal youtube/.env")
    ap.add_argument("--revisar", action="store_true", help="comprobar cada escena con mlx-whisper")
    ap.add_argument("--umbral", type=float, default=0.12, help="diferencia máxima de palabras aceptada")
    a = ap.parse_args()

    catalog = json.loads(a.textos.read_text(encoding="utf-8"))
    wanted = set(json.loads(a.solo.read_text())) if a.solo else None
    audio_dir = a.salida / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = a.salida / "manifiesto.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"voz": VOICE, "modelo": MODEL, "cuentos": {}}
    key = api_key(a.env)
    whisper = None
    if a.revisar:
        import mlx_whisper  # noqa: PLC0415 (solo si se pide)
        whisper = mlx_whisper

    spent = 0
    flagged = []
    stories = [c for c in catalog["cuentos"] if wanted is None or c["id"] in wanted]
    try:
        for n, story in enumerate(stories, 1):
            scenes = story["escenas"]
            entry = {"titulo": story["titulo"], "escenas": []}
            for i, text in enumerate(scenes):
                h = fingerprint(text)
                path = audio_dir / f"{h}.mp3"
                tries = 0
                while True:
                    if not path.exists():
                        data = tts(key, text, scenes[i - 1] if i else None, scenes[i + 1] if i + 1 < len(scenes) else None)
                        path.write_bytes(data)
                        spent += len(text)
                        tries += 1
                    diff = None
                    if whisper:
                        heard = whisper.transcribe(str(path), path_or_hf_repo="mlx-community/whisper-large-v3-turbo",
                                                   language="es")["text"]
                        diff = round(mismatch(text, heard), 3)
                        if diff > a.umbral and tries < 2:
                            path.unlink()  # se graba otra vez, una sola vez
                            continue
                        if diff > a.umbral:
                            flagged.append({"cuento": story["id"], "escena": i + 1, "diferencia": diff, "oido": heard})
                    break
                entry["escenas"].append({"archivo": f"audio/{h}.mp3", "huella": h, "texto": text, "caracteres": len(text),
                                         "segundos": duration(path), **({"diferencia": diff} if diff is not None else {})})
            # Título y enseñanza (la app los dice al empezar y al terminar): cada uno, su clip.
            for field, text in (("titulo_audio", story["titulo"]),
                                ("ensenanza_audio", f"La enseñanza de hoy: {story['ensenanza']}")):
                h = fingerprint(text)
                path = audio_dir / f"{h}.mp3"
                if not path.exists():
                    path.write_bytes(tts(key, text, None, None))
                    spent += len(text)
                entry[field] = {"archivo": f"audio/{h}.mp3", "texto": text, "segundos": duration(path)}
            manifest["cuentos"][story["id"]] = entry
            manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
            print(f"[{n}/{len(stories)}] {story['id']} · {len(scenes)} escenas · gastados {spent} caracteres", flush=True)
    except QuotaExceeded as e:
        print(f"\nSe acabaron los créditos de ElevenLabs: {e}\nRecarga y vuelve a lanzar el mismo comando: sigue donde quedó.")
    finally:
        if flagged:
            (a.salida / "revisar.json").write_text(json.dumps(flagged, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"Caracteres gastados en esta pasada: {spent}. Escenas para revisar a oído: {len(flagged)}")


if __name__ == "__main__":
    main()
