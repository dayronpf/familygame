#!/usr/bin/env python3
"""Kit de personajes del pack «Aldea de las Nubes» (docs/27).

Mismo kit procedural que el medieval y el mar (`medieval_kit.build` y las piezas del espacio: casco de burbuja, traje
espacial, chistera). Dos personajes cambian el cuerpo sin cambiar de esqueleto, para que les sirvan todos los gestos:

* **Tornillo, el robot** (`body: robot`): cabeza cuadrada con antena y ojos de pantalla, cuerpo de caja con una pantalla
  en el pecho, brazos y piernas de tubo.
* **Zumbo, el alien** (`body: alien`): cabeza redonda y verde con tres ojos y dos antenas.

**Chispa**, el perrito astronauta, es un objeto animado con los huesos de la cabrita (usa sus gestos `goat_*`).

Uso:
    python3 tools/art/cosmos_kit.py            # escribe art/cosmos/ (rigs, índice y hoja de personajes)
"""
import json
from pathlib import Path

import anim
import medieval_kit as kit
from mar_kit import find, prop_rig, recolor
from medieval_kit import DARK, S, ell, mix, n, node, poly, rrect, shade, shine, star

OUT = Path(__file__).resolve().parent.parent.parent / "art" / "cosmos"

PIJAMA = {"orion": {"primary": "#9ab8f0", "secondary": "#ffffff", "pants": "#9ab8f0", "boots": "#c9a06a"},
          "lira": {"primary": "#f0a8c8", "secondary": "#ffffff", "pants": "#f0a8c8", "boots": "#c9a06a"}}


# ------------------------------------------------------------------ el robot
def robot(rig):
    root = rig["root"]
    head = find(root, "head")
    head["shapes"] = [S(rrect(-46, -238, 92, 84, 18), "$skin"), shade(rrect(18, -236, 26, 80, 12)),
                      S(rrect(-36, -224, 72, 48, 10), "$screen"),
                      S("M0,-238 L0,-262", None, "$metal", 4), S(ell(0, -268, 7, 7), "$glow"),
                      S(ell(-50, -196, 6, 12), "$metal"), S(ell(50, -196, 6, 12), "$metal"),
                      S(ell(-24, -168, 6, 3.5), "#ff9aa8", None, 0, 0.6), S(ell(24, -168, 6, 3.5), "#ff9aa8", None, 0, 0.6)]
    # ojos de pantalla (siguen siendo el hueso `eyes`, así parpadean)
    find(root, "eyes")["shapes"] = [S(rrect(-24, -210, 14, 20, 6), "$glow", None), S(rrect(10, -210, 14, 20, 6), "$glow", None)]
    find(root, "mouth")["shapes"] = [S("M-12,-184 Q0,-176 12,-184", None, "$glow", 3.2)]
    for b in ("browL", "browR"):
        for sh in find(root, b)["shapes"]:
            sh["stroke"] = "$glow"
    torso = find(root, "torso")
    torso["shapes"] = [S(rrect(-40, -150, 80, 84, 14), "$primary"), shade(rrect(14, -148, 24, 80, 10)),
                       S(rrect(-24, -136, 48, 34, 6), "$screen"),
                       S("M-16,-118 L-8,-126 L0,-114 L8,-128 L16,-118", None, "$glow", 2.6),
                       S(ell(-14, -88, 4, 4), "$gold"), S(ell(0, -88, 4, 4), "#ff6a6a"), S(ell(14, -88, 4, 4), "$glow")]
    for side, sx in (("L", -1), ("R", 1)):
        x = 36 * sx
        find(root, "arm" + side)["shapes"] = [S(rrect(x - 9, -148, 18, 40, 9), "$metal"), S(ell(x, -144, 12, 10), "$secondary")]
        find(root, "foreArm" + side)["shapes"] = [S(rrect(x - 8.5, -120, 17, 28, 8.5), "$metal"),
                                                 S(f"M{n(x - 10)},-96 L{n(x - 10)},-84 M{n(x + 10)},-96 L{n(x + 10)},-84", None, "$secondary", 5)]
    for leg, cx in (("legL", -14), ("legR", 14)):
        find(root, leg)["shapes"] = [S(rrect(cx - 10, -82, 20, 60, 8), "$metal"),
                                     S(rrect(cx - 15, -26, 30, 26, 8), "$secondary"), shine(rrect(cx - 11, -22, 6, 10, 3))]
    return rig


