"""Contrato: el ejemplo que genera la app valida contra el esquema OpenAPI; lo indebido se rechaza.

La app (Dart) y este servidor comparten `docs/api/examples/rating-event.json`: una prueba de Dart exige
que el evento real de la app sea IDÉNTICO al ejemplo, y esta prueba exige que el ejemplo cumpla el contrato.
"""
import copy
import json
import unittest
from pathlib import Path

import yaml
from jsonschema import Draft7Validator, RefResolver

DOCS = Path(__file__).resolve().parent.parent.parent / "docs" / "api"
SPEC = yaml.safe_load((DOCS / "feedback.openapi.yaml").read_text(encoding="utf-8"))
EXAMPLE = json.loads((DOCS / "examples" / "rating-event.json").read_text(encoding="utf-8"))
WITH_REASONS = json.loads((DOCS / "examples" / "rating-event-with-reasons.json").read_text(encoding="utf-8"))
REASONS = ["no_sense", "repeated", "length", "scary", "moral"]


def validator(name):
    schema = {"$ref": f"#/components/schemas/{name}", "components": SPEC["components"]}
    return Draft7Validator(schema, resolver=RefResolver.from_schema(schema))


def errors(name, doc):
    return sorted(validator(name).iter_errors(doc), key=lambda e: list(e.path))


class ContractTests(unittest.TestCase):
    def test_la_especificacion_es_openapi_3(self):
        self.assertTrue(SPEC["openapi"].startswith("3."))
        self.assertIn("/v1/feedback", SPEC["paths"])

    def test_el_ejemplo_cumple_el_contrato(self):
        self.assertEqual(errors("RatingEvent", EXAMPLE), [])

    def test_el_ejemplo_con_motivos_cumple_el_contrato(self):
        self.assertEqual(errors("RatingEvent", WITH_REASONS), [])
        self.assertLessEqual(WITH_REASONS["rating"], 3, "los motivos solo existen con nota baja")

    def test_motivos_invalidos(self):
        cases = {
            "motivo inventado": ["aburrido"],
            "texto libre": ["no entendí nada de nada"],
            "repetidos": ["scary", "scary"],
            "vacío": [],
            "más de cinco": REASONS + ["no_sense"],
            "no es lista": "scary",
        }
        for name, value in cases.items():
            doc = copy.deepcopy(WITH_REASONS)
            doc["reasons"] = value
            self.assertTrue(errors("RatingEvent", doc), f"debería rechazar: {name}")

    def test_los_cinco_motivos_a_la_vez_son_validos(self):
        doc = copy.deepcopy(WITH_REASONS)
        doc["reasons"] = REASONS
        self.assertEqual(errors("RatingEvent", doc), [])

    def test_un_lote_de_ejemplos_cumple_el_contrato(self):
        self.assertEqual(errors("FeedbackBatch", {"events": [EXAMPLE] * 50}), [])

    def test_el_contrato_no_admite_datos_de_mas(self):
        """La privacidad es parte del contrato: ningún campo extra, ni arriba ni dentro de la receta."""
        for where, mutate in {
            "campo extra": lambda d: d.update(deviceId="abc"),
            "usuario": lambda d: d.update(user="ana"),
            "hora exacta": lambda d: d.update(at="2026-10-08T03:12:45Z"),
            "texto en la receta": lambda d: d["recipe"].update(text="Había una vez"),
            "nombre en la receta": lambda d: d["recipe"].update(heroName="Nilo"),
        }.items():
            doc = copy.deepcopy(EXAMPLE)
            mutate(doc)
            self.assertTrue(errors("RatingEvent", doc), f"debería rechazar: {where}")

    def test_rechaza_valores_invalidos(self):
        cases = {
            "nota 0": ("rating", 0), "nota 6": ("rating", 6), "nota decimal": ("rating", 4.5),
            "id no es uuid v4": ("id", "123"), "día con hora": ("day", "2026-10-08T03:00:00Z"),
            "versión rara": ("app", "v1"), "schema desconocido": ("schema", 2),
        }
        for name, (field, value) in cases.items():
            doc = copy.deepcopy(EXAMPLE)
            doc[field] = value
            self.assertTrue(errors("RatingEvent", doc), f"debería rechazar: {name}")

    def test_rechaza_recetas_invalidas(self):
        cases = {
            "sin fragmentos": ("fragments", []),
            "demasiados fragmentos": ("fragments", ["a"] * 21),
            "fragmento con espacios o mayúsculas": ("fragments", ["Había una vez"]),
            "semilla negativa": ("seed", -1),
            "reparto con nombre propio": ("cast", {"hero": "Nilo el erizo"}),
        }
        for name, (field, value) in cases.items():
            doc = copy.deepcopy(EXAMPLE)
            doc["recipe"][field] = value
            self.assertTrue(errors("RatingEvent", doc), f"debería rechazar: {name}")

    def test_faltan_campos_obligatorios(self):
        for field in ["id", "schema", "rating", "day", "app", "recipe"]:
            doc = copy.deepcopy(EXAMPLE)
            del doc[field]
            self.assertTrue(errors("RatingEvent", doc), f"debería exigir {field}")

    def test_lote_vacio_o_enorme(self):
        self.assertTrue(errors("FeedbackBatch", {"events": []}))
        self.assertTrue(errors("FeedbackBatch", {"events": [EXAMPLE] * 51}))


if __name__ == "__main__":
    unittest.main()
