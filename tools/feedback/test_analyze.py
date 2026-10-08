"""Pruebas del análisis con eventos sintéticos EN EL FORMATO REAL de la app."""
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

import analyze

STAGES = ["opening", "trouble", "helper", "test", "climax", "resolution", "closing"]
MORALS = ["honestidad", "generosidad", "valentia"]


def make_events(n, bad, seed=1, noise=0.9, pack_version="1.0.0", start=0):
    """n eventos con la forma que envía la app. `bad`: ids de fragmentos con efecto −1.0."""
    rng = np.random.default_rng(seed)
    out = []
    for i in range(n):
        m = MORALS[int(rng.integers(0, len(MORALS)))]
        frags = [f"{st}_{m[:3]}_{int(rng.integers(0, 4))}" for st in STAGES]
        latent = 4.2 - sum(1.0 for f in frags if f in bad)
        rating = int(np.clip(np.rint(latent + rng.normal(0, noise)), 1, 5))
        out.append({"id": f"e{start + i}", "schema": 1, "rating": rating, "day": "2026-10-08", "app": "0.1.0",
                    "recipe": {"packId": "demo", "packVersion": pack_version, "engine": "0.1.0", "seed": start + i,
                               "value": m, "cast": {"hero": "nilo"}, "fragments": frags}})
    return out


BAD = {"trouble_hon_2", "climax_gen_1", "helper_val_0"}


class AnalyzeTests(unittest.TestCase):
    def test_encuentra_los_fragmentos_malos_plantados(self):
        res = analyze.analyze(make_events(4000, BAD))
        self.assertEqual(set(res["flagged"]), BAD)

    def test_no_marca_nada_si_todo_es_bueno(self):
        res = analyze.analyze(make_events(4000, set(), seed=2))
        self.assertEqual(res["flagged"], [])

    def test_pocos_datos_no_acusan_a_nadie(self):
        res = analyze.analyze(make_events(40, BAD, seed=3))
        self.assertEqual(res["flagged"], [], "con 40 valoraciones no hay evidencia suficiente")
        res = analyze.analyze(make_events(5, BAD))
        self.assertIn("Muy pocas valoraciones", analyze.report(res))

    def test_quita_duplicados_y_notas_invalidas(self):
        ev = make_events(300, BAD)
        dup = ev + ev[:50]
        bad_rating = [dict(e, id=f"x{i}", rating=9) for i, e in enumerate(ev[:10])]
        malformed = [{"id": "m1"}, {"rating": 3}]
        res = analyze.analyze(dup + bad_rating + malformed)
        self.assertEqual(res["n"], 300)
        self.assertEqual(res["dropped"]["duplicado o nota inválida"], 60)
        self.assertEqual(res["dropped"]["malformado"], 2)

    def test_no_mezcla_versiones_del_pack(self):
        ev = make_events(1500, BAD, pack_version="1.0.0") + make_events(300, set(), seed=5, pack_version="1.1.0", start=5000)
        self.assertEqual(analyze.analyze(ev)["pack_version"], "1.0.0", "por defecto, la versión con más datos")
        res = analyze.analyze(ev, pack_version="1.1.0")
        self.assertEqual((res["pack_version"], res["n"]), ("1.1.0", 300))

    def test_filtra_por_pack(self):
        ev = make_events(200, BAD)
        other = [dict(e, id="o" + e["id"], recipe=dict(e["recipe"], packId="otro")) for e in ev]
        self.assertEqual(analyze.analyze(ev + other, pack="demo")["n"], 200)

    def test_efecto_de_la_ensenanza_no_se_atribuye_a_sus_fragmentos(self):
        """Una enseñanza que gusta menos NO debe hacer que se acuse a sus fragmentos específicos."""
        rng = np.random.default_rng(9)
        ev = []
        for i in range(4000):
            m = MORALS[int(rng.integers(0, 3))]
            frags = [f"{st}_{m[:3]}_{int(rng.integers(0, 4))}" for st in STAGES]
            latent = 4.4 - (0.6 if m == "valentia" else 0)
            ev.append({"id": f"v{i}", "rating": int(np.clip(np.rint(latent + rng.normal(0, 0.9)), 1, 5)),
                       "recipe": {"packId": "demo", "packVersion": "1", "value": m, "fragments": frags}})
        res = analyze.analyze(ev)
        self.assertEqual(res["flagged"], [])
        self.assertEqual(res["values"][0]["id"], "valentia")

    def test_los_motivos_separan_incoherencia_de_susto(self):
        """Dos fragmentos igual de malos por nota; los motivos dicen CUÁL es el problema de cada uno."""
        incoherent, scary = "trouble_hon_2", "climax_gen_1"
        rng = np.random.default_rng(21)
        ev = []
        for i in range(5000):
            m = MORALS[int(rng.integers(0, 3))]
            frags = [f"{st}_{m[:3]}_{int(rng.integers(0, 4))}" for st in STAGES]
            causes = [c for f, c in ((incoherent, "no_sense"), (scary, "scary")) if f in frags]
            rating = int(np.clip(np.rint(4.2 - len(causes) + rng.normal(0, 0.9)), 1, 5))
            e = {"id": f"r{i}", "rating": rating,
                 "recipe": {"packId": "demo", "packVersion": "1", "value": m, "fragments": frags}}
            if rating <= 3 and rng.random() < 0.5:  # solo contesta la mitad
                pool = causes if causes and rng.random() < 0.8 else list(analyze.REASONS)
                e["reasons"] = [str(rng.choice(pool))]
            ev.append(e)
        res = analyze.analyze(ev)
        self.assertEqual(set(res["flagged"]), {incoherent, scary}, "por nota se ven los dos")
        self.assertIn(incoherent, res["flagged_by_reason"]["no_sense"])
        self.assertNotIn(scary, res["flagged_by_reason"]["no_sense"])
        self.assertIn(scary, res["flagged_by_reason"]["scary"])
        self.assertNotIn(incoherent, res["flagged_by_reason"]["scary"])
        text = analyze.report(res)
        self.assertIn("No tuvo sentido", text)
        self.assertIn("prioridad de coherencia", text)

    def test_motivos_invalidos_se_ignoran_pero_la_nota_cuenta(self):
        ev = make_events(300, BAD)
        for e, reasons in zip(ev[:5], (["scary"], ["aburrido"], ["scary", "scary"], [], "scary")):
            e["rating"] = 5 if reasons == ["scary"] else 2
            e["reasons"] = reasons
        res = analyze.analyze(ev)
        self.assertEqual(res["n"], 300, "ninguna nota se descarta")
        self.assertEqual(res["dropped"]["motivos inválidos (ignorados)"], 5)
        self.assertEqual(res["reason_summary"]["by_reason"]["scary"], 0)

    def test_sin_motivos_el_informe_sigue_funcionando(self):
        res = analyze.analyze(make_events(1500, BAD))
        self.assertEqual(res["reason_summary"]["answered"], 0)
        self.assertTrue(all(v == [] for v in res["flagged_by_reason"].values()))
        self.assertIn("Fragmentos para REVISAR", analyze.report(res))

    def test_lee_jsonl_y_json_con_events(self):
        ev = make_events(60, BAD)
        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d) / "a.jsonl", Path(d) / "b.json"
            a.write_text("\n".join(json.dumps(e) for e in ev), encoding="utf-8")
            b.write_text(json.dumps({"events": ev}), encoding="utf-8")
            self.assertEqual(len(analyze.load_events(a)), 60)
            self.assertEqual(len(analyze.load_events(b)), 60)


if __name__ == "__main__":
    unittest.main()
