#!/usr/bin/env python3
"""Mete una premisa (y, si hace falta, personajes secundarios u objetos de la trama nuevos) en un pack.

Uso:
    python3 tools/content/merge_premise.py premisa.json [--pack content/packs/medieval/pack.json] [--out otro.json]

`premisa.json` es un objeto con la premisa en la clave `premise` y, opcionalmente, `props` (objetos nuevos para
`pack.props`). Si ya existe una premisa con ese `id`, la sustituye (así se itera sobre el mismo archivo). Sin `--out`
escribe sobre el propio pack. Con `--out` el pack original no se toca: sirve para validar un borrador aparte:

    python3 tools/content/merge_premise.py mi.json --out /tmp/borrador.json
    dart run packages/caldero_engine/bin/validate_pack.dart /tmp/borrador.json
"""
import argparse
import json
import sys
from pathlib import Path

DEFAULT_PACK = Path(__file__).resolve().parents[2] / "content/packs/medieval/pack.json"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("premise")
    ap.add_argument("--pack", default=str(DEFAULT_PACK))
    ap.add_argument("--out")
    a = ap.parse_args()

    pack = json.loads(Path(a.pack).read_text(encoding="utf-8"))
    src = json.loads(Path(a.premise).read_text(encoding="utf-8"))
    premise = src.get("premise")
    if not isinstance(premise, dict) or "id" not in premise:
        sys.exit("el archivo debe ser {\"premise\": {...}, \"props\": [...]} con un `id` en la premisa")

    for prop in src.get("props", []):
        if all(p["id"] != prop["id"] for p in pack["props"]):
            pack["props"].append(prop)
    pack["premises"] = [p for p in pack["premises"] if p["id"] != premise["id"]] + [premise]

    out = Path(a.out or a.pack)
    out.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{premise['id']} ({premise.get('value')}, {premise.get('ages')}) → {out}")


if __name__ == "__main__":
    main()
