# Caldero de Cuentos (nombre provisional)

Aplicación móvil (Android e iOS) que **genera cuentos infantiles originales** a partir de un «caldero mágico»
de personajes, lugares, conflictos, desenlaces y enseñanzas. El cuento se **narra en voz alta**, se **anima**
mientras avanza y puede proyectarse como **holograma** con una pirámide transparente sobre la pantalla del teléfono.

> Rescatar el arte de leer cuentos por las noches, en familia, frente a la cultura del scroll infinito.

## Principios

1. **Primero la familia, no la pantalla.** La app acompaña la lectura; no sustituye a quien lee.
2. **Cada cuento deja una enseñanza** (un valor humano explícito).
3. **100 % contenido original o con licencia verificable.** Cero riesgo de derechos de autor.
4. **Seguro para niños:** sin anuncios, sin cuentas infantiles, sin rastreo.
5. **Crece sin parar:** el contenido vive en *packs* descargables (freemium).

## Documentación

| Documento | Para qué sirve |
|---|---|
| [docs/00-vision.md](docs/00-vision.md) | Visión del producto, público, objetivo y métrica principal |
| [docs/01-metodologia-agil.md](docs/01-metodologia-agil.md) | Cómo trabajamos: Scrum ligero, sprints, definición de «listo» y «terminado» |
| [docs/02-roadmap.md](docs/02-roadmap.md) | Hoja de ruta por versiones y sprints, con criterios de salida |
| [docs/03-arquitectura.md](docs/03-arquitectura.md) | Stack técnico, motor de cuentos, narración, animación y modo holograma |
| [docs/04-contenido-y-derechos.md](docs/04-contenido-y-derechos.md) | Estrategia para no infringir derechos de autor + privacidad infantil |
| [docs/05-modelo-freemium.md](docs/05-modelo-freemium.md) | Packs gratis y premium, precios y reglas de tiendas |
| [docs/06-modelo-de-contenido.md](docs/06-modelo-de-contenido.md) | Cómo se describe un personaje, lugar o fragmento; ejemplo real generado |
| [docs/07-backlog.md](docs/07-backlog.md) | Épicas e historias priorizadas; sprints 0–3 detallados |
| [docs/08-decisiones-y-riesgos.md](docs/08-decisiones-y-riesgos.md) | Decisiones tomadas (ADR), supuestos abiertos y riesgos |

## Prototipo del caldero mágico (spike S-01)

```bash
# Genera un cuento (semilla y enseñanza opcionales)
python3 tools/prototype/caldero.py --pack content/packs/demo --seed 3 --value honestidad

# Valida el pack: renderiza cada fragmento con todos los repartos posibles
python3 tools/prototype/caldero.py --pack content/packs/demo --lint
```

Es un prototipo en Python (sin dependencias) para validar el *modelo de contenido*. El motor definitivo
se implementará en Dart dentro de la app; el formato de los packs (`content/packs/*/pack.json`) es el contrato.

## Estado

**Sprint 0 — Fundamentos.** Visión, plan y prototipo del motor listos. Siguiente paso: ver
[docs/07-backlog.md](docs/07-backlog.md).
