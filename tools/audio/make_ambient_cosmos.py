#!/usr/bin/env python3
"""Sonido de fondo del pack «Aldea de las Nubes», sintetizado desde cero (sin muestras de terceros).

El espacio que no da miedo: un zumbido grave y suave, como el de una nave tranquila, un aire quieto de nubes
y estrellas que titilan con notas agudas de campanita; debajo, el mismo colchón de acordes de nana que el fondo del
Reino de la Luna, un poco más presente que en el mar. Dura 48 s y empalma consigo mismo sin salto. Uso:
    python3 tools/audio/make_ambient_cosmos.py app/assets/audio/ambient_cosmos.m4a
Licencia: original del proyecto; no deriva de ninguna grabación (CC0, como el resto del sonido sintetizado).
"""
import subprocess
import sys

import numpy as np

SR = 32000
DUR = 48.0
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(23)


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


# ------------------------------------------------------------------ zumbido de la nave
# Dos senos graves casi iguales: laten despacio (0,25 Hz, 12 latidos exactos en 48 s) como un motor dormido.
hum = (np.sin(2 * np.pi * 55.0 * t) + np.sin(2 * np.pi * 55.25 * t)) * 0.5
hum += 0.3 * np.sin(2 * np.pi * 110.0 * t)

# ------------------------------------------------------------------ aire de nubes
noise = rng.standard_normal(N)
air = lowpass(noise, 420.0)
# Un aire casi constante y muy suave: ruido filtrado que sube y baja despacio suena a olas, y esto es el espacio
air *= 0.9 + 0.1 * np.sin(2 * np.pi * t / 24.0)

# ------------------------------------------------------------------ estrellas que titilan
SCALE = [880.0, 987.77, 1174.66, 1318.51, 1567.98, 1760.0]  # pentatónica, siempre consonante con el colchón
stars = np.zeros(N)
for _ in range(34):
    n0 = int(rng.uniform(0, DUR) * SR)
    L = int(rng.uniform(1.2, 2.4) * SR)
    tt = np.arange(L) / SR
    f = SCALE[rng.integers(len(SCALE))]
    env = np.exp(-tt * rng.uniform(2.0, 3.2)) * np.minimum(1, tt / 0.01)
    tone = np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(2 * np.pi * 2.01 * f * tt)
    idx = (n0 + np.arange(L)) % N  # circular: el bucle empalma
    np.add.at(stars, idx, tone * env * rng.uniform(0.025, 0.05))
# un eco largo, como si sonaran muy lejos
echo = np.zeros(N)
dly = int(0.41 * SR)
echo += 0.35 * np.roll(stars, dly) + 0.15 * np.roll(stars, 2 * dly)
stars += echo

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

mix = hum * 0.08 + air * 0.06 + stars + pad * 0.3
# Misma sonoridad que el fondo del Reino de la Luna: ≈ −24 dB de media y −10 dB de pico. Con la voz del sistema (más
# baja que un reproductor de archivos), un fondo a −15 dB de media tapaba el cuento.
mix *= 10 ** (-24 / 20) / np.sqrt(np.mean(mix ** 2))
mix *= min(1.0, 10 ** (-10 / 20) / np.max(np.abs(mix)))
pcm = (mix * 32767).astype("<i2").tobytes()

# AAC en .m4a: lo reproducen tanto iOS como Android (iOS no reproduce Ogg)
out = sys.argv[1] if len(sys.argv) > 1 else "ambient_cosmos.m4a"
subprocess.run(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
     "-c:a", "aac", "-b:a", "48k", out],
    input=pcm, check=True)
print("escrito", out)
