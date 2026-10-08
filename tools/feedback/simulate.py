#!/usr/bin/env python3
"""Simulación: ¿cuántas valoraciones (1–5) hacen falta para encontrar los fragmentos malos?

Se inventa un pack con la estructura del pack gratuito (≈ 100 fragmentos, 6 enseñanzas, 7 etapas),
se «plantan» fragmentos y transiciones malos, se generan valoraciones ruidosas y se prueba el
análisis que se usaría de verdad. Sirve para decidir el diseño ANTES de tener usuarios.

Supuestos (a validar con datos reales):
  * Cada cuento elige un fragmento por etapa al azar entre los de su enseñanza (como el motor).
  * Valoración = 4.2 + efectos de fragmentos (naturales) + efecto de enseñanza + ruido, redondeada y
    recortada a 1–5. El ruido (σ ≈ 0.9) incluye el humor del adulto, el sueño del niño, la voz, etc.
  * Fragmentos malos plantados: efecto −1.0. Transiciones incoherentes plantadas: −1.2.
  * Quien valora no depende del cuento (no hay sesgo de respuesta).

Uso: python3 tools/feedback/simulate.py [--quick]
"""
import argparse
import itertools

import numpy as np

from analyze import ridge as _ridge

STAGES = ["opening", "trouble", "helper", "test", "climax", "resolution", "closing"]
# Cuántas variantes tiene cada etapa. "per_moral": las variantes son específicas de cada enseñanza.
VARIANTS = {"opening": (6, False), "trouble": (4, True), "helper": (3, True), "test": (6, False),
            "climax": (4, True), "resolution": (3, True), "closing": (2, False)}
MORALS = 6
BASE, NOISE_SD = 4.2, 0.9


class World:
    """El pack sintético: índice de cada fragmento y de cada transición posible."""

    def __init__(self):
        self.frag = {}  # (etapa, moral|None, variante) -> índice
        for st in STAGES:
            n, per_moral = VARIANTS[st]
            for m in (range(MORALS) if per_moral else [None]):
                for v in range(n):
                    self.frag[(st, m, v)] = len(self.frag)
        self.n_frag = len(self.frag)
        self.pairs = {}
        for m in range(MORALS):
            for a, b in zip(STAGES, STAGES[1:]):
                for va, vb in itertools.product(range(VARIANTS[a][0]), range(VARIANTS[b][0])):
                    self.pairs[(self._f(a, m, va), self._f(b, m, vb))] = len(self.pairs)
        self.n_pair = len(self.pairs)

    def _f(self, st, m, v):
        return self.frag[(st, m if VARIANTS[st][1] else None, v)]

    def stories(self, n, rng):
        """n cuentos: enseñanza (n,), fragmentos (n,7), transiciones (n,6)."""
        m = rng.integers(0, MORALS, n)
        frags = np.zeros((n, len(STAGES)), dtype=int)
        for j, st in enumerate(STAGES):
            k, per_moral = VARIANTS[st]
            v = rng.integers(0, k, n)
            for i in range(n):
                frags[i, j] = self._f(st, m[i], v[i])
        pairs = np.array([[self.pairs[(frags[i, j], frags[i, j + 1])] for j in range(len(STAGES) - 1)] for i in range(n)])
        return m, frags, pairs


def truth(world, rng):
    """Efectos verdaderos: naturales + malos plantados."""
    eff = rng.normal(0, 0.12, world.n_frag)
    mor = rng.normal(0, 0.2, MORALS)
    # Fragmentos malos: uno por etapa en 6 etapas distintas con variantes (no en «closing»).
    bad = []
    for st in ["trouble", "helper", "climax", "resolution", "opening", "test"]:
        n, per = VARIANTS[st]
        m = int(rng.integers(0, MORALS)) if per else None
        bad.append(world.frag[(st, m, int(rng.integers(0, n)))])
    eff[bad] -= 1.0
    # Transiciones incoherentes: 3 pares al azar entre etapas contiguas.
    bad_pairs = [int(p) for p in rng.choice(world.n_pair, 3, replace=False)]
    pair_eff = np.zeros(world.n_pair)
    pair_eff[bad_pairs] = -1.2
    return eff, mor, pair_eff, bad, bad_pairs


def ratings(world, st, eff, mor, pair_eff, rng):
    m, frags, pairs = st
    latent = BASE + mor[m] + eff[frags].sum(axis=1) + pair_eff[pairs].sum(axis=1)
    latent = latent - eff.mean() * len(STAGES)  # centra los efectos naturales: el promedio ≈ BASE
    return np.clip(np.rint(latent + rng.normal(0, NOISE_SD, len(m))), 1, 5)


