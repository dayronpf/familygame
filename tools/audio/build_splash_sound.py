#!/usr/bin/env python3
"""Sonido de la pantalla de bienvenida: una sola pista que va al compás de la animación (`app/lib/src/ui/splash_page.dart`).

Todo está **sintetizado desde cero** aquí (sin muestras de terceros): original del proyecto, dedicado al dominio
público (CC0). Estéreo, 44,1 kHz, AAC en `app/assets/audio/splash.m4a` (Android e iPhone lo leen igual).

Guion (segundos; la animación dura `SPLASH_SECONDS`, y cada momento sale de su fracción en splash_page.dart):
  0.00  colchón de aire que crece y un brillo agudo que sube
  0.10  estrella fugaz que cruza el cielo (silbido brillante que baja)
  0.25  el libro aparece con un «bloop» suave
  0.85  el libro se abre: soplo de páginas y un arpegio de arpa mágica que sube
  1.30  estallido de chispas doradas (campanitas)
  1.25  la luna sale: acorde cálido de campanas
  1.7→  cada letra del nombre, una campanita (pentatónica que sube)
  2.9→  el destello cruza el nombre: barrido de cristal
  3.10  acorde final que florece y se apaga despacio

Uso (desde la raíz del repositorio; necesita ffmpeg y numpy):
    python3 tools/audio/build_splash_sound.py
"""
import subprocess
from pathlib import Path

import numpy as np

SR = 44100
SPLASH_SECONDS = 4.2  # = splashMinimum de app.dart
LENGTH = 5.6
ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "app/assets/audio/splash.m4a"
rng = np.random.default_rng(7)
N = int(LENGTH * SR)
L = np.zeros(N)
R = np.zeros(N)


def at(frac):
    """Segundo de la pista que corresponde a una fracción de la animación."""
    return frac * SPLASH_SECONDS


def t_of(n):
    return np.arange(n) / SR


def place(sig, start, pan=0.0, gain=1.0):
    """Suma [sig] en la pista desde [start] segundos, con paneo -1 (izq.) … 1 (der.)."""
    i = int(start * SR)
    if i >= N:
        return
    sig = sig[: N - i] * gain
    lg = np.cos((pan + 1) * np.pi / 4)
    rg = np.sin((pan + 1) * np.pi / 4)
    L[i:i + len(sig)] += sig * lg
    R[i:i + len(sig)] += sig * rg


def bell(freq, dur=1.6, bright=1.0):
    """Campanita: parciales inarmónicos que se apagan a distinto ritmo (suena a celesta/glockenspiel)."""
    n = int(dur * SR)
    t = t_of(n)
    sig = np.zeros(n)
    for ratio, amp, decay in [(1, 1.0, 2.2), (2.0, 0.45 * bright, 3.5), (3.01, 0.22 * bright, 5.0),
                              (4.2, 0.12 * bright, 7.0), (5.43, 0.06 * bright, 9.0)]:
        sig += amp * np.sin(2 * np.pi * freq * ratio * t + rng.uniform(0, 6.28)) * np.exp(-decay * t)
    attack = np.minimum(1, t / 0.003)
    return sig * attack


def pluck(freq, dur=1.2):
    """Cuerda de arpa (Karplus-Strong): cálida y suave."""
    n = int(dur * SR)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.5 * (buf[i % period] + buf[(i + 1) % period]) * 0.996
    # suaviza el ataque y quita algo de brillo
    out = np.convolve(out, np.ones(4) / 4, mode="same")
    return out * np.minimum(1, t_of(n) / 0.004)


def noise_sweep(dur, f0, f1, q=6.0):
    """Ruido filtrado por una banda que se desplaza de f0 a f1 (soplos, whoosh)."""
    n = int(dur * SR)
    x = rng.normal(0, 1, n)
    out = np.zeros(n)
    # filtro pasabanda resonante de 2 polos, con frecuencia que cambia muestra a muestra
    y1 = y2 = 0.0
    freqs = np.geomspace(f0, f1, n)
    for i in range(n):
        w = 2 * np.pi * freqs[i] / SR
        r = np.exp(-w / (2 * q))
        a1 = -2 * r * np.cos(w)
        a2 = r * r
        y = (1 - r) * x[i] - a1 * y1 - a2 * y2
        y2, y1 = y1, y
        out[i] = y
    return out / (np.max(np.abs(out)) or 1)


def pad(freqs, dur, attack=1.0):
    """Colchón suave: senos ligeramente desafinados con vibrato lento."""
    n = int(dur * SR)
    t = t_of(n)
    sig = np.zeros(n)
    for f in freqs:
        for det in (-0.6, 0.6):
            vib = 0.0025 * np.sin(2 * np.pi * 4.5 * t + rng.uniform(0, 6))
            sig += np.sin(2 * np.pi * (f + det) * t * (1 + vib))
    e = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / (dur * 0.5))
    return sig * e / (len(freqs) * 2)


def reverb(x, seconds=1.8, mix=0.28):
    """Reverberación sencilla: ruido que se apaga, convolucionado (sala amplia y suave)."""
    n = int(seconds * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.linspace(0, 7, n))
    ir = np.convolve(ir, np.ones(30) / 30, mode="same")  # quita lo áspero
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = np.fft.irfft(np.fft.rfft(x, len(x) + n) * np.fft.rfft(ir, len(x) + n))[: len(x)]
    return (1 - mix) * x + mix * wet


def hz(note):
    """Nota MIDI a Hz."""
    return 440.0 * 2 ** ((note - 69) / 12)


