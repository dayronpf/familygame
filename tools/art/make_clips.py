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
}


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = {"format": "caldero-clips", "version": 1, "rig": "humanoid", "clips": CLIPS}
    OUT.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(CLIPS)} clips, {OUT.stat().st_size / 1024:.1f} KB → {OUT.relative_to(OUT.parents[2])}")


if __name__ == "__main__":
    main()
