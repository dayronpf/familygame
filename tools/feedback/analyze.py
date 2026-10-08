#!/usr/bin/env python3
"""Análisis de valoraciones: ¿qué fragmentos y transiciones hacen peores los cuentos?

Lee eventos con el MISMO formato que envía la app (docs/api/feedback.openapi.yaml), en formato
JSON Lines (un evento por línea) o un JSON con {"events": [...]}.

Método (validado por simulación en tools/feedback/simulate.py):
  * Regresión ridge: nota ≈ media + efecto(enseñanza) + Σ efecto(fragmento) + Σ efecto(transición).
    Estimar todos los efectos a la vez evita confundir «este fragmento» con «esta enseñanza».
  * El ridge encoge hacia 0 los efectos con pocos datos (no se culpa a un fragmento por azar).
  * Un fragmento se MARCA para revisión humana solo si su efecto < -0.3 y z < -2 con ≥ 20 apariciones.
  * Nunca decide solo: marca; una persona revisa el texto y decide (o se baja su peso en el pack).

Uso: python3 tools/feedback/analyze.py ratings.jsonl [--pack demo] [--pack-version 1.0.0] [--top 10]
"""
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np

MIN_APPEARANCES = 20  # apariciones mínimas para marcar un fragmento
EFFECT_THRESHOLD = -0.3  # efecto mínimo (en puntos de nota) para marcar
Z_THRESHOLD = -2.0
MIN_PAIR_APPEARANCES = 30
LAMBDA = 9.0  # ≈ σ²/τ² con σ≈0.9 (ruido) y τ≈0.3 (efectos esperables)


def ridge(X, y, lam=LAMBDA):
    """Ridge con intercepto sin penalizar. Devuelve (coeficientes, errores estándar, media base)."""
    n, p = X.shape
    Xc = np.hstack([np.ones((n, 1), dtype=np.float32), X])
    pen = np.eye(p + 1) * lam
    pen[0, 0] = 0
    inv = np.linalg.inv(Xc.T @ Xc + pen)
    beta = inv @ (Xc.T @ y)
    resid = y - Xc @ beta
    xtx = Xc.T @ Xc
    edf = float(np.trace(inv @ xtx))  # grados de libertad efectivos
    sigma2 = float(resid @ resid) / max(n - edf, 1.0)
    se = np.sqrt(np.diag(inv @ xtx @ inv) * sigma2)
    return beta[1:], se[1:], float(beta[0])


def load_events(path):
    text = Path(path).read_text(encoding="utf-8").strip()
    if text.startswith("{") and '"events"' in text[:50]:
        return json.loads(text)["events"]
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def clean(events, pack=None, pack_version=None):
    """Quita duplicados (mismo id), notas fuera de 1–5 y mezcla de packs/versiones."""
    seen, out, dropped = set(), [], Counter()
    for e in events:
        try:
            r = e["recipe"]
            ok = e["id"] not in seen and 1 <= int(e["rating"]) <= 5 and len(r["fragments"]) > 0
        except (KeyError, TypeError, ValueError):
            dropped["malformado"] += 1
            continue
        if not ok:
            dropped["duplicado o nota inválida"] += 1
            continue
        seen.add(e["id"])
        out.append(e)
    if pack:
        out = [e for e in out if e["recipe"]["packId"] == pack]
    if not out:
        return [], dropped, None
    if pack_version is None:  # la versión con más valoraciones
        pack_version = Counter(e["recipe"]["packVersion"] for e in out).most_common(1)[0][0]
    out = [e for e in out if e["recipe"]["packVersion"] == pack_version]
    return out, dropped, pack_version


