#!/usr/bin/env python3
"""Kit de personajes del pack «Mar de las Estrellas» (piratas y sirenas, docs/26).

Usa el mismo kit procedural que el medieval (`medieval_kit.build`: esqueleto humano, piezas y paleta) con las
piezas piratas que se añadieron allí (tricornio, rayas, casaca, catalejo…). Dos personajes cambian el cuerpo
sin cambiar de esqueleto, para que los mismos gestos les sirvan:

* **Nácar, la sirena** (`body: mermaid`): la cola vive en el hueso `legL` (pivote en la cadera) y `legR` queda
  vacío. Al andar la cola se mece como si nadara; al sentarse se tiende de lado, como sobre una roca.
* **Remolino, el pulpo** (`body: octopus`): el manto es la cabeza (con sus ojos, cejas y boca de siempre), dos
  tentáculos son las piernas, otros dos los brazos y cuatro más se quedan detrás, quietos.

El loro y la tortuga son objetos animados, como el búho y la cabrita: el loro usa los gestos `hoot` (posado) y
`flutter` (aleteo); la tortuga, los de la cabrita (`goat_idle`, `goat_walk`).

Uso:
    python3 tools/art/mar_kit.py            # escribe art/mar/ (rigs, índice y hoja de personajes)
"""
import json
from pathlib import Path

import anim
import medieval_kit as kit
from medieval_kit import DARK, S, ell, mix, n, node, poly, rrect, shade, shine

OUT = Path(__file__).resolve().parent.parent.parent / "art" / "mar"

# Pijama de los protagonistas (para dormir en el camarote o en la arena)
PIJAMA = {"bruno": {"primary": "#9ab8f0", "secondary": "#ffffff", "pants": "#9ab8f0"},
          "vega": {"primary": "#f0a8c8", "secondary": "#ffffff", "pants": "#f0a8c8"}}


# ------------------------------------------------------------------ utilidades
def find(nd, id_):
    if nd["id"] == id_:
        return nd
    for c in nd["pre"] + nd["post"]:
        f = find(c, id_)
        if f:
            return f
    return None


def recolor(nd, old, new):
    for sh in nd["shapes"]:
        if sh["fill"] == old:
            sh["fill"] = new
    for c in nd["pre"] + nd["post"]:
        recolor(c, old, new)


# ------------------------------------------------------------------ la sirena
def mermaid(rig):
    """Cambia las piernas por una cola con aleta; los brazos, sin mangas."""
    root = rig["root"]
    tail = [S("M-30,-104 C-38,-64 -22,-30 -7,-16 L7,-16 C22,-30 38,-64 30,-104 Z", "$tail"),
            shade("M12,-102 L30,-104 C38,-64 22,-30 7,-16 L2,-16 C16,-34 22,-70 12,-102 Z")]
    for y in (-88, -72, -56, -40):  # escamas
        for x in (-14, 0, 14):
            if abs(x) < 26 + (y + 16) * 0.2:
                tail.append(S(f"M{n(x - 6)},{y} Q{n(x)},{y + 6} {n(x + 6)},{y}", None, "$fin", 1.6))
    tail += [S("M-4,-20 C-28,-16 -46,-4 -42,4 C-26,-2 -12,-4 0,-10 C12,-4 26,-2 42,4 C46,-4 28,-16 4,-20 Z", "$fin"),
             shine("M-36,-2 C-26,-8 -14,-12 -4,-14 C-14,-8 -24,-4 -32,2 Z")]
    root["pre"] = [node("legL", (0, -100), shapes=tail), node("legR", (0, -100))]
    for arm in ("armL", "armR"):
        recolor(find(root, arm), "$primary", "$skin")
    return rig


# ------------------------------------------------------------------ el pulpo
def tentacle(x0, dx, y0=-100):
    """Un tentáculo que baja desde (x0, y0) y se enrosca hacia `dx` (±1), con ventosas."""
    s = dx
    path = (f"M{n(x0 - 10)},{y0} C{n(x0 - 12 + s * 4)},-60 {n(x0 + s * 22)},-30 {n(x0 + s * 36)},-14 "
            f"C{n(x0 + s * 44)},-6 {n(x0 + s * 38)},4 {n(x0 + s * 28)},-2 "
            f"C{n(x0 + s * 14)},-14 {n(x0 + 4)},-50 {n(x0 + 10)},{y0} Z")
    sh = [S(path, "$body")]
    for t, (yy, k) in enumerate([(-70, 0.15), (-46, 0.45), (-26, 0.8)]):
        sh.append(S(ell(x0 + s * 36 * k, yy, 3.4 - t * 0.6, 3 - t * 0.5), "$spots", None))
    return sh


