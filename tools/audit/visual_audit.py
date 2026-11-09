#!/usr/bin/env python3
"""Revisor visual de los cuentos: compara el texto de cada escena con su dibujo usando un modelo con visión.

Primero se dibujan las escenas con la herramienta de la app (mismo pintor que el teléfono):

    cd app && AUDIT_OUT=/tmp/auditoria flutter test test/audit_visual_manual_test.dart

y luego se revisan:

    pip install anthropic
    python3 tools/audit/visual_audit.py /tmp/auditoria            # todas
    python3 tools/audit/visual_audit.py /tmp/auditoria --limit 20 # para probar (y medir el coste)

Escribe `findings.jsonl` (una línea por escena revisada; se puede cortar y volver a lanzar: retoma donde iba) y
`revision.html` con las escenas con problemas primero. Las credenciales salen del entorno (ANTHROPIC_API_KEY o el
perfil de `ant auth login`); nunca se escriben en el código.

Es una ayuda para el revisor humano (el SuperAdmin): cada hallazgo se mira en la imagen antes de corregir el cuento.
"""
import argparse
import base64
import html
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import anthropic

MODEL = "claude-opus-5-5"

# Lista de comprobación fija (va en el system: se guarda en caché y sale más barata en cada escena).
SYSTEM = """Eres el revisor de coherencia entre texto e ilustración de una app de cuentos infantiles para dormir.
Cada escena es un dibujo 2D sencillo, hecho por código, con fondos, personajes y objetos. Tu trabajo: decir si lo que
cuenta el texto de ESTA escena es lo que se ve en ESTE dibujo, para que un niño que mira la pantalla mientras le leen
no vea contradicciones.

Comprueba, en este orden:
1. Objetos: cada objeto que el texto dice que alguien tiene, usa, enciende, mira o que está en la escena, ¿se ve? ¿es
   el mismo objeto (una linterna no es una vela; una capa no es un vestido)? ¿Hay en el dibujo una luz u objeto llamativo
   que el texto no menciona y que pueda confundir (p. ej. una vela encendida cuando el texto habla de una linterna)?
2. Personajes: ¿están los que el texto nombra en la escena? ¿Sobra alguien que el texto no menciona?
3. Acción y postura: ¿el personaje hace lo que dice el texto (acostado en la cama, de pie, quieto, riendo, tapándose la
   boca, saludando con la mano, escondido bajo la manta)? Si el texto dice que está quieto o paralizado, una pose de
   brazos en movimiento o de baile es un problema.
4. Ropa y accesorios: ¿la ropa encaja con el momento (pijama en la cama de noche; no una armadura con espada para ir a
   mirar una sombra en el cuarto)?
5. Lugar y hora: ¿el lugar y la luz (día/noche) son los del texto?
6. Encuadre: si el texto describe una escena completa (el cuarto, la cama, la ventana, el niño) y el dibujo es solo un
   primer plano de un objeto, es un problema.

No marques: el estilo del dibujo, la calidad artística, detalles que el texto no menciona y que no confunden, lo que el
texto cuenta como recuerdo o como algo que pasó en otro momento u otro lugar, lo que se dice entre comillas como
diálogo sobre otra cosa, ni sonidos. Sé concreto: cada problema dice qué dice el texto y qué se ve. Si todo cuadra,
devuelve la lista vacía. Escribe en español de Latinoamérica."""

SCHEMA = {
    "type": "object",
    "properties": {
        "problems": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ["objeto", "personaje", "accion", "ropa", "lugar_hora", "encuadre", "otro"]},
                    "severity": {"type": "string", "enum": ["alta", "media", "baja"]},
                    "text_says": {"type": "string"},
                    "image_shows": {"type": "string"},
                },
                "required": ["kind", "severity", "text_says", "image_shows"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["problems"],
    "additionalProperties": False,
}


def review(client, root: Path, rec: dict) -> dict:
    data = base64.standard_b64encode((root / rec["image"]).read_bytes()).decode("utf-8")
    context = (f"Cuento: «{rec['title']}» (escena {rec['scene']} de {rec['of']}). Protagonista: {rec.get('hero') or '—'}.\n"
               + (f"Escena anterior (solo como contexto): {rec['previous']}\n" if rec.get("previous") else "")
               + f"\nTEXTO DE ESTA ESCENA:\n{rec['text']}")
    response = client.beta.messages.create(
        model=MODEL,
        max_tokens=4000,
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
        cache_control={"type": "ephemeral"},
        system=SYSTEM,
        output_config={"effort": "medium", "format": {"type": "json_schema", "schema": SCHEMA}},
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": data}},
            {"type": "text", "text": context},
        ]}],
    )
    if response.stop_reason == "refusal":
        return {**rec, "status": "rechazada", "problems": []}
    text = next((b.text for b in response.content if b.type == "text"), "{}")
    problems = json.loads(text).get("problems", [])
    usage = response.usage
    return {**rec, "status": "ok", "problems": problems,
            "usage": {"in": usage.input_tokens, "out": usage.output_tokens,
                      "cache_read": getattr(usage, "cache_read_input_tokens", 0) or 0}}


