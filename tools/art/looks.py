#!/usr/bin/env python3
"""«Luces» de los lugares: la misma escena a distintas horas del día (`time`) y en distintas estaciones
(`season`), generadas por código a partir del fondo base.

El cuento declara en cada escena `time` (dia, amanecer, atardecer, noche) y, si importa, `season`
(invierno, primavera, otono; sin estación = verano/normal). La app elige la escena `<lugar>__<time>` o
`<lugar>__<time>__<season>`. Así «por la mañana» no se dibuja con un atardecer y «la nevada» no se
dibuja con hierba y sol.

Cómo se obtiene cada variante:
  1. se sustituye la capa de cielo (degradado, sol o luna, nubes, estrellas) según la hora y la estación;
  2. se retoca el color del resto de capas (la hierba se vuelve nieve en invierno y oro en otoño; todo se
     oscurece de noche y se calienta al atardecer; las luces encendidas se respetan);
  3. en invierno se añade una capa de copos que titilan (las animaciones ambientales solo admiten
     opacidad y giro).
Los extras de forma (nieve sobre los tejados, el pozo) los dibuja cada fondo (ver scenes_story.py).
"""
import colorsys
import copy

from medieval_kit import S, ell, mix, n, node

TIMES = ["dia", "amanecer", "atardecer", "noche"]
SEASONS = ["invierno", "primavera", "otono"]

SKY = {
    "dia": [[0, "#3f86d6"], [0.55, "#86c4ee"], [1, "#d6f0ff"]],
    "amanecer": [[0, "#4a4f9a"], [0.4, "#e690a8"], [1, "#ffd9a0"]],
    "atardecer": [[0, "#3b2a7a"], [0.45, "#d96a8a"], [1, "#ffcf7a"]],
    "noche": [[0, "#0c0922"], [0.55, "#2b2063"], [1, "#5a4296"]],
}
# Cuánto se mezcla el cielo con gris (invierno) o con naranja (otoño)
SKY_SEASON = {"invierno": ("#cfd8e3", {"dia": 0.55, "amanecer": 0.4, "atardecer": 0.4, "noche": 0.3}),
              "otono": ("#f0a860", {"dia": 0.22, "amanecer": 0.2, "atardecer": 0.18, "noche": 0.1})}
# Multiplicador de color por hora para todo lo que no es cielo
TIME_MUL = {"dia": (1.0, 1.0, 1.0), "amanecer": (1.0, 0.92, 0.94), "atardecer": (1.0, 0.88, 0.8),
            "noche": (0.4, 0.44, 0.74)}
STARS = {"dia": 0, "amanecer": 5, "atardecer": 10, "noche": 30}


def lcg(seed):
    s = seed
    while True:
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        yield s / 0xFFFFFFFF


def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def _hex(r, g, b):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in (r, g, b))


def ambient(prop, values, dur=3.0, phase=0.0, ease="smooth"):
    return {"prop": prop, "values": values, "dur": dur, "phase": round(phase, 3), "ease": ease}


def key_of(time, season=None):
    return time if not season else f"{time}__{season}"


# ------------------------------------------------------------------ color
def tone(c, time, season):
    """Color de un fondo base (pensado para un día de verano) a la hora y estación dadas."""
    if not (isinstance(c, str) and c.startswith("#") and len(c) == 7):
        return c
    r, g, b = _rgb(c)
    h, light, s = colorsys.rgb_to_hls(r, g, b)
    deg = h * 360
    green = 70 <= deg <= 175 and s > 0.18
    purple = 245 <= deg <= 300 and s > 0.15
    tan = 25 <= deg <= 48 and 0.2 < s < 0.75 and light > 0.5
    lit = 35 <= deg <= 62 and s > 0.5 and light > 0.6  # ventanas y llamas: no se apagan
    if season == "invierno":
        if green:
            c = mix("#e9f1fa" if light > 0.35 else "#c9d8ea", c, 0.12)
        elif purple and light > 0.2:
            c = mix(c, "#dfe6f2", 0.6)
        elif tan:
            c = mix(c, "#f0f4f8", 0.6)
    elif season == "otono":
        if green:
            nh = 0.09 + 0.03 * (1 - light)
            c = _hex(*colorsys.hls_to_rgb(nh, min(0.5, light * 0.95), 0.55))
    elif season == "primavera":
        if green:
            c = _hex(*colorsys.hls_to_rgb(h, min(0.7, light * 1.1), min(1.0, s * 1.1)))
    if lit and time in ("noche", "atardecer", "amanecer"):
        return c
    mr, mg, mb = TIME_MUL[time]
    r, g, b = _rgb(c)
    return _hex(r * mr, g * mg, b * mb)