def octopus(rig):
    root = rig["root"]
    head = find(root, "head")
    head["shapes"] = [S(ell(0, -184, 62, 66), "$body"),
                      shade("M0,-250 A62,66 0 0 1 0,-118 A34,66 0 0 0 0,-250 Z"),
                      S(ell(-34, -228, 9, 7), "$spots", None), S(ell(28, -236, 6, 5), "$spots", None),
                      S(ell(40, -212, 7, 6), "$spots", None), shine("M-40,-226 C-34,-240 -18,-248 -6,-248 C-20,-240 -30,-232 -34,-220 Z"),
                      S(ell(-30, -172, 8, 5), "#ff7a8a", None, 0, 0.45), S(ell(30, -172, 8, 5), "#ff7a8a", None, 0, 0.45)]
    torso = find(root, "torso")
    torso["shapes"] = [S(ell(0, -112, 46, 26), "$body")]
    torso["pre"] = []
    root["pre"] = [node("back", (0, -100), shapes=tentacle(-26, -1) + tentacle(26, 1) + tentacle(-8, -1) + tentacle(8, 1)),
                   node("legL", (-18, -100), shapes=tentacle(-18, -1, -96)),
                   node("legR", (18, -100), shapes=tentacle(18, 1, -96))]
    for side, sx in (("L", -1), ("R", 1)):  # los brazos: dos tentáculos que saludan
        x = 36 * sx
        find(root, "arm" + side)["shapes"] = [S(rrect(x - 11, -146, 22, 44, 11), "$body")]
        find(root, "foreArm" + side)["shapes"] = [
            S(f"M{n(x - 10)},-118 C{n(x - 10)},-104 {n(x + sx * 4)},-92 {n(x + sx * 14)},-88 "
              f"C{n(x + sx * 22)},-86 {n(x + sx * 20)},-96 {n(x + sx * 12)},-98 C{n(x + sx * 4)},-100 {n(x + 8)},-108 {n(x + 10)},-118 Z", "$body"),
            S(ell(x + sx * 2, -104, 3, 2.6), "$spots", None)]
    return rig


# ------------------------------------------------------------------ animales
def prop_rig(id_, name, viewbox, palette, root):
    return {"format": "caldero-rig", "version": 1, "id": id_, "name": name, "rig": "prop",
            "viewBox": viewbox, "bodyScale": 1.0, "rest": {}, "itemUpright": False, "itemTilt": 0,
            "palette": palette, "root": root}


PARROT = {"body": "#3fb24a", "belly": "#f4d35e", "wing": "#2f86d6", "wing2": "#e84a5f", "beak": "#f29a3a",
          "eye": "#ffffff", "dark": "#1b1230", "feet": "#8a8a96"}


def loro():
    """Pimienta, el loro: posado y mirando a la derecha. Huesos: wingL (detrás), wingR (delante), eyes y la cola
    dentro del cuerpo. Origen: bajo las patas."""
    tail = [S("M-10,-30 L-34,10 L-22,12 L-4,-22 Z", "$wing2"), S("M-2,-28 L-20,16 L-8,16 L6,-24 Z", "$wing")]
    body = [S("M-22,-30 C-28,-62 -16,-98 10,-104 C34,-108 46,-88 40,-70 C36,-50 26,-30 6,-22 C-6,-18 -18,-20 -22,-30 Z", "$body"),
            S("M-6,-30 C-10,-50 -4,-70 12,-74 C24,-60 22,-40 6,-24 Z", "$belly"),
            S("M30,-92 C46,-94 54,-84 50,-72 C46,-76 40,-78 36,-76 Z", "$beak"),
            S("M36,-76 C42,-74 46,-70 44,-66 C40,-68 36,-70 34,-72 Z", mix(PARROT["beak"], DARK, 0.3)),
            shade("M24,-104 C44,-100 46,-84 40,-70 C36,-50 26,-30 6,-22 C24,-44 30,-80 24,-104 Z")]
    feet = [S(rrect(-6, -24, 5, 24, 2), "$feet"), S(rrect(6, -24, 5, 24, 2), "$feet"),
            S(rrect(-10, -3, 26, 5, 2), "$feet")]
    eyes = node("eyes", (24, -88), shapes=[S(ell(24, -88, 7, 7), "$eye"), S(ell(26, -88, 3.4, 4), "$dark", None),
                                           S(ell(25, -90, 1.2, 1.2), "#ffffff", None)])
    wing_l = node("wingL", (0, -70), shapes=[S("M0,-74 C-24,-74 -38,-50 -30,-28 C-18,-40 -8,-54 0,-60 Z", mix(PARROT["wing"], DARK, 0.2))])
    wing_r = node("wingR", (4, -72), shapes=[S("M4,-76 C-18,-72 -26,-46 -16,-26 C-6,-34 6,-50 12,-64 Z", "$wing"),
                                             S("M-14,-30 C-10,-38 -4,-44 2,-48", None, "$wing2", 3)])
    root = node("root", (0, 0), pre=[node("tail", (-6, -26), shapes=tail), wing_l] + [node("feet", (0, 0), shapes=feet)],
                shapes=body, post=[wing_r, eyes])
    return prop_rig("loro", "Pimienta · loro", [-50, -120, 110, 140], PARROT, root)


