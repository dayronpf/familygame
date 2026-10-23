#!/usr/bin/env python3
"""Sonido de fondo del pack «Mar de las Estrellas», sintetizado desde cero (sin muestras de terceros).

Olas que rompen despacio en la orilla, el crujido suave de la madera de un barco anclado y, de vez en cuando, una
gaviota lejana; debajo, el mismo colchón de acordes de nana que el fondo del Reino de la Luna, más bajito, para que
el cuento siga sonando a cuento. Dura 48 s y empalma consigo mismo sin salto. Uso:
    python3 tools/audio/make_ambient_mar.py app/assets/audio/ambient_mar.m4a
Licencia: original del proyecto; no deriva de ninguna grabación (CC0, como el resto del sonido sintetizado).
"""
import subprocess
import sys

import numpy as np

SR = 32000
DUR = 48.0
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(11)


def lowpass(x, cutoff):
    """Filtro paso bajo de un polo, circular (para que el bucle empalme)."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for _ in range(2):  # dos pasadas: la segunda arranca con el estado del final
        for i in range(len(x)):
            acc = (1 - a) * x[i] + a * acc
            y[i] = acc
    return y


# ------------------------------------------------------------------ olas
# Ruido filtrado con una envolvente que sube y baja cada 6–8 s (una ola), con 7 olas exactas en 48 s.
noise = rng.standard_normal(N)
surf = lowpass(noise, 900.0) * 0.8 + lowpass(noise, 250.0) * 1.2
waves = np.zeros(N)
period = DUR / 7
for k in range(7):
    c = (k + 0.5) * period + rng.uniform(-0.6, 0.6)
    d = ((t - c + DUR / 2) % DUR) - DUR / 2  # distancia circular al centro de la ola
    env = np.where(d < 0, np.exp(-(d / 2.2) ** 2), np.exp(-(d / 3.4) ** 2))  # sube rápido, se retira despacio
    waves += env * rng.uniform(0.75, 1.0)
waves = surf * (0.12 + waves)

# ------------------------------------------------------------------ madera
creaks = np.zeros(N)
for _ in range(6):
    n0 = int(rng.uniform(0, DUR - 2) * SR)
    L = int(rng.uniform(0.5, 0.9) * SR)
    tt = np.arange(L) / SR
    f0 = rng.uniform(140, 210)
    f = f0 * (1 + 0.25 * np.sin(2 * np.pi * 1.3 * tt))  # el tono resbala como una tabla que cede
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sign(np.sin(phase)) * 0.3 + np.sin(phase) * 0.7  # algo áspero
    env = np.sin(np.pi * tt / tt[-1]) ** 2
    creaks[n0:n0 + L] += tone * env * 0.06

# ------------------------------------------------------------------ gaviotas
gulls = np.zeros(N)
for pos in (7.0, 23.5, 38.0):
    for j in range(rng.integers(2, 4)):
        n0 = int((pos + j * 0.45) * SR)
        L = int(0.35 * SR)
        tt = np.arange(L) / SR
        f = 1500 - 700 * (tt / tt[-1]) ** 0.7  # el grito cae de agudo a grave
        phase = 2 * np.pi * np.cumsum(f) / SR
        env = np.sin(np.pi * tt / tt[-1]) ** 1.5
        cry = (np.sin(phase) + 0.3 * np.sin(2 * phase)) * env * 0.05
        gulls[n0:n0 + L] += cry
# lejanas: con eco y sin agudos
gulls = lowpass(gulls, 2400.0)
echo = np.zeros(N)
dly = int(0.32 * SR)
echo[dly:] += 0.4 * gulls[:-dly]
gulls += echo

# ------------------------------------------------------------------ colchón
CHORDS = [[110.0, 164.81, 220.0], [87.31, 174.61, 220.0], [130.81, 196.0, 261.63], [98.0, 196.0, 246.94]]
SEG = N // 4
pad = np.zeros(N)
for i, ch in enumerate(CHORDS):
    L = SEG + SR * 4
    tt = np.arange(L) / SR
    seg = sum(np.sin(2 * np.pi * f * tt) + 0.6 * np.sin(2 * np.pi * (f + 0.5) * tt) for f in ch) / (len(ch) * 1.6)
    env = np.minimum(1, tt / 4) * np.minimum(1, (tt[-1] - tt) / 4)
    idx = (i * SEG + np.arange(L)) % N
    np.add.at(pad, idx, seg * env)

mix = waves * 0.9 + creaks + gulls + pad * 0.12
# Misma sonoridad media que el fondo del Reino de la Luna (≈ −15 dB), sin pasarse de pico
mix *= 10 ** (-15 / 20) / np.sqrt(np.mean(mix ** 2))
mix = np.clip(mix, -0.97, 0.97)
pcm = (mix * 32767).astype("<i2").tobytes()

# AAC en .m4a: lo reproducen tanto iOS como Android (iOS no reproduce Ogg)
out = sys.argv[1] if len(sys.argv) > 1 else "ambient_mar.m4a"
subprocess.run(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
     "-c:a", "aac", "-b:a", "48k", out],
    input=pcm, check=True)
print("escrito", out)