def design(world, st, with_pairs):
    m, frags, pairs = st
    n = len(m)
    cols = world.n_frag + MORALS + (world.n_pair if with_pairs else 0)
    X = np.zeros((n, cols), dtype=np.float32)
    rows = np.arange(n)[:, None]
    X[rows, frags] = 1
    X[np.arange(n), world.n_frag + m] = 1
    if with_pairs:
        X[rows, world.n_frag + MORALS + pairs] = 1
    return X


def trial(world, n, seed, lam=9.0):
    rng = np.random.default_rng(seed)
    eff, mor, pair_eff, bad, bad_pairs = truth(world, rng)
    st = world.stories(n, rng)
    y = ratings(world, st, eff, mor, pair_eff, rng)
    out = {}

    # 1) Ingenuo: promedio de las valoraciones de los cuentos que contienen el fragmento.
    m, frags, _ = st
    naive = np.full(world.n_frag, np.inf)
    for f in range(world.n_frag):
        sel = (frags == f).any(axis=1)
        if sel.sum() >= 5:
            naive[f] = y[sel].mean()
    out["naive_recall"] = len(set(np.argsort(naive)[:6]) & set(bad)) / 6

    # 2) Regresión ridge con fragmentos + enseñanza + transiciones.
    X = design(world, st, with_pairs=True)
    beta, se, _ = _ridge(X, y, lam)
    bf, sf = beta[:world.n_frag], se[:world.n_frag]
    out["ridge_recall"] = len(set(np.argsort(bf)[:6]) & set(bad)) / 6
    flagged = np.where((bf < -0.3) & (bf / np.maximum(sf, 1e-9) < -2))[0]
    out["flag_hits"] = len(set(flagged) & set(bad))
    out["flag_false"] = len(set(flagged) - set(bad))
    bp = beta[world.n_frag + MORALS:]
    out["pair_recall"] = len(set(np.argsort(bp)[:3]) & set(bad_pairs)) / 3
    out["exposure"] = float(np.bincount(frags.ravel(), minlength=world.n_frag).mean())
    out["mean_rating"] = float(y.mean())
    out["pct45"] = float((y >= 4).mean())
    return out


def main():
    global NOISE_SD
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--noise", type=float, default=0.9, help="desviación típica del ruido (σ)")
    args = ap.parse_args()
    NOISE_SD = args.noise
    world = World()
    print(f"Pack sintético: {world.n_frag} fragmentos, {world.n_pair} transiciones posibles, {MORALS} enseñanzas")
    print(f"Verdad plantada: 6 fragmentos malos (−1.0), 3 transiciones incoherentes (−1.2), ruido σ={NOISE_SD}\n")
    grid = [(250, 20), (500, 20), (1000, 20), (2000, 16), (5000, 8)] if args.quick else \
           [(250, 30), (500, 30), (1000, 30), (2000, 24), (5000, 16), (10000, 8), (20000, 5)]
    print(f"{'valoraciones':>12} {'veces/frag':>10} {'ingenuo':>8} {'ridge':>7} {'marcados OK':>12} {'falsos':>7} {'transiciones':>13}")
    print(f"{'':>12} {'':>10} {'recall@6':>8} {'recall@6':>7} {'(de 6)':>12} {'(media)':>7} {'recall@3':>13}")
    rows = []
    for n, trials in grid:
        r = [trial(world, n, 1000 * n + t) for t in range(trials)]
        mean = lambda k: float(np.mean([x[k] for x in r]))
        rows.append((n, mean("exposure"), mean("naive_recall"), mean("ridge_recall"), mean("flag_hits"), mean("flag_false"), mean("pair_recall")))
        print(f"{n:>12} {rows[-1][1]:>10.0f} {rows[-1][2]:>8.0%} {rows[-1][3]:>7.0%} {rows[-1][4]:>12.1f} {rows[-1][5]:>7.1f} {rows[-1][6]:>13.0%}")
    print(f"\nValoración media simulada: {mean('mean_rating'):.2f} · % de 4 o 5: {mean('pct45'):.0%}")

    print("\nTiempo hasta tener N valoraciones, según cuántas familias activas y qué fracción valora:")
    print(f"{'familias/sem':>13} {'responden':>10} {'cuentos/fam':>12} {'valoraciones/sem':>17} {'sem. hasta 2000':>16}")
    for fam, resp, per in [(200, 0.3, 3), (1000, 0.3, 3), (1000, 0.15, 3), (5000, 0.3, 3)]:
        w = fam * resp * per
        print(f"{fam:>13} {resp:>10.0%} {per:>12} {w:>17.0f} {2000 / w:>16.1f}")


if __name__ == "__main__":
    main()
