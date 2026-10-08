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

## Estructura del repositorio

```
app/                      App Flutter (Android + iOS)
packages/caldero_engine/  Motor de cuentos en Dart puro (con pruebas y validador de packs)
content/packs/            Packs de contenido (fuente de verdad) y su esquema JSON
tools/                    Prototipo en Python, validador de esquema, sincronía de assets
docs/                     Visión, metodología, roadmap, arquitectura, backlog…
ASSETS_LICENSES.md        Libro de licencias de todo asset de terceros
```

## Cómo trabajar

Requisitos: Flutter 3.47.x (incluye Dart) y Python 3.

```bash
# Motor: análisis, pruebas y validación de packs
cd packages/caldero_engine
dart pub get && dart analyze && dart test
dart run caldero_engine:validate_pack ../../content/packs/*/pack.json

# App
cd app && flutter pub get && flutter analyze && flutter test
flutter run                      # en un dispositivo o emulador

# Si cambias un pack en content/, sincroniza la copia que lleva la app
tools/sync_assets.sh             # CI falla si lo olvidas (--check)

# Esquema JSON de los packs (opcional, requiere: pip install jsonschema)
python3 tools/validate_schema.py content/packs/*/pack.json
```

El prototipo original en Python sigue disponible como referencia
(`python3 tools/prototype/caldero.py --pack content/packs/demo --seed 3 --value honestidad`).
**Ojo:** el motor Dart usa su propio generador aleatorio determinista (mulberry32), así que la misma
semilla da un cuento distinto en Python y en Dart; lo que ambos comparten es el *formato del pack*.

## Estado

**Sprint 1 — «El caldero en Dart».** Motor en Dart, validador, esquema, CI y primera pantalla
(elegir enseñanza → crear cuento → leer en modo noche) listos y probados.
Falta verificarlos en dispositivos Android/iOS y en el CI de GitHub. Ver [docs/07-backlog.md](docs/07-backlog.md).