# ------------------------------------------------------------------ el alien
def alien(rig):
    root = rig["root"]
    head = find(root, "head")
    head["shapes"] = [S("M-20,-238 C-34,-268 -40,-280 -30,-288", None, "$spots", 4), S(ell(-30, -290, 7, 7), "$secondary"),
                      S("M20,-238 C34,-268 40,-280 30,-288", None, "$spots", 4), S(ell(30, -290, 7, 7), "$secondary"),
                      S(ell(0, -196, 52, 48), "$skin"), shade("M0,-244 A52,48 0 0 1 0,-148 A28,48 0 0 0 0,-244 Z"),
                      S(ell(-30, -178, 7, 4.5), "#ff9aa8", None, 0, 0.55), S(ell(30, -178, 7, 4.5), "#ff9aa8", None, 0, 0.55),
                      S(ell(-22, -222, 6, 4), "$spots", None), S(ell(26, -228, 4, 3), "$spots", None)]
    eyes = find(root, "eyes")
    eyes["shapes"] = [S(ell(x, y, 12, 13), "#ffffff", DARK, 2.4) for x, y in ((-22, -190), (22, -190), (0, -216))] + \
                     [S(ell(x + 1, y + 2, 5.5, 6.5), DARK, None) for x, y in ((-22, -190), (22, -190), (0, -216))] + \
                     [S(ell(x - 1, y - 2, 2, 2), "#ffffff", None) for x, y in ((-22, -190), (22, -190), (0, -216))]
    eyes["pivot"] = [0, -200]
    return rig


# ------------------------------------------------------------------ el perrito astronauta
DOG = {"fur": "#e8c48a", "fur2": "#c89a5a", "ear": "#8a5a2a", "eye": "#2a1c14", "nose": "#2a1c14", "suit": "#f0f2f8",
       "glass": "#d8f4ff", "tag": "#f4c542"}


def chispa():
    """Chispa: perrito de perfil mirando a la derecha, con traje y casco de burbuja. Huesos de la cabrita."""
    def leg(id_, x, col):
        return node(id_, (x, -40), shapes=[S(rrect(x - 7, -44, 14, 40, 6), col), S(rrect(x - 9, -8, 18, 8, 4), "$ear")])

    legs = [leg("legBF", -22, "$fur2"), leg("legFF", 26, "$fur2"), leg("legBN", -32, "$suit"), leg("legFN", 36, "$suit")]
    tail = node("tail", (-48, -60), shapes=[S("M-46,-62 C-64,-80 -70,-96 -60,-100 C-56,-88 -50,-78 -42,-70 Z", "$fur")])
    eyes = node("eyes", (78, -102), shapes=[S(ell(78, -102, 4.2, 5), "$eye", None), S(ell(77, -104, 1.4, 1.4), "#ffffff", None)])
    head = node("head", (48, -84), shapes=[
        S("M40,-96 C42,-124 80,-128 92,-104 C98,-92 92,-82 80,-82 C68,-82 52,-80 42,-84 Z", "$fur"),
        S(ell(94, -96, 5.5, 4.5), "$nose", None),
        S("M52,-112 C40,-126 34,-108 40,-92 C46,-100 50,-106 52,-112 Z", "$ear"),
        S(ell(70, -100, 40, 38), "$glass", "#9ac0d8", 2.5, 0.25),
        shine("M44,-118 C50,-130 64,-136 76,-136 C64,-130 54,-122 50,-110 Z")], post=[eyes])
    body = [S("M-48,-48 C-50,-72 -30,-82 0,-82 C24,-82 46,-80 52,-66 C58,-52 48,-38 20,-38 C-14,-38 -46,-36 -48,-48 Z", "$suit"),
            shade("M10,-82 C34,-82 46,-80 52,-66 C58,-52 48,-38 20,-38 C30,-50 30,-70 10,-82 Z"),
            S(rrect(-16, -78, 32, 14, 5), "$fur2"), S(star(0, -71, 5, 2.2), "$tag", None)]
    root = node("root", (0, 0), pre=legs + [tail], shapes=body, post=[head])
    return prop_rig("chispa", "Chispa · perrito astronauta", [-80, -140, 184, 144], DOG, root)