def write_html(root: Path, results: list[dict]) -> Path:
    rank = {"alta": 0, "media": 1, "baja": 2}
    def worst(r):
        return min((rank.get(p["severity"], 3) for p in r["problems"]), default=9)
    results = sorted(results, key=lambda r: (worst(r), r["pack"], r["premise"], r["scene"]))
    flagged = sum(1 for r in results if r["problems"])
    out = ["<!doctype html><meta charset='utf-8'><title>Revisión visual</title><style>"
           "body{font-family:system-ui;background:#1b1438;color:#fff6e6;margin:24px}"
           ".card{display:flex;gap:16px;background:#2a1f5c;border-radius:12px;padding:12px;margin:12px 0}"
           ".card img{width:420px;border-radius:8px}.ok{opacity:.55}.p{margin:6px 0;padding:6px 8px;border-radius:6px;background:#3a2c7a}"
           ".alta{border-left:4px solid #ff7a6b}.media{border-left:4px solid #ffd36e}.baja{border-left:4px solid #8ee3c8}"
           ".id{opacity:.6;font-size:12px}</style>",
           f"<h1>Revisión visual</h1><p>{flagged} de {len(results)} escenas con algo que revisar.</p>"]
    for r in results:
        probs = "".join(
            f"<div class='p {html.escape(p['severity'])}'><b>{html.escape(p['kind'])} · {html.escape(p['severity'])}</b><br>"
            f"Texto: {html.escape(p['text_says'])}<br>Dibujo: {html.escape(p['image_shows'])}</div>" for p in r["problems"])
        out.append(f"<div class='card {'' if r['problems'] else 'ok'}'><img src='{html.escape(r['image'])}' loading='lazy'>"
                   f"<div><b>{html.escape(r['title'])}</b> · escena {r['scene']}/{r['of']}"
                   f"<div class='id'>{html.escape(r['pack'])}:{html.escape(r['premise'])} · {html.escape(r['fragment'])}"
                   f"{' · camino ' + ','.join(r['path']) if r['path'] else ''}</div>"
                   f"<p>{html.escape(r['text'])}</p>{probs or '<p>Sin problemas.</p>'}</div></div>")
    path = root / "revision.html"
    path.write_text("\n".join(out), encoding="utf-8")
    return path


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", type=Path, help="carpeta que escribió audit_visual_manual_test.dart (con scenes.jsonl)")
    ap.add_argument("--limit", type=int, default=0, help="revisar solo N escenas nuevas (para probar)")
    ap.add_argument("--workers", type=int, default=4)
    a = ap.parse_args()

    records = [json.loads(l) for l in (a.root / "scenes.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    done_path = a.root / "findings.jsonl"
    done = {}
    if done_path.exists():
        for l in done_path.read_text(encoding="utf-8").splitlines():
            if l.strip():
                r = json.loads(l)
                done[r["image"]] = r
    todo = [r for r in records if r["image"] not in done]
    if a.limit:
        todo = todo[: a.limit]
    print(f"{len(records)} escenas · {len(done)} ya revisadas · {len(todo)} por revisar", file=sys.stderr)

    client = anthropic.Anthropic()
    lock = threading.Lock()
    tokens = {"in": 0, "out": 0, "cache_read": 0}
    with done_path.open("a", encoding="utf-8") as f, ThreadPoolExecutor(max_workers=a.workers) as pool:
        futures = {pool.submit(review, client, a.root, r): r for r in todo}
        for n, fut in enumerate(as_completed(futures), 1):
            rec = futures[fut]
            try:
                res = fut.result()
            except anthropic.RateLimitError:
                print(f"límite de ritmo en {rec['image']}: vuelve a lanzar más tarde (retoma solo)", file=sys.stderr)
                continue
            except anthropic.APIStatusError as e:
                print(f"error {e.status_code} en {rec['image']}: {e.message}", file=sys.stderr)
                continue
            except anthropic.APIConnectionError:
                print(f"sin conexión en {rec['image']}", file=sys.stderr)
                continue
            with lock:
                f.write(json.dumps(res, ensure_ascii=False) + "\n")
                f.flush()
                done[res["image"]] = res
                for k in tokens:
                    tokens[k] += res.get("usage", {}).get(k, 0)
            if n % 10 == 0:
                print(f"  {n}/{len(todo)}", file=sys.stderr)
    # Coste aproximado con los precios de Claude Opus 5.5 ($4 entrada, $0,20 lectura de caché, $20 salida por millón)
    cost = (tokens["in"] * 4 + tokens["cache_read"] * 0.2 + tokens["out"] * 20) / 1e6
    print(f"tokens de esta pasada: {tokens} ≈ USD {cost:.2f}", file=sys.stderr)
    page = write_html(a.root, list(done.values()))
    flagged = sum(1 for r in done.values() if r["problems"])
    print(f"{flagged} escenas con algo que revisar → {page}")


if __name__ == "__main__":
    main()
