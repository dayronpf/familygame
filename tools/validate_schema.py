#!/usr/bin/env python3
"""Valida packs contra content/schema/pack.schema.json.

Uso: python3 tools/validate_schema.py content/packs/*/pack.json
Requiere: pip install jsonschema
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

schema = json.loads((Path(__file__).parent.parent / "content/schema/pack.schema.json").read_text(encoding="utf-8"))
validator = Draft202012Validator(schema)
failed = False
for path in sys.argv[1:]:
    errors = sorted(validator.iter_errors(json.loads(Path(path).read_text(encoding="utf-8"))), key=lambda e: list(e.path))
    print(f"{path}: {len(errors)} problemas")
    for e in errors:
        print(f" - /{'/'.join(map(str, e.path))}: {e.message}")
    failed |= bool(errors)
sys.exit(1 if failed else 0)