# ------------------------------------------------------------------ reparto
def load_cast():
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
    return {"robot": robot, "alien": alien}.get(spec.get("body"), lambda r: r)(rig)


def sheet(rigs):
    clips, props = anim.load_clips("humanoid"), anim.load_clips("props")
    by = {r["id"]: r for r in rigs}
    cw, ch, cols = 236, 330, 7
    main = [r for r in rigs if r.get("rig") == "humanoid" and "_" not in r["id"]] + [by["chispa"]]
    cells = [(r, "idle", 0.0) for r in main]
    cells += [(by["orion"], "wave", 0.9), (by["lira"], "cheer", 0.6), (by["tornillo"], "talk", 0.5), (by["zumbo"], "laugh", 0.4),
              (by["brillo"], "surprised", 0.6), (by["lira_miedo"], "scared", 0.06), (by["orion_pijama"], "yawn", 0.8),
              (by["chispa"], "goat_hop", 0.4)]
    for k in [x for x in ("telescopio", "estrella_caida", "cohete_juguete", "casco", "mapa_estelar", "piedra_lunar", "flor_cristal",
                          "llave_inglesa", "globo", "semilla_luz") if x in by]:
        cells.append((by[k], "shimmer" if k in ("estrella_caida", "flor_cristal", "semilla_luz") else "idle", 0.3))
    rows = [cells[i:i + cols] for i in range(0, len(cells), cols)]
    W, H = cw * cols, ch * len(rows) + 10
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
             'font-family="Helvetica, Arial, sans-serif">',
             '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a2a7a"/>'
             '<stop offset="1" stop-color="#120c2c"/></linearGradient></defs>', f'<rect width="{W}" height="{H}" fill="url(#bg)"/>']
    for ri, row in enumerate(rows):
        for ci, (rig, pn, tt) in enumerate(row):
            ox, oy = ci * cw, ri * ch
            human = rig.get("rig") == "humanoid"
            k = (ch - 60) / rig["viewBox"][3] * (1 if human else 0.55)
            tx, ty = ox + cw / 2, oy + ch - 40
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
    rigs = [build(c) for c in cast] + [chispa()]
    try:
        import cosmos_props
        rigs += cosmos_props.build_all()
    except ImportError:
        pass
    for r in rigs:
        (OUT / "rigs" / f'{r["id"]}.json').write_text(json.dumps(r, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT / "preview" / "sheet.svg").write_text(sheet(rigs), encoding="utf-8")
    index_path = OUT / "index.json"
    old = json.loads(index_path.read_text(encoding="utf-8")) if index_path.exists() else {}
    index = {"format": "caldero-art-index", "version": 1, "pack": "cosmos", "rig": "humanoid",
             "rigs": [f"cosmos/rigs/{r['id']}.json" for r in rigs],
             "scenes": old.get("scenes", []), "clips": "clips/humanoid.json", "extraClips": ["clips/props.json"],
             "sizes": {**{c["id"]: c["size"] for c in cast if "size" in c}, "chispa": 1.0}}
    if "places" in old:
        index["places"] = old["places"]
    index_path.write_text(json.dumps(index, indent=1) + "\n", encoding="utf-8")
    size = sum((OUT / "rigs" / f'{r["id"]}.json').stat().st_size for r in rigs)
    print(f"{len(rigs)} dibujos, {size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