TURTLE = {"shell": "#4a9a5a", "plate": "#8ac46a", "skin": "#9ac87a", "skin2": "#7aa85a", "eye": "#2a1c14", "cheek": "#ff9aa0"}


def tortuga():
    """Calma, la tortuga: de perfil mirando a la derecha. Huesos como la cabrita (legFN, legBN, legFF, legBF, tail,
    head, eyes) para usar sus gestos. Origen: bajo las patas."""
    def leg(id_, x, col):
        return node(id_, (x, -22), shapes=[S(rrect(x - 9, -26, 18, 26, 8), col)])

    legs = [leg("legBF", -26, "$skin2"), leg("legFF", 26, "$skin2"), leg("legBN", -36, "$skin"), leg("legFN", 36, "$skin")]
    tail = node("tail", (-56, -20), shapes=[S("M-52,-24 L-70,-16 L-52,-12 Z", "$skin")])
    eyes = node("eyes", (82, -46), shapes=[S(ell(82, -46, 4, 5), "$eye", None), S(ell(81, -48, 1.4, 1.4), "#ffffff", None)])
    head = node("head", (52, -28), shapes=[
        S("M44,-34 C50,-56 82,-62 92,-44 C96,-34 90,-24 78,-24 C66,-24 56,-22 46,-18 Z", "$skin"),
        S(ell(86, -36, 5, 3), "$cheek", None, 0, 0.6),
        S("M84,-30 Q90,-28 94,-32", None, "$eye", 1.8)], post=[eyes])
    shell = [S("M-58,-18 C-58,-64 -26,-86 2,-86 C30,-86 60,-64 60,-18 Z", "$shell"),
             S(poly([(-14, -70), (14, -70), (22, -46), (0, -34), (-22, -46)]), "$plate"),
             S(poly([(-46, -30), (-30, -52), (-22, -46), (-28, -24)]), "$plate"),
             S(poly([(46, -30), (30, -52), (22, -46), (28, -24)]), "$plate"),
             S(rrect(-62, -24, 124, 10, 5), mix(TURTLE["shell"], DARK, 0.2)),
             shine("M-40,-60 C-30,-74 -14,-80 0,-80 C-16,-74 -28,-66 -34,-52 Z")]
    root = node("root", (0, 0), pre=legs + [tail], shapes=shell, post=[head])
    return prop_rig("tortuga", "Calma · tortuga", [-80, -100, 184, 108], TURTLE, root)


# ------------------------------------------------------------------ reparto
def load_cast():
    """Personajes del pack y sus variantes: `<id>_miedo` (sin nada en las manos) para todos y `<id>_pijama` para los
    protagonistas."""
    base = json.loads((OUT / "specs" / "characters.json").read_text(encoding="utf-8"))["characters"]
    out = list(base)
    for c in base:
        v = {k: val for k, val in c.items() if k not in ("hold_r", "hold_l", "item_tilt")}
        v.update(id=f'{c["id"]}_miedo', name=f'{c["name"]} (con miedo)', variant_of=c["id"], rest={"armL": 9, "armR": -9})
        out.append(v)
    for c in base:
        if c["id"] in PIJAMA:
            v = {k: val for k, val in c.items() if k not in ("hat", "hold_r", "hold_l", "item_tilt", "rest")}
            v.update(id=f'{c["id"]}_pijama', name=f'{c["name"]} (en pijama)', outfit="tunic", brows="sleepy", mouth="smile",
                     variant_of=c["id"], palette={**c["palette"], **PIJAMA[c["id"]]})
            out.append(v)
    return out