def _recolor_shape(sh, time, season):
    for k in ("fill", "stroke"):
        if sh.get(k):
            sh[k] = tone(sh[k], time, season)


def _recolor_node(nd, time, season):
    for sh in nd.get("shapes", []):
        _recolor_shape(sh, time, season)
    for c in nd.get("pre", []) + nd.get("post", []):
        _recolor_node(c, time, season)


def _swap_node(nd, swap):
    for sh in nd.get("shapes", []):
        for k in ("fill", "stroke"):
            if sh.get(k) in swap:
                sh[k] = swap[sh[k]]
    for c in nd.get("pre", []) + nd.get("post", []):
        _swap_node(c, swap)


# ------------------------------------------------------------------- cielo
def sky_stops(time, season):
    stops = SKY[time]
    if season in SKY_SEASON:
        target, amount = SKY_SEASON[season]
        stops = [[o, mix(c, target, amount[time])] for o, c in stops]
    return [[o, c, 1] for o, c in stops]


def sky_color_at(stops, f):
    """Color del cielo a la fracción f de la altura (interpolando los puntos del degradado)."""
    f = max(0.0, min(1.0, f))
    for (o0, c0, _), (o1, c1, _) in zip(stops, stops[1:]):
        if f <= o1:
            return mix(c0, c1, (f - o0) / (o1 - o0) if o1 > o0 else 0)
    return stops[-1][1]


def _crescent(cx, cy, big, small, d):
    """Luna creciente: el disco grande menos un disco menor desplazado `d` a la derecha."""
    x = (d * d + big * big - small * small) / (2 * d)
    y = (big * big - x * x) ** 0.5
    return (f"M{n(cx + x)},{n(cy - y)} A{n(big)},{n(big)} 0 1 0 {n(cx + x)},{n(cy + y)} "
            f"A{n(small)},{n(small)} 0 1 1 {n(cx + x)},{n(cy - y)} Z")


def _cloud(i, x, y, k, color, phase):
    sh = [S(ell(x, y, 54 * k, 20 * k), color, None, 0, 0.95),
          S(ell(x - 28 * k, y + 4, 32 * k, 15 * k), color, None, 0, 0.95),
          S(ell(x + 30 * k, y + 5, 34 * k, 15 * k), color, None, 0, 0.95)]
    nd = node(f"cloud{i}", (x, y), shapes=sh)
    nd["anim"] = [ambient("opacity", [0.75, 1.0, 0.75], 6.0, phase)]
    return nd


