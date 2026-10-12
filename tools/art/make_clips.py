#!/usr/bin/env python3
"""Genera la biblioteca de animaciones del rig humanoide → art/clips/humanoid.json

Cada clip es DATOS (pistas de claves por hueso). Sirve a cualquier personaje humanoide de
cualquier pack: los ángulos se suman a la pose de reposo de cada personaje.
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent.parent / "art" / "clips" / "humanoid.json"


def r(v):
    return round(v, 3)


def sine(dur, amp, phase=0.0, n=8):
    """Una oscilación completa en `dur`; el último valor iguala al primero (bucle sin costuras)."""
    return [[r(dur * i / n), r(amp * math.sin(2 * math.pi * (i / n + phase)))] for i in range(n + 1)]


def keys(*pairs):
    return [[r(t), r(v)] for t, v in pairs]


def blink(dur, at=0.86):
    return keys((0, 1), (dur * at, 1), (dur * (at + 0.03), 0.12), (dur * (at + 0.07), 1), (dur, 1))


CLIPS = {
    "idle": dict(dur=3.0, loop=True, tracks={
        "torso": sine(3, 1.2), "head": sine(3, 2.5, 0.13),
        "armL": sine(3, 3.0, 0.07), "armR": sine(3, 3.0, 0.57),
        "root.dy": keys((0, 0), (0.75, -2), (1.5, 0), (2.25, -2), (3, 0)),
        "eyes.sy": blink(3.0)}),
    "walk": dict(dur=0.8, loop=True, tracks={
        "legL": sine(0.8, 16), "legR": sine(0.8, 16),
        "legL.dy": keys((0, 0), (0.2, -9), (0.4, 0), (0.8, 0)),
        "legR.dy": keys((0, 0), (0.4, 0), (0.6, -9), (0.8, 0)),
        "armL": sine(0.8, -22), "armR": sine(0.8, -22),
        "torso": sine(0.8, 2.5), "head": sine(0.8, -2),
        "root.dy": keys((0, 0), (0.2, -3), (0.4, 0), (0.6, -3), (0.8, 0))}),
    "run": dict(dur=0.5, loop=True, tracks={
        "legL": sine(0.5, 26), "legR": sine(0.5, 26),
        "legL.dy": keys((0, 0), (0.125, -16), (0.25, 0), (0.5, 0)),
        "legR.dy": keys((0, 0), (0.25, 0), (0.375, -16), (0.5, 0)),
        "armL": sine(0.5, -48), "armR": sine(0.5, -48),
        "torso": sine(0.5, 4, 0.0), "head": sine(0.5, -3),
        "root.dy": keys((0, -4), (0.125, -10), (0.25, -4), (0.375, -10), (0.5, -4))}),
    "wave": dict(dur=2.0, loop=True, tracks={
        "armR": keys((0, 0), (0.3, -150), (0.6, -128), (0.9, -152), (1.2, -128), (1.5, -150), (2, 0)),
        "head": keys((0, 0), (0.3, -5), (1.5, -5), (2, 0)),
        "torso": keys((0, 0), (0.3, -2), (1.5, -2), (2, 0)),
        "root.dy": keys((0, 0), (0.5, -1), (1, 0), (1.5, -1), (2, 0)),
        "eyes.sy": blink(2.0, 0.8)}),
    "cheer": dict(dur=1.2, loop=True, tracks={
        "armL": keys((0, 0), (0.25, 165), (0.6, 150), (0.9, 168), (1.2, 0)),
        "armR": keys((0, 0), (0.25, -165), (0.6, -150), (0.9, -168), (1.2, 0)),
        "root.dy": keys((0, 0), (0.15, 3), (0.4, -14), (0.6, 0), (0.75, 3), (1.0, -14), (1.2, 0)),
        "legL": keys((0, 0), (0.4, -10), (0.6, 0), (1.0, -10), (1.2, 0)),
        "legR": keys((0, 0), (0.4, 10), (0.6, 0), (1.0, 10), (1.2, 0)),
        "head": sine(1.2, 4)}),
    "jump": dict(dur=1.0, loop=False, tracks={
        "root.dy": keys((0, 0), (0.15, 7), (0.45, -26), (0.7, -26), (0.88, 5), (1, 0)),
        "legL": keys((0, 0), (0.15, 8), (0.45, -18), (0.7, -18), (0.88, 8), (1, 0)),
        "legR": keys((0, 0), (0.15, -8), (0.45, 18), (0.7, 18), (0.88, -8), (1, 0)),
        "armL": keys((0, 0), (0.15, -20), (0.45, 118), (0.7, 118), (0.88, -10), (1, 0)),
        "armR": keys((0, 0), (0.15, 20), (0.45, -118), (0.7, -118), (0.88, 10), (1, 0)),
        "torso": keys((0, 0), (0.15, 4), (0.45, -3), (1, 0))}),
    "surprised": dict(dur=1.4, loop=True, tracks={
        "armL": keys((0, 0), (0.12, 105), (1.2, 105), (1.4, 0)),
        "armR": keys((0, 0), (0.12, -105), (1.2, -105), (1.4, 0)),
        "head": keys((0, 0), (0.12, -7), (1.2, -7), (1.4, 0)),
        "root.dy": keys((0, 0), (0.08, -9), (0.25, 0), (1.4, 0)),
        "torso": keys((0, 0), (0.12, -3), (1.2, -3), (1.4, 0)),
        "eyes.sy": keys((0, 1), (0.1, 1.25), (1.2, 1.25), (1.4, 1))}),
    "scared": dict(dur=0.5, loop=True, tracks={
        "armL": keys((0, 128), (0.125, 134), (0.25, 128), (0.375, 134), (0.5, 128)),
        "armR": keys((0, -128), (0.125, -134), (0.25, -128), (0.375, -134), (0.5, -128)),
        "torso": keys((0, -1.5), (0.125, 1.5), (0.25, -1.5), (0.375, 1.5), (0.5, -1.5)),
        "head": keys((0, -6), (0.125, -3), (0.25, -6), (0.375, -3), (0.5, -6)),
        "root.dy": keys((0, -2), (0.125, 0), (0.25, -2), (0.375, 0), (0.5, -2)),
        "legL": keys((0, 6), (0.5, 6)), "legR": keys((0, -6), (0.5, -6)),
        "eyes.sy": keys((0, 1.25), (0.5, 1.25))}),
    "talk": dict(dur=1.6, loop=True, tracks={
        "head": keys((0, 0), (0.2, 3), (0.45, -1), (0.7, 3.5), (1.0, 0), (1.3, 2.5), (1.6, 0)),
        "torso": sine(1.6, 1.0),
        "armL": sine(1.6, 5, 0.1), "armR": sine(1.6, 5, 0.6),
        "root.dy": keys((0, 0), (0.4, -1.5), (0.8, 0), (1.2, -1.5), (1.6, 0)),
        "eyes.sy": blink(1.6, 0.7)}),
    # En vista frontal la reverencia es «hacia la cámara»: el torso se acorta y la cabeza baja.
    "bow": dict(dur=2.4, loop=False, tracks={
        "torso.sy": keys((0, 1), (0.7, 0.8), (1.5, 0.8), (2.4, 1)),
        "torso": keys((0, 0), (0.7, 4), (1.5, 4), (2.4, 0)),
        "head": keys((0, 0), (0.7, 10), (1.5, 10), (2.4, 0)),
        "head.dy": keys((0, 0), (0.7, 10), (1.5, 10), (2.4, 0)),
        "armL": keys((0, 0), (0.7, 6), (1.5, 6), (2.4, 0)),
        "armR": keys((0, 0), (0.7, -6), (1.5, -6), (2.4, 0)),
        "eyes.sy": keys((0, 1), (0.6, 0.35), (1.6, 0.35), (2.4, 1))}),
    # --- gestos nuevos (más actuación que solo «reposo / susto / alegría»)
    "point": dict(dur=1.8, loop=True, tracks={
        "armR": keys((0, 0), (0.25, -96), (0.55, -90), (0.85, -97), (1.2, -90), (1.5, -96), (1.8, 0)),
        "head": keys((0, 0), (0.25, -7), (1.5, -7), (1.8, 0)),
        "torso": keys((0, 0), (0.25, -3), (1.5, -3), (1.8, 0)),
        "root.dy": keys((0, 0), (0.45, -2), (0.9, 0), (1.35, -2), (1.8, 0)),
        "eyes.sy": blink(1.8, 0.75)}),
    "sad": dict(dur=3.2, loop=True, tracks={
        "head": keys((0, 8), (1.6, 10), (3.2, 8)),
        "head.dy": keys((0, 7), (1.6, 9), (3.2, 7)),
        "torso": keys((0, 2), (1.6, 3), (3.2, 2)),
        "torso.sy": keys((0, 0.96), (1.6, 0.95), (3.2, 0.96)),
        "armL": keys((0, -5), (1.6, -3), (3.2, -5)), "armR": keys((0, 5), (1.6, 3), (3.2, 5)),
        "eyes.sy": keys((0, 0.55), (2.8, 0.55), (2.9, 0.12), (3.0, 0.55), (3.2, 0.55))}),
    "think": dict(dur=3.0, loop=True, tracks={
        "armR": keys((0, 0), (0.4, -142), (2.6, -142), (3.0, 0)),
        "armL": keys((0, 0), (0.4, -22), (2.6, -22), (3.0, 0)),
        "head": keys((0, 0), (0.4, 7), (1.5, 5), (2.6, 7), (3.0, 0)),
        "torso": sine(3.0, 1.0),
        "eyes.sy": blink(3.0, 0.6)}),
    "sneak": dict(dur=1.4, loop=True, tracks={
        "root.dy": keys((0, 12), (0.35, 9), (0.7, 12), (1.05, 9), (1.4, 12)),
        "torso.sy": keys((0, 0.9), (1.4, 0.9)),
        "torso": keys((0, 6), (0.7, 3), (1.4, 6)),
        "head": keys((0, 8), (0.7, 5), (1.4, 8)),
        "legL": sine(1.4, 14), "legR": sine(1.4, 14),
        "legL.dy": keys((0, 0), (0.35, -5), (0.7, 0), (1.4, 0)),
        "legR.dy": keys((0, 0), (0.7, 0), (1.05, -5), (1.4, 0)),
        "armL": sine(1.4, -10), "armR": sine(1.4, -10),
        "eyes.sy": keys((0, 0.6), (1.4, 0.6))}),
    "laugh": dict(dur=0.8, loop=True, tracks={
        "root.dy": keys((0, 0), (0.1, -7), (0.2, 0), (0.3, -7), (0.4, 0), (0.5, -7), (0.6, 0), (0.7, -5), (0.8, 0)),
        "head": keys((0, -6), (0.4, -9), (0.8, -6)),
        "torso": sine(0.8, 2.5),
        "armL": keys((0, 14), (0.4, 18), (0.8, 14)), "armR": keys((0, -14), (0.4, -18), (0.8, -14)),
        "eyes.sy": keys((0, 0.3), (0.8, 0.3))}),
    "sleep": dict(dur=4.0, loop=True, tracks={
        "head": keys((0, 16), (2, 19), (4, 16)),
        "head.dy": keys((0, 5), (2, 7), (4, 5)),
        "torso": sine(4.0, 1.2),
        "root.dy": keys((0, 0), (2, 2), (4, 0)),
        "eyes.sy": keys((0, 0.08), (4, 0.08))}),
    "offer": dict(dur=2.2, loop=True, tracks={
        "armR": keys((0, 0), (0.4, -72), (1.8, -72), (2.2, 0)),
        "head": keys((0, 0), (0.5, 4), (1.1, -1), (1.7, 4), (2.2, 0)),
        "torso": keys((0, 0), (0.4, -3), (1.8, -3), (2.2, 0)),
        "eyes.sy": blink(2.2, 0.7)}),
    "no": dict(dur=1.0, loop=True, tracks={
        "head": keys((0, 0), (0.15, 11), (0.4, -11), (0.65, 11), (0.85, -8), (1.0, 0)),
        "torso": keys((0, 0), (0.25, 2), (0.6, -2), (1.0, 0)),
        "armL": keys((0, 0), (0.2, 18), (0.8, 18), (1.0, 0)), "armR": keys((0, 0), (0.2, -18), (0.8, -18), (1.0, 0)),
        "eyes.sy": keys((0, 0.7), (1.0, 0.7))}),
    "clap": dict(dur=0.6, loop=True, tracks={
        "armL": keys((0, 62), (0.15, 48), (0.3, 62), (0.45, 48), (0.6, 62)),
        "armR": keys((0, -62), (0.15, -48), (0.3, -62), (0.45, -48), (0.6, -62)),
        "root.dy": keys((0, 0), (0.15, -4), (0.3, 0), (0.45, -4), (0.6, 0)),
        "head": sine(0.6, 3)}),
    # --- gestos de la ronda 8 (lo que el texto cuenta, ahora se ve)
    # Temblor / frío / vergüenza: brazos cruzados sobre el pecho, cabeza gacha, tiembla rápido.
    "shiver": dict(dur=0.4, loop=True, tracks={
        "armL": keys((0, -70), (0.1, -66), (0.2, -70), (0.3, -66), (0.4, -70)),
        "armR": keys((0, 70), (0.1, 66), (0.2, 70), (0.3, 66), (0.4, 70)),
        "torso": keys((0, -1.6), (0.1, 1.6), (0.2, -1.6), (0.3, 1.6), (0.4, -1.6)),
        "head": keys((0, 7), (0.2, 9), (0.4, 7)),
        "head.dy": keys((0, 5), (0.4, 5)),
        "root.dy": keys((0, 1), (0.1, 0), (0.2, 1), (0.3, 0), (0.4, 1)),
        "legL": keys((0, -4), (0.4, -4)), "legR": keys((0, 4), (0.4, 4)),
        "eyes.sy": keys((0, 0.45), (0.4, 0.45))}),
    # Abrazo: los dos brazos abiertos hacia delante (dos personajes juntos se ven abrazados).
    "hug": dict(dur=2.0, loop=True, tracks={
        "armL": keys((0, 0), (0.4, 78), (1.6, 78), (2.0, 0)),
        "armR": keys((0, 0), (0.4, -78), (1.6, -78), (2.0, 0)),
        "head": keys((0, 0), (0.4, 8), (1.6, 8), (2.0, 0)),
        "torso": keys((0, 0), (0.4, 3), (1.6, 3), (2.0, 0)),
        "eyes.sy": keys((0, 1), (0.4, 0.3), (1.6, 0.3), (2.0, 1))}),
    # Sentado (de frente): piernas cortas y el cuerpo más abajo.
    "sit": dict(dur=3.0, loop=True, tracks={
        "root.dy": keys((0, 33), (1.5, 34), (3.0, 33)),
        "legL.sy": keys((0, 0.45), (3.0, 0.45)), "legR.sy": keys((0, 0.45), (3.0, 0.45)),
        "legL": keys((0, 10), (3.0, 10)), "legR": keys((0, -10), (3.0, -10)),
        "torso": sine(3.0, 1.0), "head": sine(3.0, 2.0, 0.1),
        "armL": keys((0, -8), (3.0, -8)), "armR": keys((0, 8), (3.0, 8)),
        "eyes.sy": blink(3.0, 0.6)}),
    # Sentado y triste (Tomás junto al gancho vacío, un niño en el suelo).
    "sit_sad": dict(dur=3.2, loop=True, tracks={
        "root.dy": keys((0, 33), (1.6, 34), (3.2, 33)),
        "legL.sy": keys((0, 0.45), (3.2, 0.45)), "legR.sy": keys((0, 0.45), (3.2, 0.45)),
        "legL": keys((0, 10), (3.2, 10)), "legR": keys((0, -10), (3.2, -10)),
        "head": keys((0, 9), (1.6, 11), (3.2, 9)), "head.dy": keys((0, 6), (3.2, 6)),
        "torso": keys((0, 3), (1.6, 4), (3.2, 3)),
        "armL": keys((0, -14), (3.2, -14)), "armR": keys((0, 14), (3.2, 14)),
        "eyes.sy": keys((0, 0.5), (2.9, 0.5), (3.0, 0.12), (3.1, 0.5), (3.2, 0.5))}),
    # Trepar: los brazos suben alternados y las piernas empujan.
    "climb": dict(dur=1.2, loop=True, tracks={
        "armL": keys((0, 150), (0.3, 118), (0.6, 150), (0.9, 170), (1.2, 150)),
        "armR": keys((0, -118), (0.3, -150), (0.6, -170), (0.9, -150), (1.2, -118)),
        "legL": sine(1.2, 22), "legR": sine(1.2, 22, 0.5),
        "legL.dy": keys((0, 0), (0.3, -8), (0.6, 0), (1.2, 0)),
        "legR.dy": keys((0, 0), (0.6, 0), (0.9, -8), (1.2, 0)),
        "torso": sine(1.2, 3), "head": sine(1.2, -3),
        "root.dy": keys((0, 0), (0.6, -4), (1.2, 0)),
        "eyes.sy": keys((0, 0.8), (1.2, 0.8))}),
    # Agachado, escondiéndose: encogido y quieto.
    "hide": dict(dur=2.4, loop=True, tracks={
        "root.dy": keys((0, 22), (1.2, 23), (2.4, 22)),
        "legL.sy": keys((0, 0.6), (2.4, 0.6)), "legR.sy": keys((0, 0.6), (2.4, 0.6)),
        "torso.sy": keys((0, 0.9), (2.4, 0.9)),
        "head": keys((0, 6), (2.4, 6)),
        "armL": keys((0, -40), (2.4, -40)), "armR": keys((0, 40), (2.4, 40)),
        "eyes.sy": keys((0, 1.2), (2.4, 1.2))}),
}


# ---------------------------------------------------------------- brazos con codo: la mano va a un punto
# El brazo mide 26 (hombro→codo) + 22 (codo→mano). `hand(lado, (x, y))` calcula cuánto girar hombro y codo para
# que la mano llegue al punto (coordenadas del dibujo; el hombro derecho está en (36, -140)). Es cinemática inversa
# de dos huesos, hecha al generar los clips: en el clip solo quedan ángulos.
L1, L2 = 26.0, 22.0
REST_ARM = {-1: 9.0, 1: -9.0}   # el reposo de armL / armR (se suma a la pista)


def _norm(a):
    return (a + 180) % 360 - 180


def hand(side, target):
    """Ángulos (pista del hombro, pista del codo) para que la mano de `side` (-1 izq., +1 der.) llegue a `target`."""
    if target is None:
        return 0.0, 0.0
    sx, sy = 36 * side, -140.0
    tx, ty = target
    dx, dy = tx - sx, ty - sy
    d = math.hypot(dx, dy)
    d = min(max(d, abs(L1 - L2) + 0.5), L1 + L2 - 0.5)
    base = math.atan2(dy, dx)
    alpha = math.acos((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))
    best = None
    for sign in (1, -1):
        psi1 = base + sign * alpha
        ex, ey = sx + L1 * math.cos(psi1), sy + L1 * math.sin(psi1)
        score = ey + 0.2 * side * ex          # el codo queda lo más abajo posible (y algo hacia fuera)
        if best is None or score > best[0]:
            best = (score, psi1, ex, ey)
    _, psi1, ex, ey = best
    hx, hy = sx + dx * d / math.hypot(dx, dy), sy + dy * d / math.hypot(dx, dy)
    psi2 = math.atan2(hy - ey, hx - ex)
    a1 = _norm(math.degrees(psi1) - 90)       # dirección «abajo» = 0°, en sentido horario
    f = _norm(math.degrees(psi2 - psi1))
    return a1 - REST_ARM[side], f


def arms(dur, frames):
    """Pistas armL/foreArmL/armR/foreArmR a partir de `[(t, objetivoIzq, objetivoDer), ...]` (None = en reposo)."""
    t = {"armL": [], "foreArmL": [], "armR": [], "foreArmR": []}
    prev = {}
    for time, tl, tr in frames:
        for side, name, target in ((-1, "L", tl), (1, "R", tr)):
            a1, f = hand(side, target)
            # sin saltos de 360° entre claves
            if name in prev:
                pa, pf = prev[name]
                a1 = pa + _norm(a1 - pa)
                f = pf + _norm(f - pf)
            prev[name] = (a1, f)
            t["arm" + name].append([r(time), r(a1)])
            t["foreArm" + name].append([r(time), r(f)])
    return t


def mirror(p):
    return (-p[0], p[1])


# ---------------------------------------------------------------- caras (cejas, boca, mirada) y gestos nuevos
# Huesos de la cara: `browL`/`browR` (giran: negativo = el extremo de dentro sube), `mouth` (la sonrisa; sy<0 la
# vuelve un gesto triste), `jaw` (boca abierta: una lente casi plana que se agranda con sy) y `eyes.dx/dy` (mirada).
WORRY, ANGRY = 15, 11


def hold(dur, v):
    return keys((0, v), (dur, v))


def cycle(dur, vals):
    """Valores repartidos a partes iguales en `dur` (el último vuelve al primero)."""
    n = len(vals)
    return keys(*[(dur * i / n, v) for i, v in enumerate(vals)], (dur, vals[0]))


def brows(dur, rot=0.0, dy=0.0):
    t = {}
    if rot:
        t["browL"] = hold(dur, -rot)
        t["browR"] = hold(dur, rot)
    if dy:
        t["browL.dy"] = hold(dur, dy)
        t["browR.dy"] = hold(dur, dy)
    return t


def open_mouth(dur, sy, sx=1.0, wobble=0.0, n=4):
    """Boca abierta (con la línea de la sonrisa escondida); `wobble` la hace temblar o masticar."""
    vals = [sy + (wobble if i % 2 else -wobble) for i in range(n)] if wobble else [sy]
    return {"jaw.sy": cycle(dur, vals) if wobble else hold(dur, sy), "jaw.sx": hold(dur, sx), "mouth.sy": hold(dur, 0.01)}


FACES = {
    "idle": lambda d: {"eyes.dx": keys((0, 0), (0.9, -2.5), (1.3, -2.5), (1.6, 0), (2.2, 2.5), (2.6, 2.5), (3, 0))},
    "wave": lambda d: {**brows(d, dy=-2), "mouth.sx": hold(d, 1.2)},
    "cheer": lambda d: {**brows(d, dy=-4), **open_mouth(d, 4, 1.15, 1.0)},
    "jump": lambda d: {**brows(d, dy=-5), **open_mouth(d, 5, 0.9)},
    "surprised": lambda d: {**brows(d, dy=-7), **open_mouth(d, 6, 0.65)},
    "scared": lambda d: {**brows(d, WORRY, -3), **open_mouth(d, 4.5, 0.9, 1.2), "eyes.dx": cycle(d, [-1.5, 1.5, -1.5, 1.5])},
    "talk": lambda d: {**brows(d, dy=-1), "mouth.sy": cycle(d, [1, 0.35, 0.9, 0.3, 1, 0.45, 0.8, 0.3]),
                       "jaw.sy": cycle(d, [1, 5, 1.5, 6, 1, 4.5, 2, 5.5]), "jaw.sx": hold(d, 0.95)},
    "bow": lambda d: {"mouth.sx": hold(d, 1.15)},
    "point": lambda d: {**brows(d, dy=-2), "mouth.sx": hold(d, 1.15)},
    "sad": lambda d: {**brows(d, WORRY, 1), "mouth.sy": hold(d, -1.0), "mouth.dy": hold(d, 4), "mouth.sx": hold(d, 0.85)},
    "think": lambda d: {"browL": hold(d, 6), "browR.dy": hold(d, -6), "mouth.sx": hold(d, 0.6), "mouth.dx": hold(d, 5),
                        "eyes.dx": keys((0, 0), (0.5, -5), (d * 0.8, -5), (d, 0)), "eyes.dy": keys((0, 0), (0.5, -4), (d * 0.8, -4), (d, 0))},
    "sneak": lambda d: {**brows(d, -ANGRY), "mouth.sx": hold(d, 0.6), "eyes.dx": cycle(d, [-5, 5, -5, 5])},
    "laugh": lambda d: {**brows(d, dy=-3), **open_mouth(d, 5.5, 1.3, 0.8, 8)},
    "sleep": lambda d: {"mouth.sx": hold(d, 0.55), "jaw.sy": cycle(d, [1.2, 2.4, 1.2, 2.0]), "jaw.sx": hold(d, 0.5)},
    "offer": lambda d: {**brows(d, dy=-2), "mouth.sx": hold(d, 1.15)},
    "no": lambda d: {**brows(d, -ANGRY), "mouth.sy": hold(d, -0.7), "mouth.dy": hold(d, 2)},
    "clap": lambda d: {**brows(d, dy=-3), **open_mouth(d, 3.5, 1.1)},
    "shiver": lambda d: {**brows(d, WORRY - 4), **open_mouth(d, 2.2, 0.8, 1.2, 8)},
    "hug": lambda d: {**brows(d, dy=-2), "mouth.sx": hold(d, 1.3)},
    "sit_sad": lambda d: {**brows(d, WORRY, 1), "mouth.sy": hold(d, -1.0), "mouth.dy": hold(d, 4), "mouth.sx": hold(d, 0.85)},
    "climb": lambda d: {**brows(d, -ANGRY + 3), **open_mouth(d, 2.5, 0.8, 0.5)},
    "hide": lambda d: {**brows(d, WORRY - 3, -1), "eyes.dx": keys((0, -5), (0.6 * d, -5), (0.7 * d, 5), (d, 5))},
    "run": lambda d: {**brows(d, -6), **open_mouth(d, 2.2, 0.9, 0.5)},
}

NEW_CLIPS = {
    # comer: la mano a la boca y a masticar
    "eat": dict(dur=1.8, loop=True, tracks={
        "armR": keys((0, 0), (0.3, -140), (0.6, -128), (0.9, -140), (1.2, -128), (1.5, -140), (1.8, 0)),
        "armL": sine(1.8, 3, 0.2), "torso": sine(1.8, 1.2), "head": keys((0, 0), (0.3, 3), (1.5, 3), (1.8, 0)),
        "root.dy": keys((0, 0), (0.45, -1), (0.9, 0), (1.35, -1), (1.8, 0)),
        "eyes.sy": keys((0, 1), (0.3, 0.55), (1.5, 0.55), (1.8, 1)),
        "mouth.sx": hold(1.8, 1.15), "mouth.sy": hold(1.8, 0.01),
        "jaw.sy": keys((0, 1), (0.3, 1), (0.45, 3), (0.6, 1), (0.75, 3), (0.9, 1), (1.05, 3), (1.2, 1), (1.35, 3), (1.5, 1), (1.8, 1)),
        "browL.dy": hold(1.8, -1), "browR.dy": hold(1.8, -1)}),
    # soplar la sopa: se inclina, los labios en «o» pequeña
    "blow": dict(dur=2.2, loop=True, tracks={
        "armL": keys((0, 0), (0.4, 62), (1.8, 62), (2.2, 0)), "armR": keys((0, 0), (0.4, -62), (1.8, -62), (2.2, 0)),
        "torso": keys((0, 0), (0.4, 4), (1.8, 4), (2.2, 0)), "head": keys((0, 0), (0.4, 7), (1.8, 7), (2.2, 0)),
        "head.dy": keys((0, 0), (0.4, 3), (1.8, 3), (2.2, 0)),
        "eyes.sy": keys((0, 1), (0.4, 0.55), (1.8, 0.55), (2.2, 1)),
        "jaw.sx": hold(2.2, 0.5), "mouth.sy": hold(2.2, 0.01),
        "jaw.sy": keys((0, 1), (0.5, 4), (0.8, 2), (1.1, 4), (1.4, 2), (1.7, 4), (2.2, 1)),
        "browL.dy": hold(2.2, -1), "browR.dy": hold(2.2, -1)}),
    # orgulloso: pecho fuera, barbilla arriba, brazos separados
    "proud": dict(dur=2.4, loop=True, tracks={
        "armL": keys((0, 0), (0.4, 38), (2.0, 38), (2.4, 0)), "armR": keys((0, 0), (0.4, -38), (2.0, -38), (2.4, 0)),
        "torso.sy": keys((0, 1), (0.4, 1.04), (2.0, 1.04), (2.4, 1)), "torso": sine(2.4, 0.8),
        "head": keys((0, 0), (0.4, -5), (2.0, -5), (2.4, 0)), "root.dy": keys((0, 0), (1.2, -2), (2.4, 0)),
        "eyes.sy": keys((0, 1), (0.4, 0.75), (2.0, 0.75), (2.4, 1)), "mouth.sx": hold(2.4, 1.25),
        "browL.dy": hold(2.4, -2), "browR.dy": hold(2.4, -2), "eyes.dx": keys((0, 0), (1.2, 3), (2.4, 0))}),
    # bostezo: la mano a la boca, ojos cerrados, cabeza atrás
    "yawn": dict(dur=3.2, loop=True, tracks={
        "armR": keys((0, 0), (0.6, -142), (2.4, -142), (3.2, 0)), "armL": sine(3.2, 2, 0.3),
        "head": keys((0, 0), (0.6, -6), (2.2, -6), (3.2, 0)), "torso.sy": keys((0, 1), (0.8, 1.04), (2.0, 1.04), (3.2, 1)),
        "eyes.sy": keys((0, 1), (0.6, 0.12), (2.6, 0.12), (3.2, 0.6)),
        "jaw.sy": keys((0, 1), (0.6, 1), (1.0, 7), (2.2, 7), (2.7, 1), (3.2, 1)),
        "jaw.sx": hold(3.2, 1.3), "mouth.sy": hold(3.2, 0.01),
        "browL.dy": keys((0, 0), (1.0, 2), (2.2, 2), (3.2, 0)), "browR.dy": keys((0, 0), (1.0, 2), (2.2, 2), (3.2, 0))}),
    # asombro: mira hacia arriba con la boca en «o»
    "wonder": dict(dur=2.4, loop=True, tracks={
        "head": keys((0, 0), (0.4, -8), (2.0, -8), (2.4, 0)), "torso": keys((0, 0), (0.4, -2), (2.0, -2), (2.4, 0)),
        "armL": keys((0, 0), (0.4, 24), (2.0, 24), (2.4, 0)), "armR": keys((0, 0), (0.4, -24), (2.0, -24), (2.4, 0)),
        "root.dy": keys((0, 0), (1.2, -2), (2.4, 0)),
        "eyes.sy": hold(2.4, 1.25), "eyes.dy": keys((0, 0), (0.4, -4), (2.0, -4), (2.4, 0)),
        "jaw.sy": hold(2.4, 4), "jaw.sx": hold(2.4, 0.8), "mouth.sy": hold(2.4, 0.01),
        "browL.dy": hold(2.4, -6), "browR.dy": hold(2.4, -6)}),
}
CLIPS.update(NEW_CLIPS)

N = None
ARM_POSES = {
    "wave": lambda d: arms(d, [(0, N, N), (0.3, N, (56, -184)), (0.6, N, (68, -174)), (0.9, N, (56, -184)),
                               (1.2, N, (68, -174)), (1.5, N, (56, -184)), (d, N, N)]),
    "surprised": lambda d: arms(d, [(0, N, N), (0.12, (-30, -170), (30, -170)), (1.2, (-30, -170), (30, -170)), (d, N, N)]),
    "scared": lambda d: arms(d, [(0, (-26, -164), (26, -164)), (0.125, (-29, -168), (29, -168)),
                                 (0.25, (-26, -164), (26, -164)), (0.375, (-29, -168), (29, -168)), (d, (-26, -164), (26, -164))]),
    "talk": lambda d: arms(d, [(0, N, N), (0.3, N, (60, -120)), (0.7, (-58, -118), (52, -134)),
                               (1.1, (-50, -130), (60, -118)), (1.4, N, (48, -128)), (d, N, N)]),
    "think": lambda d: arms(d, [(0, N, N), (0.4, (-4, -118), (10, -160)), (2.6, (-4, -118), (10, -160)), (d, N, N)]),
    "sad": lambda d: arms(d, [(0, (-10, -102), (10, -102)), (1.6, (-12, -104), (12, -104)), (d, (-10, -102), (10, -102))]),
    "laugh": lambda d: arms(d, [(0, (-14, -112), (14, -112)), (0.4, (-16, -108), (16, -108)), (d, (-14, -112), (14, -112))]),
    "clap": lambda d: arms(d, [(0, (-4, -124), (4, -124)), (0.3, (-26, -120), (26, -120)), (d, (-4, -124), (4, -124))]),
    "shiver": lambda d: arms(d, [(0, (4, -132), (-4, -132)), (0.1, (8, -130), (-8, -130)), (0.2, (4, -132), (-4, -132)),
                                 (0.3, (8, -130), (-8, -130)), (d, (4, -132), (-4, -132))]),
    "hide": lambda d: arms(d, [(0, (-16, -182), (16, -182)), (d, (-16, -182), (16, -182))]),
    "proud": lambda d: arms(d, [(0, N, N), (0.4, (-46, -98), (46, -98)), (2.0, (-46, -98), (46, -98)), (d, N, N)]),
    "eat": lambda d: arms(d, [(0, N, N), (0.3, (-6, -118), (12, -164)), (0.6, (-6, -118), (24, -150)), (0.9, (-6, -118), (12, -164)),
                              (1.2, (-6, -118), (24, -150)), (1.5, (-6, -118), (12, -164)), (d, N, N)]),
    "yawn": lambda d: arms(d, [(0, N, N), (0.6, N, (14, -168)), (2.4, N, (14, -168)), (d, N, N)]),
    "blow": lambda d: arms(d, [(0, N, N), (0.4, (-14, -118), (14, -118)), (1.8, (-14, -118), (14, -118)), (d, N, N)]),
    "hug": lambda d: arms(d, [(0, N, N), (0.4, (-16, -122), (16, -122)), (1.6, (-16, -122), (16, -122)), (d, N, N)]),
    "wonder": lambda d: arms(d, [(0, N, N), (0.4, (-58, -150), (58, -150)), (2.0, (-58, -150), (58, -150)), (d, N, N)]),
}
# (el arma de la mano derecha se aparta de la cara: se inclina hacia fuera)
for _name, _deg in {"eat": 55, "think": 55, "yawn": 55, "hide": 50, "surprised": 45, "scared": 45, "blow": 40}.items():
    CLIPS[_name]["tracks"]["itemR"] = hold(CLIPS[_name]["dur"], _deg)
for _name, _arm in ARM_POSES.items():
    CLIPS[_name]["tracks"].update(_arm(CLIPS[_name]["dur"]))
CLIPS["cheer"]["tracks"].update({"foreArmL": keys((0, 0), (0.25, -8), (0.6, -28), (0.9, -8), (1.2, 0)),
                                 "foreArmR": keys((0, 0), (0.25, 8), (0.6, 28), (0.9, 8), (1.2, 0))})
# un poco de holgura natural en el codo, en reposo y al caminar
CLIPS["idle"]["tracks"].update({"foreArmL": hold(3.0, -7), "foreArmR": hold(3.0, 7)})
CLIPS["walk"]["tracks"].update({"foreArmL": sine(0.8, -9, 0.25), "foreArmR": sine(0.8, -9, 0.25)})
for _name, _face in FACES.items():
    _c = CLIPS[_name]
    for _k, _v in _face(_c["dur"]).items():
        _c["tracks"].setdefault(_k, _v)


def steam(offset, dur=3.0, rise=62):
    """Una nube de vapor que sube, crece y se disuelve; `offset` desfasa cada nube. Bucle sin costuras."""
    n = 12
    dy, sc = [], []
    for i in range(n + 1):
        u = ((i / n) + offset) % 1.0
        dy.append([r(dur * i / n), r(-rise * u)])
        sc.append([r(dur * i / n), r(0.15 + 0.95 * math.sin(math.pi * u))])
    return dy, sc


def _steam_tracks():
    out = {}
    for k, off in ((1, 0.0), (2, 0.34), (3, 0.67)):
        dy, sc = steam(off)
        out[f"steam{k}.dy"], out[f"steam{k}.sx"], out[f"steam{k}.sy"] = dy, sc, sc
    out["fire.sy"] = keys((0, 1), (0.3, 1.12), (0.6, 0.94), (0.9, 1.1), (1.2, 0.96), (1.5, 1.08), (1.8, 1))
    out["fire.sx"] = keys((0, 1), (0.4, 0.96), (0.8, 1.04), (1.2, 0.97), (1.8, 1))
    return out


PROP_CLIPS = {
    "still": dict(dur=1.0, loop=True, tracks={}),
    "swing": dict(dur=2.6, loop=True, tracks={"swing": sine(2.6, 5), "clapper": sine(2.6, -9, 0.2)}),
    "ring": dict(dur=1.1, loop=True, tracks={"swing": sine(1.1, 17), "clapper": sine(1.1, -26, 0.25)}),
    "glow": dict(dur=2.4, loop=True, tracks={
        "flame.sy": keys((0, 1), (0.4, 1.14), (0.8, 0.94), (1.3, 1.1), (1.8, 0.96), (2.4, 1)),
        "flame.sx": keys((0, 1), (0.5, 0.94), (1.1, 1.05), (1.7, 0.97), (2.4, 1)),
        "glow.sx": keys((0, 1), (0.8, 1.06), (1.6, 0.97), (2.4, 1)),
        "glow.sy": keys((0, 1), (0.8, 1.06), (1.6, 0.97), (2.4, 1))}),
    "boil": dict(dur=3.0, loop=True, tracks=_steam_tracks()),
    "jingle": dict(dur=0.5, loop=True, tracks={"bag": sine(0.5, 6), "root.dy": keys((0, 0), (0.12, -2), (0.25, 0), (0.37, -2), (0.5, 0))}),
    "sway": dict(dur=2.6, loop=True, tracks={"kite": sine(2.6, 7), "tail": sine(1.3, 16, 0.2)}),
    "sun": dict(dur=3.2, loop=True, tracks={"stem": sine(3.2, 3), "head": sine(3.2, 5, 0.3)}),
    "grow": dict(dur=3.0, loop=False, tracks={"stem.sy": keys((0, 0.2), (3.0, 1.0)), "stem.sx": keys((0, 0.6), (3.0, 1.0)), "head": keys((0, -8), (1.5, 6), (3.0, 0))}),
    "shimmer": dict(dur=2.4, loop=True, tracks={"glow.sx": keys((0, 1), (1.2, 1.15), (2.4, 1)), "glow.sy": keys((0, 1), (1.2, 1.15), (2.4, 1)), "leaves": sine(2.4, 2)}),
    # La mariposa aletea (las alas giran a la vez en sentidos opuestos) y sube y baja mientras vuela
    "flutter": dict(dur=0.5, loop=True, tracks={
        "wingL": sine(0.5, 34), "wingR": sine(0.5, -34),
        "root.dy": keys((0, 0), (0.125, -5), (0.25, 0), (0.375, -5), (0.5, 0))}),
    "goat_idle": dict(dur=2.8, loop=True, tracks={
        "head": sine(2.8, 4), "tail": sine(0.9, 14), "eyes.sy": blink(2.8, 0.5),
        "root.dy": keys((0, 0), (1.4, -1.2), (2.8, 0))}),
    # Cabecea hacia arriba al balar, y la barriga y la cola acompañan
    "goat_baa": dict(dur=1.4, loop=True, tracks={
        "head": keys((0, 0), (0.25, -14), (0.7, -11), (1.1, 2), (1.4, 0)), "tail": sine(0.6, 18),
        "eyes.sy": blink(1.4, 0.4), "root.dy": keys((0, 0), (0.25, -2), (0.7, -1.5), (1.4, 0))}),
    # Camina al trote diagonal: delantera cercana con trasera lejana, y al revés
    "goat_walk": dict(dur=0.8, loop=True, tracks={
        "legFN": sine(0.8, 24), "legBF": sine(0.8, 24), "legFF": sine(0.8, -24), "legBN": sine(0.8, -24),
        "head": sine(0.8, 4), "tail": sine(0.4, 12),
        "root.dy": keys((0, 0), (0.2, -3), (0.4, 0), (0.6, -3), (0.8, 0))}),
    # Cabriola: salta con las patas recogidas (delanteras hacia delante, traseras hacia atrás) y cae
    "goat_hop": dict(dur=1.0, loop=True, tracks={
        "root.dy": keys((0, 0), (0.15, 0), (0.4, -26), (0.65, 0), (1.0, 0)),
        "legFN": keys((0, 0), (0.15, 8), (0.4, 38), (0.65, 6), (1.0, 0)),
        "legFF": keys((0, 0), (0.15, 8), (0.4, 30), (0.65, 6), (1.0, 0)),
        "legBN": keys((0, 0), (0.15, -8), (0.4, -38), (0.65, -6), (1.0, 0)),
        "legBF": keys((0, 0), (0.15, -8), (0.4, -30), (0.65, -6), (1.0, 0)),
        "head": keys((0, 0), (0.15, 6), (0.4, -10), (0.65, 4), (1.0, 0)), "tail": sine(0.5, 20),
        "eyes.sy": blink(1.0, 0.4)}),
    "hoot": dict(dur=3.4, loop=True, tracks={
        "eyes.sy": blink(3.4, 0.55),
        "root.sy": keys((0, 1), (0.5, 1.04), (1.0, 1), (3.4, 1)),
        "root.dy": keys((0, 0), (0.5, -2), (1.0, 0), (3.4, 0))}),
}


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = {"format": "caldero-clips", "version": 1, "rig": "humanoid", "clips": CLIPS}
    OUT.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(CLIPS)} clips, {OUT.stat().st_size / 1024:.1f} KB → {OUT.relative_to(OUT.parents[2])}")
    pout = OUT.with_name("props.json")
    pout.write_text(json.dumps({"format": "caldero-clips", "version": 1, "rig": "prop", "clips": PROP_CLIPS},
                               ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(PROP_CLIPS)} clips de objetos, {pout.stat().st_size / 1024:.1f} KB → {pout.relative_to(OUT.parents[2])}")


if __name__ == "__main__":
    main()
