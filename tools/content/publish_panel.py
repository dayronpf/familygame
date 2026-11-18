#!/usr/bin/env python3
"""Publica los cuentos que se mandaron a publicar desde el panel (docs/37).

El panel (cuentos2.tuvendor.com/admin) guarda los cambios como borradores y los pone en una cola. Este programa:

1. lee la cola del servidor (GET /internal/contenido/cola, con el token del gancho de despliegue);
2. aplica cada cambio a content/packs/<pack>/pack.json y al catálogo de la app (content/catalogo/lanzamiento-es.json):
   cuento nuevo o editado → se agrega o se reemplaza; eliminar → se quita del pack y del catálogo;
3. valida cada pack con el motor (dart run bin/validate_pack.dart). Si un cambio no pasa, se deshace solo ese cambio y
   el panel muestra el error en la ficha del cuento;
4. graba la voz de los cuentos que cambiaron (ElevenLabs, render_catalog.py). Si no hay créditos sigue sin voz: la
   app los lee con la voz del teléfono hasta que se graben;
5. prepara el audio (export_app.py) y publica en R2 (publish.py --subir): la app recibe los cuentos sin actualizarse;
6. sube los cambios a git (rama de trabajo y rama `servidor`): el despliegue vuelve a importar los packs y el panel
   marca los cuentos como publicados;
7. avisa al servidor del resultado de cada cuento.

Uso (desde la raíz del repositorio):
    python3 tools/content/publish_panel.py                 # todo
    python3 tools/content/publish_panel.py --prueba        # aplica y valida, sin voz, sin subir nada (deshace al final)
    python3 tools/content/publish_panel.py --sin-voz       # publica sin grabar la voz
Necesita: dart, ffmpeg, boto3 (para R2) y credenciales/.env (MININOCHES_DEPLOY_TOKEN o DEPLOY_TOKEN, ELEVENLABS_*, R2).
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "packages" / "caldero_engine"
PACKS = ROOT / "content" / "packs"
CATALOG = ROOT / "content" / "catalogo" / "lanzamiento-es.json"
VOICE = ROOT / "builds" / "voz"
VENV_PY = Path("/Users/vida/Documents/GitHub/.voicetest-venv/bin/python")


def env_values(path):
    out = {}
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip().strip('"').strip("'")
    out.update({k: v for k, v in os.environ.items() if k in out or k.startswith(("MININOCHES_", "DEPLOY_"))})
    return out


def api(server, token, path, body=None):
    req = urllib.request.Request(server.rstrip("/") + path, method="POST" if body is not None else "GET",
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {token}", "Accept": "application/json",
                                          "Content-Type": "application/json", "User-Agent": "mininoches-publicar"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save_pack(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def save_catalog(data):
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def bump_patch(v):
    parts = (v or "1.0.0").split(".")
    parts[-1] = str(int(parts[-1]) + 1) if parts[-1].isdigit() else parts[-1] + ".1"
    return ".".join(parts)


def bump_minor(v):
    major, _, minor = (v or "1.0").partition(".")
    return f"{major}.{int(minor or 0) + 1}" if (minor or "0").isdigit() else v + ".1"


def validate(pack_path):
    r = subprocess.run(["dart", "run", "bin/validate_pack.dart", str(pack_path.resolve())], cwd=ENGINE,
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def readable(output, premise_id):
    """Las líneas del motor que tocan a este cuento, sin rutas, sin ids técnicos y sin repetir."""
    out = []
    for line in output.splitlines():
        line = line.strip().lstrip("-").strip()
        if not line or line.startswith("/") or "renders" in line:
            continue
        if premise_id and not line.startswith(premise_id) and premise_id not in line:
            continue
        line = re.sub(r"^\S+\s*\[[^\]]*\]:\s*", "", line)      # «atajo_anillo [hero=…]: »
        line = re.sub(r"\s*\([a-z0-9_]+(\.[a-z0-9_]+){1,3}\)", "", line)  # «(atajo_anillo.escena_11.…)»
        line = line.replace("(falta moves: true)", "(marca «Cambia de lugar» en el dibujo de la escena)")
        line = re.sub(r"«time: (\w+)»", r"«\1»", line)
        line = line[0].upper() + line[1:] if line else line
        if line not in out:
            out.append(line)
    return out


def apply(item, pack, catalog):
    """Aplica un cambio al pack y al catálogo (en memoria)."""
    pid, ref = item["id"], item["ref"]
    premises = pack["premises"]
    idx = next((i for i, p in enumerate(premises) if p.get("id") == pid), None)
    entries = catalog["cuentos"]
    cidx = next((i for i, c in enumerate(entries) if c.get("id") == ref), None)
    if item["op"] == "eliminar":
        if idx is not None:
            premises.pop(idx)
        if cidx is not None:
            entries.pop(cidx)
        catalog["gratis"] = [g for g in catalog.get("gratis", []) if g != ref]
        return
    premise = item["premise"]
    premise["id"] = pid
    if idx is None:
        premises.append(premise)
    else:
        premises[idx] = premise
    entry = item.get("catalog")
    if entry:
        entry = {k: entry[k] for k in ("id", "titulo", "edad", "valor", "semilla", "heroe", "generoHeroe", "caracteres") if k in entry}
        entry["id"] = ref
        if cidx is None:
            entries.append(entry)
        else:
            entries[cidx] = entry
    elif cidx is not None:
        entries.pop(cidx)
        catalog["gratis"] = [g for g in catalog.get("gratis", []) if g != ref]


def run(cmd, **kw):
    print("  $ " + " ".join(str(c) for c in cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT, **kw)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--servidor", default="https://cuentos2.tuvendor.com")
    ap.add_argument("--env", type=Path, default=ROOT / "credenciales" / ".env")
    ap.add_argument("--sin-voz", action="store_true", help="no graba la voz (la app usa la voz del teléfono)")
    ap.add_argument("--prueba", action="store_true", help="aplica y valida, sin voz ni subir nada, y lo deshace")
    a = ap.parse_args()

    env = env_values(a.env)
    token = env.get("MININOCHES_DEPLOY_TOKEN") or env.get("DEPLOY_TOKEN")
    if not token:
        sys.exit("Falta MININOCHES_DEPLOY_TOKEN (o DEPLOY_TOKEN) en credenciales/.env")
    if shutil.which("dart") is None:
        sys.exit("Falta dart en el PATH (hace falta para validar los packs)")

    items = api(a.servidor, token, "/internal/contenido/cola")["items"]
    if not items:
        print("No hay cuentos en cola. Nada que publicar.")
        return
    print(f"{len(items)} cuentos en cola: " + ", ".join(f"{i['ref']} ({i['op']})" for i in items))

    originals = {CATALOG: CATALOG.read_text(encoding="utf-8")}
    catalog = load(CATALOG)
    results, applied, changed_packs = [], [], {}
    for item in items:
        pack_path = PACKS / item["pack"] / "pack.json"
        if not pack_path.is_file():
            results.append({"ref": item["ref"], "ok": False, "error": f"No existe el pack {item['pack']}.", "updatedAt": item.get("updatedAt")})
            continue
        originals.setdefault(pack_path, pack_path.read_text(encoding="utf-8"))
        pack = changed_packs.get(pack_path) or load(pack_path)
        before_pack = json.dumps(pack, ensure_ascii=False)
        before_catalog = json.dumps(catalog, ensure_ascii=False)
        apply(item, pack, catalog)
        save_pack(pack_path, pack)
        ok, out = validate(pack_path)
        if ok:
            changed_packs[pack_path] = pack
            applied.append(item)
            print(f"  ✓ {item['ref']}")
        else:
            pack = json.loads(before_pack)
            catalog = json.loads(before_catalog)
            save_pack(pack_path, pack)
            if pack_path in changed_packs:
                changed_packs[pack_path] = pack
            lines = readable(out, item["id"])[:12] or [l for l in out.splitlines() if l.strip()][-8:]
            results.append({"ref": item["ref"], "ok": False, "updatedAt": item.get("updatedAt"),
                            "error": "El texto y el dibujo no coinciden o falta algo:\n" + "\n".join("• " + l for l in lines)})
            print(f"  ✗ {item['ref']}: no pasó la validación")

    def restore():
        for path, text in originals.items():
            path.write_text(text, encoding="utf-8")

    if not applied:
        restore()
        if results:
            api(a.servidor, token, "/internal/contenido/resultado", {"results": results})
        sys.exit("Ningún cambio pasó la validación (el panel muestra el error de cada cuento).")

    for path, pack in changed_packs.items():
        pack["pack"]["version"] = bump_patch(pack["pack"].get("version"))
        save_pack(path, pack)
    catalog["version"] = bump_minor(catalog.get("version"))
    save_catalog(catalog)

    if a.prueba:
        print(f"Prueba: {len(applied)} cambios aplicados y validados. Se deshacen.")
        restore()
        return

    # Texto de cada cuento del catálogo y caracteres de los que cambiaron
    textos = VOICE / "textos-es.json"
    VOICE.mkdir(parents=True, exist_ok=True)
    r = run(["dart", "run", "bin/catalog_texts.dart", str(CATALOG), str(textos)], cwd=ENGINE)
    if r.returncode != 0:
        restore()
        sys.exit("No se pudieron generar los textos del catálogo.")
    texts = {t["id"]: t for t in load(textos)["cuentos"]}
    refs = [i["ref"] for i in applied if i["op"] != "eliminar" and i["ref"] in texts]
    for entry in catalog["cuentos"]:
        if entry["id"] in refs:
            entry["caracteres"] = sum(len(s if isinstance(s, str) else s.get("texto", "")) for s in texts[entry["id"]].get("escenas", []))
    save_catalog(catalog)

    python = str(VENV_PY) if VENV_PY.exists() else sys.executable
    if refs and not a.sin_voz:
        lote = VOICE / "panel.json"
        lote.write_text(json.dumps(refs), encoding="utf-8")
        print(f"Grabando la voz de {len(refs)} cuentos…")
        run([python, "-I", "tools/voice/render_catalog.py", str(textos), "--solo", str(lote)])
    r = run([python, "-I", "tools/voice/export_app.py"])
    if r.returncode != 0:
        restore()
        sys.exit("export_app.py falló: no se publicó nada.")
    r = run([python, "-I", "tools/content/publish.py", "--subir"])
    if r.returncode != 0:
        restore()
        sys.exit("La publicación en R2 falló: no se publicó nada.")

    files = [str(p.relative_to(ROOT)) for p in changed_packs] + [str(CATALOG.relative_to(ROOT)), "app/assets/voz"]
    run(["git", "add", *files])
    msg = "Cuentos del panel: " + ", ".join(f"{i['ref']} ({i['op']})" for i in applied)
    run(["git", "commit", "-m", msg + "\n\nPublicado con tools/content/publish_panel.py desde la cola del panel."])
    pushed = run(["git", "push", "origin", "HEAD"]).returncode == 0 and run(["git", "push", "origin", "HEAD:servidor"]).returncode == 0
    if not pushed:
        print("Aviso: no se pudo subir a git. La app ya tiene los cuentos (R2), pero el panel no los verá publicados hasta subirlo.")

    results += [{"ref": i["ref"], "ok": True, "updatedAt": i.get("updatedAt")} for i in applied]
    api(a.servidor, token, "/internal/contenido/resultado", {"results": results})
    print(f"Listo: {len(applied)} publicados, {len(results) - len(applied)} con error.")


if __name__ == "__main__":
    main()
