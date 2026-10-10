#!/usr/bin/env python3
"""Valida packs contra content/schema/pack.schema.json.

Uso: python3 tools/validate_schema.py content/packs/*/pack.json
Requiere: pip install jsonschema
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

SCHEMAS = {1: "pack.schema.json", 2: "pack-2.schema.json"}  # según pack.schema del propio pack
validators = {
    v: Draft202012Validator(json.loads((Path(__file__).parent.parent / "content/schema" / f).read_text(encoding="utf-8")))
    for v, f in SCHEMAS.items()
}
failed = False
for path in sys.argv[1:]:
    pack = json.loads(Path(path).read_text(encoding="utf-8"))
    version = pack.get("pack", {}).get("schema")
    if version not in validators:
        print(f"{path}: esquema de pack desconocido: {version!r}")
        failed = True
        continue
    errors = sorted(validators[version].iter_errors(pack), key=lambda e: list(e.path))
    print(f"{path}: {len(errors)} problemas")
    for e in errors:
        print(f" - /{'/'.join(map(str, e.path))}: {e.message}")
    failed |= bool(errors)
sys.exit(1 if failed else 0)
