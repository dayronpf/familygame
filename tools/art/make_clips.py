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
}


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
    "goat_idle": dict(dur=2.8, loop=True, tracks={
        "head": sine(2.8, 5), "tail": sine(0.9, 16), "eyes.sy": blink(2.8, 0.5),
        "root.dy": keys((0, 0), (1.4, -1.5), (2.8, 0))}),
    "goat_baa": dict(dur=1.4, loop=True, tracks={
        "head": keys((0, 0), (0.25, -16), (0.7, -12), (1.1, 2), (1.4, 0)), "tail": sine(0.6, 20),
        "eyes.sy": blink(1.4, 0.4), "root.dy": keys((0, 0), (0.25, -3), (0.7, -2), (1.4, 0))}),
    "goat_walk": dict(dur=0.8, loop=True, tracks={
        "legsA": sine(0.8, 22), "legsB": sine(0.8, -22), "head": sine(0.8, 4), "tail": sine(0.4, 12),
        "root.dy": keys((0, 0), (0.2, -3), (0.4, 0), (0.6, -3), (0.8, 0))}),
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
