#!/usr/bin/env python3
"""Efectos de sonido del cuento («¡Cric!», «¡Beee!», «¡Plaf!»…): los que la voz no sabe imitar.

Cada efecto es un .ogg corto (≤ 1,8 s, mono, 32 kHz) en `app/assets/audio/sfx/<id>.ogg`. Salen de dos sitios, los dos
**sin derechos de autor** (ver `docs/21-efectos-de-sonido.md`):

* grabaciones **CC0** de terceros (en `tools/audio/sfx_src/`, con su licencia): Kenney.nl («Impact Sounds»,
  «Interface Sounds», «RPG Audio») y AntumDeluge en OpenGameArt («Sheep Baa»);
* sonidos **sintetizados desde cero** aquí mismo (viento, siseo, chapoteo, gruñido, búho…): originales del proyecto,
  dedicados al dominio público (CC0).

Uso (desde la raíz del repositorio; necesita ffmpeg y numpy):
    python3 tools/audio/build_sfx.py
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

SR = 32000
ROOT = Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "tools/audio/sfx_src"
OUT = ROOT / "app/assets/audio/sfx"
rng = np.random.default_rng(11)


# ------------------------------------------------------------------ utilidades
def load(name):
    """Lee un .ogg a mono 32 kHz (float)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(SRC / name), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def trim(x, thresh=0.01, tail=0.02):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    return x[max(0, idx[0] - int(0.005 * SR)): min(len(x), idx[-1] + int(tail * SR))]


def fade(x, fin=0.004, fout=0.05):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def norm(x, rms_db=-20.0, peak=0.92):
    """Igual sonoridad para todos (volumen medio de -20 dB) sin pasar de [-peak, peak]."""
    active = x[np.abs(x) > 0.02 * (np.max(np.abs(x)) or 1.0)]
    rms = np.sqrt(np.mean(active ** 2)) if len(active) else 1.0
    y = x * (10 ** (rms_db / 20) / rms)
    m = np.max(np.abs(y)) or 1.0
    return y * (peak / m) if m > peak else y


def cut(x, seconds):
    return x[: int(seconds * SR)]


def env(n, attack, release):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(attack, 1e-6))
    r = np.minimum(1.0, (n / SR - t) / max(release, 1e-6))
    return a * r


def lowpass(x, fc):
    """Filtro de un polo (suficiente para dar cuerpo al ruido)."""
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, fc):
    return x - lowpass(x, fc)


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def tone(freq, seconds, phase=0.0):
    t = np.arange(int(seconds * SR)) / SR
    return np.sin(2 * np.pi * (freq * t + phase))


def sweep(f0, f1, seconds):
    t = np.arange(int(seconds * SR)) / SR
    f = f0 + (f1 - f0) * (t / seconds)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def save(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    x = fade(norm(trim(x)))
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "3", str(OUT / f"{name}.ogg")], input=pcm, check=True)
    print(f"{name}.ogg  {len(x) / SR:.2f} s  {(OUT / f'{name}.ogg').stat().st_size / 1024:.1f} KB")


# ------------------------------------------------------------- grabaciones CC0
def recorded():
    save("bleat", fade(load("oga-antumdeluge-sheep_baa.ogg"), 0.01, 0.12))
    save("creak", cut(load("kenney-rpg-creak2.ogg"), 0.9))
    save("crack", cut(load("kenney-impact-impactPlank_medium_002.ogg"), 0.6))
    save("coins", cut(load("kenney-rpg-handleCoins.ogg"), 0.85))
    save("clang", cut(load("kenney-impact-impactMetal_heavy_001.ogg"), 1.2))
    save("clink", load("kenney-impact-impactMetal_light_002.ogg"))
    save("bell", fade(cut(load("kenney-impact-impactBell_heavy_001.ogg"), 1.7), 0.004, 0.4))
    save("click", load("kenney-rpg-metalClick.ogg"))
    save("drop", load("kenney-interface-drop_002.ogg"))


# ------------------------------------------------------------- sintetizados
def synthesized():
    # viento: ruido filtrado que sube y baja (¡fuuu!, ¡fiuuu!, ¡suish!)
    n = noise(1.5)
    w = lowpass(highpass(n, 250), 1400) * env(len(n), 0.5, 0.7) ** 1.5
    w += 0.5 * lowpass(highpass(noise(1.5), 600), 2600) * env(len(n), 0.45, 0.6)
    save("wind", w)
    # siseo (¡shhh!, ¡chis!)
    n = noise(1.0)
    save("hiss", highpass(n, 2500) * env(len(n), 0.12, 0.45))
    # chapoteo (¡plaf!): golpe de agua + burbujas
    n = noise(0.6)
    sp = lowpass(highpass(n, 200), 3200) * np.exp(-np.arange(len(n)) / SR * 9)
    for k in range(5):
        at = int((0.04 + 0.07 * k) * SR)
        b = sweep(500 + 200 * k, 1100 + 250 * k, 0.07) * np.hanning(int(0.07 * SR)) * 0.35
        sp[at: at + len(b)] += b[: max(0, len(sp) - at)]
    save("splash", sp)
    # burbuja (¡plof!, ¡flup!, ¡pof!)
    b = sweep(520, 240, 0.16) * np.exp(-np.arange(int(0.16 * SR)) / SR * 18)
    save("plop", b)
    # latido / golpe sordo (¡pum!)
    th = np.zeros(int(0.7 * SR))
    for at in (0.0, 0.22):
        s = tone(62, 0.22) * np.exp(-np.arange(int(0.22 * SR)) / SR * 16)
        i = int(at * SR)
        th[i: i + len(s)] += s
    save("thump", th)
    # salto (¡hop!): un «boing» suave
    save("hop", sweep(280, 640, 0.22) * np.exp(-np.arange(int(0.22 * SR)) / SR * 9))
    # rugido de barriga (¡grrr!, ¡rummm!)
    t = np.arange(int(1.2 * SR)) / SR
    g = (np.sign(np.sin(2 * np.pi * 58 * t)) * 0.5 + 0.5 * tone(116, 1.2)) * (0.6 + 0.4 * np.sin(2 * np.pi * 17 * t))
    g = lowpass(g + 0.25 * lowpass(noise(1.2), 400), 520) * env(len(t), 0.2, 0.5)
    save("growl", g)
    # búho (¡uuuh!): dos notas suaves con vibrato
    t = np.arange(int(1.1 * SR)) / SR
    def note(f, a, b):
        s = np.sin(2 * np.pi * (f * t + 3 * np.sin(2 * np.pi * 5 * t) / (2 * np.pi * 5)))
        return s * np.clip((t - a) / 0.08, 0, 1) * np.clip((b - t) / 0.12, 0, 1)
    save("hoot", note(392, 0.0, 0.42) + 0.9 * note(330, 0.5, 1.05))
    # aleteo (¡frrr!)
    n = noise(0.55)
    t = np.arange(len(n)) / SR
    save("flutter", lowpass(highpass(n, 900), 3200) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) * env(len(n), 0.05, 0.2))


if __name__ == "__main__":
    recorded()
    synthesized()
    print(f"{len(list(OUT.glob('*.ogg')))} efectos en {OUT.relative_to(ROOT)}")
