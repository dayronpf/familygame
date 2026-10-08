#!/usr/bin/env python3
"""Prototipo (spike S-01) del «caldero mágico».

Lee un pack de contenido (JSON), elige reparto y fragmentos según una
enseñanza y arma un cuento coherente. No es el motor final (ese irá en
Dart); sirve para validar el modelo de contenido y como oráculo de pruebas.

Uso:
    python3 tools/prototype/caldero.py --pack content/packs/demo --seed 7 --value honestidad
    python3 tools/prototype/caldero.py --pack content/packs/demo --lint
"""
import argparse
import itertools
import json
import random
import re
import sys
from pathlib import Path

STAGES = ["opening", "trouble", "helper", "test", "climax", "resolution", "closing"]
TOKEN = re.compile(r"\{(\w+)(?:\.(\w+))?\}")
# «Y La urraca…»: artículo capitalizado que no abre frase (error típico de plantilla).
MID_SENTENCE_CAPS = re.compile(r"[^.!?»¿¡\s]\s+(?:El|La|Un|Una|En)\s\w+")


def cap(s):
    return s[:1].upper() + s[1:]


def forms(e):
    """Formas gramaticales de una entidad (concordancia de género)."""
    m = e["gender"] == "m"
    art, uno = ("el", "un") if m else ("la", "una")
    noun = e["noun"]
    f = {
        None: e.get("given", noun),
        "noun": noun,
        "el": f"{art} {noun}",
        "un": f"{uno} {noun}",
        "del": f"del {noun}" if m else f"de la {noun}",
        "al": f"al {noun}" if m else f"a la {noun}",
        "en": f"en {art} {noun}",
        "o": "o" if m else "a",
    }
    if "trait" in e:
        f["trait"] = e["trait"]["m" if m else "f"]
    for k in ("el", "un", "en"):
        f[cap(k)] = cap(f[k])
    return f


def render(text, cast):
    def sub(match):
        role, attr = match.group(1), match.group(2)
        if role not in cast:
            raise KeyError(f"rol desconocido «{role}» en: {text[:50]}…")
        table = forms(cast[role])
        if attr not in table:
            raise KeyError(f"forma «{role}.{attr}» no existe para {cast[role]['id']}")
        return table[attr]

    return TOKEN.sub(sub, text)


def load(pack_dir):
    return json.loads((Path(pack_dir) / "pack.json").read_text(encoding="utf-8"))


def pick_fragment(pack, stage, value, state, used, rng):
    cands = [
        f for f in pack["fragments"]
        if f["stage"] == stage
        and ("*" in f["values"] or value in f["values"])
        and set(f.get("requires", [])) <= state
        and f["id"] not in used
    ]
    specific = [f for f in cands if "*" not in f["values"]]
    pool = specific or cands
    if not pool:
        raise LookupError(f"sin fragmento para etapa={stage} valor={value} estado={sorted(state)}")
    return rng.choice(pool)


def cast_story(pack, rng):
    chars = pack["characters"]
    hero = rng.choice([c for c in chars if "hero" in c["roles"]])
    helper = rng.choice([c for c in chars if "helper" in c["roles"] and c["id"] != hero["id"]])
    villain = rng.choice([c for c in chars if "villain" in c["roles"]])
    place, place2 = rng.sample(pack["places"], 2)
    return {"hero": hero, "helper": helper, "villain": villain, "place": place, "place2": place2}


def make_story(pack, seed, value=None):
    rng = random.Random(seed)
    moral = next((m for m in pack["morals"] if m["id"] == value), None) if value else rng.choice(pack["morals"])
    if moral is None:
        raise SystemExit(f"valor desconocido: {value}")
    cast = cast_story(pack, rng)
    state, used, scenes = set(), set(), []
    for stage in STAGES:
        frag = pick_fragment(pack, stage, moral["id"], state, used, rng)
        used.add(frag["id"])
        state |= set(frag.get("adds", []))
        scenes.append({"id": frag["id"], "text": render(frag["text"], cast), "scene": frag.get("scene", {})})
    return {"seed": seed, "moral": moral, "cast": cast, "scenes": scenes}


def lint(pack):
    """Renderiza cada fragmento con todos los repartos posibles; detecta fallos."""
    chars, places = pack["characters"], pack["places"]
    errors, n = [], 0
    for h, he, v in itertools.product(
        [c for c in chars if "hero" in c["roles"]],
        [c for c in chars if "helper" in c["roles"]],
        [c for c in chars if "villain" in c["roles"]],
    ):
        if h["id"] == he["id"]:
            continue
        for p, p2 in itertools.permutations(places, 2):
            cast = {"hero": h, "helper": he, "villain": v, "place": p, "place2": p2}
            for f in pack["fragments"]:
                n += 1
                try:
                    out = render(f["text"], cast)
                except KeyError as e:
                    errors.append(f"{f['id']}: {e}")
                    continue
                if "  " in out or "{" in out or not out.rstrip().endswith((".", "!", "?", "»")):
                    errors.append(f"{f['id']}: texto sospechoso: {out[-40:]!r}")
                mid = MID_SENTENCE_CAPS.search(out)
                if mid:
                    errors.append(f"{f['id']}: artículo en mayúscula a mitad de frase: «{mid.group(0)}»")
    # Cobertura: toda enseñanza debe poder recorrer todas las etapas.
    for m in pack["morals"]:
        for seed in range(50):
            try:
                make_story(pack, seed, m["id"])
            except LookupError as e:
                errors.append(f"cobertura «{m['id']}» semilla {seed}: {e}")
                break
    return n, sorted(set(errors))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pack", required=True)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--value", help="enseñanza: honestidad | generosidad | valentia")
    ap.add_argument("--debug", action="store_true", help="muestra ids de fragmento y directivas de escena")
    ap.add_argument("--lint", action="store_true")
    args = ap.parse_args()

    pack = load(args.pack)
    if args.lint:
        n, errors = lint(pack)
        print(f"{n} renders comprobados, {len(errors)} problemas")
        for e in errors:
            print(" -", e)
        sys.exit(1 if errors else 0)

    story = make_story(pack, args.seed, args.value)
    for s in story["scenes"]:
        if args.debug:
            print(f"[{s['id']}] {json.dumps(s['scene'], ensure_ascii=False)}")
        print(s["text"], end="\n\n")
    print(f"Enseñanza: {story['moral']['text']}")


if __name__ == "__main__":
    main()
