#!/usr/bin/env python3
"""Une una carpeta de PNG (f000.png…) en un GIF en bucle. Requiere Pillow.
Uso: python3 tools/art/make_gif.py frames_dir out.gif [fps] [ancho]"""
import sys
from pathlib import Path

from PIL import Image

src, out = Path(sys.argv[1]), sys.argv[2]
fps = int(sys.argv[3]) if len(sys.argv) > 3 else 10
width = int(sys.argv[4]) if len(sys.argv) > 4 else 400
frames = []
for f in sorted(src.glob("f*.png")):
    im = Image.open(f).convert("RGB")
    frames.append(im.resize((width, round(im.height * width / im.width)), Image.LANCZOS))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=round(1000 / fps), loop=0, optimize=True)
print(f"{len(frames)} fotogramas → {out}")