def analyze(events, pack=None, pack_version=None):
    events, dropped, version = clean(events, pack, pack_version)
    n = len(events)
    result = {"n": n, "pack_version": version, "dropped": dict(dropped), "fragments": [], "transitions": [],
              "values": [], "mean": None, "flagged": []}
    if n < 10:
        return result
    y = np.array([float(e["rating"]) for e in events], dtype=np.float32)
    frag_ids = sorted({f for e in events for f in e["recipe"]["fragments"]})
    values = sorted({e["recipe"]["value"] for e in events})
    pairs = sorted({(a, b) for e in events for a, b in zip(e["recipe"]["fragments"], e["recipe"]["fragments"][1:])})
    fi = {f: i for i, f in enumerate(frag_ids)}
    vi = {v: len(frag_ids) + i for i, v in enumerate(values)}
    pi = {p: len(frag_ids) + len(values) + i for i, p in enumerate(pairs)}
    X = np.zeros((n, len(frag_ids) + len(values) + len(pairs)), dtype=np.float32)
    for r, e in enumerate(events):
        fr = e["recipe"]["fragments"]
        for f in fr:
            X[r, fi[f]] = 1
        X[r, vi[e["recipe"]["value"]]] = 1
        for p in zip(fr, fr[1:]):
            X[r, pi[p]] = 1
    beta, se, base = ridge(X, y)
    counts = X.sum(axis=0)
    mean_by = {}
    for f in frag_ids:
        mean_by[f] = float(y[X[:, fi[f]] == 1].mean())

    def row(name, idx, kind):
        z = float(beta[idx] / max(se[idx], 1e-9))
        return {"id": name, "n": int(counts[idx]), "effect": round(float(beta[idx]), 3), "se": round(float(se[idx]), 3),
                "z": round(z, 2), "mean": round(mean_by[name], 2) if kind == "fragment" else None}

    result["mean"] = round(float(y.mean()), 3)
    result["fragments"] = sorted((row(f, fi[f], "fragment") for f in frag_ids), key=lambda r: r["effect"])
    result["values"] = sorted(
        ({"id": v, "n": int(counts[vi[v]]), "effect": round(float(beta[vi[v]]), 3)} for v in values),
        key=lambda r: r["effect"])
    trans = []
    for p in pairs:
        i = pi[p]
        if counts[i] >= MIN_PAIR_APPEARANCES:
            z = float(beta[i] / max(se[i], 1e-9))
            trans.append({"id": f"{p[0]} → {p[1]}", "n": int(counts[i]), "effect": round(float(beta[i]), 3), "z": round(z, 2)})
    result["transitions"] = sorted(trans, key=lambda r: r["effect"])
    result["flagged"] = [r["id"] for r in result["fragments"]
                         if r["n"] >= MIN_APPEARANCES and r["effect"] < EFFECT_THRESHOLD and r["z"] < Z_THRESHOLD]
    result["flagged_transitions"] = [r["id"] for r in result["transitions"]
                                     if r["effect"] < EFFECT_THRESHOLD and r["z"] < Z_THRESHOLD]
    return result


def report(res, top=10):
    if res["n"] < 10:
        return f"Muy pocas valoraciones ({res['n']}): hacen falta al menos ~250 para empezar a ver señales.\n"
    lines = [f"# Informe de valoraciones — versión {res['pack_version']}", "",
             f"- Valoraciones analizadas: **{res['n']}** (descartadas: {res['dropped'] or 'ninguna'})",
             f"- Nota media: **{res['mean']}**", ""]
    lines += [f"## Fragmentos para REVISAR ({len(res['flagged'])})", ""]
    if res["flagged"]:
        lines += ["| Fragmento | Apariciones | Efecto en la nota | z | Nota media con él |", "|---|---|---|---|---|"]
        for r in res["fragments"]:
            if r["id"] in res["flagged"]:
                lines.append(f"| `{r['id']}` | {r['n']} | {r['effect']:+.2f} | {r['z']} | {r['mean']} |")
    else:
        lines.append("Ninguno supera el umbral todavía (efecto < −0,3 y z < −2 con ≥ 20 apariciones).")
    lines += ["", f"## Los {top} fragmentos con peor efecto (aunque no pasen el umbral)", "",
              "| Fragmento | Apariciones | Efecto | z |", "|---|---|---|---|"]
    lines += [f"| `{r['id']}` | {r['n']} | {r['effect']:+.2f} | {r['z']} |" for r in res["fragments"][:top]]
    lines += ["", "## Transiciones (A → B) con peor efecto", "", "| Transición | Apariciones | Efecto | z |", "|---|---|---|---|"]
    lines += [f"| `{r['id']}` | {r['n']} | {r['effect']:+.2f} | {r['z']} |" for r in res["transitions"][:top]]
    lines += ["", "## Enseñanzas", "", "| Enseñanza | Cuentos | Efecto |", "|---|---|---|"]
    lines += [f"| {r['id']} | {r['n']} | {r['effect']:+.2f} |" for r in res["values"]]
    lines += ["", "> Marcar no es condenar: una persona debe leer el fragmento antes de cambiarlo o bajarle el peso."]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("events")
    ap.add_argument("--pack")
    ap.add_argument("--pack-version")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--json", action="store_true", help="salida JSON en vez de informe")
    args = ap.parse_args()
    res = analyze(load_events(args.events), args.pack, args.pack_version)
    sys.stdout.write(json.dumps(res, ensure_ascii=False, indent=1) if args.json else report(res, args.top))


if __name__ == "__main__":
    main()