def build(spec):
    rig = kit.build(spec)
    body = spec.get("body")
    if body == "mermaid":
        return mermaid(rig)
    if body == "octopus":
        return octopus(rig)
    return rig


# ------------------------------------------------------------------ hoja
def sheet(rigs):
    """Hoja de previsualización: todos en reposo y, debajo, algunos gestos (los de la app)."""
    clips = anim.load_clips("humanoid")
    props = anim.load_clips("props")
    by = {r["id"]: r for r in rigs}
    cw, ch, cols = 236, 330, 7
    main = [r for r in rigs if r.get("rig") == "humanoid" and "_" not in r["id"]] + \
           [by["nino_puerto"], by["nina_puerto"], by["loro"], by["tortuga"]]
    cells = [(r, "idle", 0.0) for r in main]
    cells += [(by["bruno"], "wave", 0.9), (by["vega"], "cheer", 0.6), (by["estela"], "point", 0.8),
              (by["nacar"], "walk", 0.2), (by["nacar"], "sit", 0.6), (by["remolino"], "wave", 0.9),
              (by["mostacho"], "surprised", 0.6), (by["bruno_miedo"], "scared", 0.06), (by["vega_pijama"], "yawn", 0.8),
              (by["loro"], "flutter", 0.1), (by["tortuga"], "goat_walk", 0.2), (by["remolino"], "laugh", 0.4)]
    rows = [cells[i:i + cols] for i in range(0, len(cells), cols)]
    W, H = cw * cols, ch * len(rows) + 10
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
             'font-family="Helvetica, Arial, sans-serif">',
             '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1f4a7a"/>'
             '<stop offset="1" stop-color="#0d1a34"/></linearGradient></defs>',
             f'<rect width="{W}" height="{H}" fill="url(#bg)"/>']
    for ri, row in enumerate(rows):
        for ci, (rig, pn, tt) in enumerate(row):
            ox, oy = ci * cw, ri * ch
            vb = rig["viewBox"]
            human = rig.get("rig") == "humanoid"
            k = (ch - 60) / vb[3] * (1 if human else 0.55)
            tx = ox + cw / 2
            ty = oy + ch - 40
            lib = clips if human else props
            pose = anim.sample_pose(rig, lib[pn], tt) if pn in lib else {}
            parts.append(f'<ellipse cx="{tx}" cy="{ty + 3}" rx="{62 * k + 10}" ry="7" fill="#000" opacity="0.35"/>')
            parts.append(f'<g transform="translate({tx} {ty}) scale({k})">{kit.svg_character(rig, pose)}</g>')
            label = rig["name"] if pn == "idle" else f'{rig["name"].split(" · ")[0]} — {pn}'
            parts.append(f'<text x="{tx}" y="{oy + ch - 12}" fill="#f2e3c6" font-size="13" text-anchor="middle">{label}</text>')
    parts.append("</svg>")
    return "".join(parts)


def main():
    (OUT / "rigs").mkdir(parents=True, exist_ok=True)
    (OUT / "preview").mkdir(parents=True, exist_ok=True)
    cast = load_cast()
    rigs = [build(c) for c in cast] + [loro(), tortuga()]
    for r in rigs:
        (OUT / "rigs" / f'{r["id"]}.json').write_text(json.dumps(r, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT / "preview" / "sheet.svg").write_text(sheet(rigs), encoding="utf-8")
    index_path = OUT / "index.json"
    old = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else {}
    index = {"format": "caldero-art-index", "version": 1, "pack": "mar", "rig": "humanoid",
             "rigs": [f"mar/rigs/{r['id']}.json" for r in rigs],
             # Las escenas y los lugares los añade el generador de fondos (fase 4); aquí se conservan
             "scenes": old.get("scenes", []), "clips": "clips/humanoid.json", "extraClips": ["clips/props.json"],
             "sizes": {**{c["id"]: c["size"] for c in cast if "size" in c}, "loro": 0.9, "tortuga": 1.1}}
    if "places" in old:
        index["places"] = old["places"]
    index_path.write_text(json.dumps(index, indent=1) + "\n", encoding="utf-8")
    for r in rigs:
        size = (OUT / "rigs" / f'{r["id"]}.json').stat().st_size
        print(f'{r["id"]:16s} {size / 1024:5.1f} KB')


if __name__ == "__main__":
    main()
