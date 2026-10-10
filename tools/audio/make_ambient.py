#!/usr/bin/env python3
"""Sonido de fondo del modo cuento/holograma, sintetizado desde cero (sin muestras de terceros).

Un colchón de acordes suaves (La menor – Fa – Do – Sol) con campanitas de nana que caen despacio.
Dura 48 s y empalma consigo mismo sin salto (todo el material es periódico en 48 s). Uso:
    python3 tools/audio/make_ambient.py app/assets/audio/ambient.ogg
Licencia: original del proyecto; no deriva de ninguna grabación.
"""
import subprocess
import sys

import numpy as np

SR = 32000
DUR = 48.0
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)

CHORDS = [  # cada acorde dura 12 s
    [110.0, 164.81, 220.0, 261.63],   # Am
    [87.31, 174.61, 220.0, 261.63],   # F
    [130.81, 196.0, 261.63, 329.63],  # C
    [98.0, 196.0, 246.94, 293.66],    # G
]
SEG = N // 4


def pad(freqs, n):
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for det, amp in ((0.0, 1.0), (0.6, 0.7), (-0.5, 0.7)):
            out += amp * np.sin(2 * np.pi * (f + det) * tt)
        out += 0.25 * np.sin(2 * np.pi * 2 * f * tt)
    return out / (len(freqs) * 2.2)


sig = np.zeros(N)
for i, ch in enumerate(CHORDS):
    seg = pad(ch, SEG + SR * 4)  # 4 s extra para solaparse con el siguiente
    env = np.minimum(1, np.arange(len(seg)) / (SR * 4)) * np.minimum(1, (len(seg) - np.arange(len(seg))) / (SR * 4))
    seg = seg * env
    start = i * SEG
    idx = (start + np.arange(len(seg))) % N  # circular: el último acorde se mezcla con el primero
    np.add.at(sig, idx, seg)

# Campanitas de nana: notas de La menor pentatónica, caen una cada ~2-3 s con eco suave.
scale = [440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
bells = np.zeros(N)
pos = 0.5
while pos < DUR - 3:
    f = rng.choice(scale)
    n0 = int(pos * SR)
    L = int(3.0 * SR)
    tt = np.arange(L) / SR
    env = np.exp(-tt * 1.6)
    note = (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * 2.01 * f * tt)) * env * 0.5
    bells[n0:n0 + L] += note[: max(0, min(L, N - n0))]
    pos += rng.uniform(1.8, 3.4)
# eco
echo = np.zeros(N)
d = int(0.45 * SR)
echo[d:] += 0.35 * bells[:-d]
bells = bells + echo

mix = sig * 0.9 + bells * 0.22
mix /= np.max(np.abs(mix)) * 1.15
pcm = (mix * 32767).astype("<i2").tobytes()

out = sys.argv[1] if len(sys.argv) > 1 else "ambient.ogg"
subprocess.run(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
     "-c:a", "libvorbis", "-q:a", "2", out],
    input=pcm, check=True)
print("escrito", out)