def sky_layer(time, season, w, h, sun_x, sun_y_day, horizon, moon_xy=None, seed=5):
    """Capa «sky» completa y los degradados que usa. `horizon` es la y de la línea de colinas."""
    grads = {"sky": {"type": "linear", "from": [0, 0], "to": [0, 1], "stops": sky_stops(time, season)},
             "sun": {"type": "radial", "stops": [[0, "#fff0b0", 0.95], [1, "#fff0b0", 0]]},
             "moon": {"type": "radial", "stops": [[0, "#fff3c4", 0.55], [1, "#fff3c4", 0]]}}
    shapes = [S(f"M0,0 L{w},0 L{w},{h} L0,{h} Z", "@sky", None, 0)]
    post = []
    r = lcg(seed)
    if time == "noche":
        mx, my = moon_xy or (sun_x, sun_y_day)
        shapes += [S(ell(mx, my, 96, 96), "@moon", None, 0), S(_crescent(mx, my, 40, 34, 15), "#fff3c4", None, 0)]
    elif season != "invierno":
        if time == "dia":
            sy, halo, disc, col = sun_y_day, 150, 34, "#fff3b0"
        else:
            sy, halo, disc, col = horizon, 190, 42, "#fff0b0" if time == "atardecer" else "#ffe4a8"
        shapes += [S(ell(sun_x, sy, halo, halo), "@sun", None, 0), S(ell(sun_x, sy, disc, disc), col, None, 0)]
    # estrellas
    for i in range(STARS[time] if season != "invierno" or time == "noche" else 0):
        x, y = round(next(r) * w, 1), round(next(r) * horizon * 0.8, 1)
        nd = node(f"st{i}", (x, y), shapes=[S(ell(x, y, 1.7, 1.7), "#fff6d8", None, 0)])
        nd["anim"] = [ambient("opacity", [0.25, 0.95, 0.25], 3.0, next(r) * 3)]
        post.append(nd)
    # nubes
    if time != "noche":
        if season == "invierno":
            grey = mix("#ffffff", "#aab6c4", 0.45 if time == "dia" else 0.6)
            for i, (x, y, k) in enumerate([(70, 50, 1.5), (230, 70, 1.4), (390, 46, 1.6), (560, 74, 1.4), (150, 120, 1.2),
                                           (470, 130, 1.3)]):
                post.append(_cloud(i, x * w / 640, y * h / 480 if h <= 480 else y, k, grey, next(r) * 6))
        else:
            tint = {"dia": "#ffffff", "amanecer": "#ffd0c8", "atardecer": "#ffb8a8"}[time]
            for i, (x, y, k) in enumerate([(110, 70, 1.0), (380, 110, 0.8), (540, 55, 0.9)]):
                post.append(_cloud(i, x * w / 640, y if h <= 480 else y * 1.2, k, tint, next(r) * 6))
    return {"id": "sky", "pivot": [0, 0], "pre": [], "shapes": shapes, "post": post}, grads


def snow_layer(w, h, count=34, seed=77):
    r = lcg(seed)
    flakes = []
    for i in range(count):
        x, y = round(next(r) * w, 1), round(next(r) * h * 0.95, 1)
        rad = round(1.8 + next(r) * 1.6, 1)
        nd = node(f"flake{i}", (x, y), shapes=[S(ell(x, y, rad, rad), "#ffffff", None, 0, 0.95)])
        nd["anim"] = [ambient("opacity", [0.1, 1.0, 0.1], 2.4 + next(r), next(r) * 3)]
        flakes.append(nd)
    return {"id": "snow", "pivot": [0, 0], "pre": [], "shapes": [], "post": flakes}


# ------------------------------------------------------------------- relook
def relook(base, time, season, w, h, sun_x, sun_y_day, horizon, moon_xy=None, seed=5, snowfall=True, swap=None):
    """Variante de una escena base: nuevo cielo, colores retocados y, en invierno, copos."""
    sc = copy.deepcopy(base)
    key = key_of(time, season)
    sc["id"] = f'{base["id"]}__{key}'
    sc["name"] = f'{base["name"]} ({time}{", " + season if season else ""})'
    sky, grads = sky_layer(time, season, w, h, sun_x, sun_y_day, horizon, moon_xy, seed)
    assert sc["layers"][0]["id"] == "sky"
    sc["layers"][0] = sky
    keep = {}
    for gid, g in sc["gradients"].items():
        if gid in ("sky", "sun", "moon", "moonhalo"):
            continue
        g = copy.deepcopy(g)
        g["stops"] = [[o, tone(c, time, season), a] for o, c, a in g["stops"]]
        keep[gid] = g
    sc["gradients"] = {**grads, **keep}
    for layer in sc["layers"][1:]:
        if swap and time != "noche":
            _swap_node(layer, swap)
        _recolor_node(layer, time, season)
    if season == "invierno" and snowfall:
        sc["layers"].append(snow_layer(w, h))
    return sc