# Tonalidad: Re mayor pentatónica (dulce y sin tensiones), todo en registro de cajita de música.
PENTA = [62, 64, 66, 69, 71]


def penta(i, octave=1):
    return hz(PENTA[i % 5] + 12 * (i // 5 + octave))


# ------------------------------------------------------------------ guion
# 0.00 colchón de aire que crece (Re, La, Fa#) + brillo que sube
place(pad([hz(50), hz(57), hz(66)], 5.0, attack=1.4), 0.0, gain=0.22)
sh = noise_sweep(1.4, 2500, 9000, q=3) * np.linspace(0, 1, int(1.4 * SR)) ** 2 * np.linspace(1, 0, int(1.4 * SR)) ** 0.5
place(sh, 0.0, pan=-0.2, gain=0.05)

# 0.10 estrella fugaz: silbido brillante que baja + chispitas
fs = noise_sweep(0.7, 9000, 3000, q=10) * np.hanning(int(0.7 * SR))
place(fs, at(0.025), pan=-0.7, gain=0.10)
for k in range(5):
    place(bell(penta(9 - k, 2), 0.6, 0.6), at(0.03) + k * 0.09, pan=-0.7 + k * 0.25, gain=0.05)

# 0.25 «bloop» del libro: seno que sube con un poco de cuerpo
n = int(0.35 * SR)
tt = t_of(n)
bloop = np.sin(2 * np.pi * (180 + 260 * (1 - np.exp(-tt * 18))) * tt) * np.exp(-tt * 9) * np.minimum(1, tt / 0.004)
place(bloop, at(0.06), gain=0.16)

# 0.85 el libro se abre: soplo de páginas + arpegio de arpa que sube
place(noise_sweep(0.6, 600, 2400, q=2) * np.hanning(int(0.6 * SR)), at(0.19), pan=0.1, gain=0.10)
for k, note in enumerate([50, 57, 62, 66, 69, 74, 78, 81]):
    place(pluck(hz(note), 1.6), at(0.20) + k * 0.075, pan=-0.6 + k * 0.17, gain=0.18)

# 1.25 la luna: acorde cálido de campanas (Re, Fa#, La, Mi)
for k, note in enumerate([74, 78, 81, 88]):
    place(bell(hz(note), 2.6, 0.7), at(0.30) + k * 0.04, pan=[-0.3, 0.3, -0.1, 0.2][k], gain=0.07)

# 1.30 estallido de chispas doradas
for k in range(14):
    place(bell(penta(rng.integers(5, 15), 1), 0.7, 1.2), at(0.31) + rng.uniform(0, 0.45), pan=rng.uniform(-0.9, 0.9),
          gain=rng.uniform(0.02, 0.045))

# 1.7→ cada letra del nombre (Mininoches = 10 letras): igual que _TitleReveal (progress 0.40→0.72, easeOut)
letters = 10
for i in range(letters):
    start_progress = i / letters * 0.7 + 0.12  # cuando la letra ya casi aterriza
    # progress = easeOut((intro-0.40)/0.32) → se invierte la curva para saber el instante
    p = min(start_progress, 0.999)
    lin = 1 - np.sqrt(1 - p)  # inversa aproximada de easeOut (1-(1-x)^2)
    t_letter = at(0.40 + 0.32 * lin)
    place(bell(penta(i + 2, 1), 1.0, 0.9), t_letter, pan=-0.6 + 1.2 * i / (letters - 1), gain=0.075)

# 2.9→ destello que cruza el nombre: barrido de cristal (ruido agudo + glissando de campanitas)
place(noise_sweep(1.1, 4000, 11000, q=8) * np.hanning(int(1.1 * SR)), at(0.70), pan=-0.5, gain=0.035)
place(noise_sweep(1.1, 4500, 12000, q=8) * np.hanning(int(1.1 * SR)), at(0.71), pan=0.5, gain=0.035)
for k in range(8):
    place(bell(penta(k + 8, 1), 0.8, 1.1), at(0.70) + k * 0.1, pan=-0.8 + k * 0.23, gain=0.03)

# 3.10 acorde final que florece (Re mayor add9, cuerdas de arpa + campanas + colchón)
for k, note in enumerate([50, 57, 62, 66, 69, 76]):
    place(pluck(hz(note), 2.4), at(0.74) + k * 0.025, pan=-0.5 + k * 0.2, gain=0.13)
for k, note in enumerate([86, 90, 93]):
    place(bell(hz(note), 2.4, 0.6), at(0.75) + k * 0.05, pan=[-0.4, 0.4, 0][k], gain=0.05)
place(pad([hz(62), hz(66), hz(69), hz(76)], 2.6, attack=0.5), at(0.74), gain=0.16)

# ------------------------------------------------------------------ mezcla
L = reverb(L)
R = reverb(R)
# fundido final y normalización suave
fade_n = int(1.2 * SR)
L[-fade_n:] *= np.linspace(1, 0, fade_n) ** 2
R[-fade_n:] *= np.linspace(1, 0, fade_n) ** 2
peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
L, R = L / peak * 0.6, R / peak * 0.6
stereo = np.stack([L, R], axis=1).astype(np.float32)

OUT.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                "-c:a", "aac", "-b:a", "128k", str(OUT)], input=stereo.tobytes(), check=True)
print(f"{OUT.relative_to(ROOT)}: {LENGTH:.1f} s, {OUT.stat().st_size // 1024} KB")
