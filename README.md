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
| [docs/09-backend-y-panel-admin.md](docs/09-backend-y-panel-admin.md) | Backend, sincronización de packs, compras y panel de administración |
| [docs/10-arte-y-estilo-visual.md](docs/10-arte-y-estilo-visual.md) | Estilo visual, derechos de autor del arte, sistema modular y presupuesto de rendimiento |
| [docs/12-valoraciones-y-mejora-continua.md](docs/12-valoraciones-y-mejora-continua.md) | Valoración 1–5 al final de cada cuento (con motivo opcional si es baja): qué se envía, evidencia, análisis y cómo mejora los cuentos |
| [docs/13-auditoria-de-historias.md](docs/13-auditoria-de-historias.md) | Auditoría de coherencia de los cuentos generados (medida con `audit_stories`), causas y plan de arreglo |
| [docs/14-rubrica-editorial.md](docs/14-rubrica-editorial.md) | Rúbrica y ciclo de mejora de los cuentos (corpus → revisión independiente → corrección → medición) con el registro de vueltas |
| [docs/11-pipeline-de-arte-por-codigo.md](docs/11-pipeline-de-arte-por-codigo.md) | Arte generado por código (sin presupuesto ni herramientas de pago), pack medieval, 3D y límites |

## Estructura del repositorio

```
app/                      App Flutter (Android + iOS)
packages/caldero_engine/  Motor de cuentos en Dart puro (con pruebas y validador de packs)
packages/caldero_rig/     Rigs 2D, clips de animación y escenas (Dart puro, con pruebas)
content/packs/            Packs de contenido (fuente de verdad) y su esquema JSON
tools/                    Prototipo en Python, validador de esquema, sincronía de assets
tools/art/                Generadores de personajes y escenas (arte por código)
art/                      Arte como datos: personajes, clips, escenas y vistas previas (PNG/GIF/SVG)
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

# Rigs y animación
cd packages/caldero_rig && dart pub get && dart analyze && dart test

# App
cd app && flutter pub get && flutter analyze && flutter test
flutter run                      # en un dispositivo o emulador

# Si cambias un pack en content/ o el arte en art/, sincroniza la copia que lleva la app
tools/sync_assets.sh             # CI falla si lo olvidas (--check)

# Valoraciones: simulación, análisis y contrato (ver docs/12)
pip install numpy jsonschema pyyaml
cd tools/feedback && python3 simulate.py --quick && python3 simulate.py --reasons --quick && python3 -m unittest test_analyze test_contract
python3 analyze.py ratings.jsonl      # informe de fragmentos a revisar

# Arte generado por código (ver docs/11)
cd tools/art && python3 medieval_kit.py && python3 make_clips.py && python3 scene_castle.py && python3 scenes_story.py && python3 make_fixtures.py

# Esquema JSON de los packs (opcional, requiere: pip install jsonschema)
python3 tools/validate_schema.py content/packs/*/pack.json
```

El prototipo original en Python sigue disponible como referencia
(`python3 tools/prototype/caldero.py --pack content/packs/demo --seed 3 --value honestidad`).
**Ojo:** el motor Dart usa su propio generador aleatorio determinista (mulberry32), así que la misma
semilla da un cuento distinto en Python y en Dart; lo que ambos comparten es el *formato del pack*.

## Instalar la app de prueba en Android

Cada subida a la rama de trabajo compila un APK y lo publica **suelto** (sin zip) en la release fija `apk-latest`:
**https://github.com/dayronpf/familygame/releases/download/apk-latest/caldero-de-cuentos.apk** (siempre el más reciente).
También queda como artefacto en Actions (en zip).
Está firmado con una **llave de prueba fija y pública** (`app/android/app/caldero-debug.p12`), así que cada APK nuevo se instala
**encima** del anterior sin perder datos. Si Android dice «conflicto con un paquete», es que la versión instalada viene de una
compilación anterior con otra llave: **desinstálala una sola vez** y se acabó. Esta llave NO sirve para las tiendas.
(El identificador de la app es `com.calderodecuentos.cuentos`; el anterior `…caldero_app` se abandonó porque en un teléfono quedó
un registro escondido que bloqueaba toda instalación con «conflicto con un paquete».)

## Estado

**Sprint 1 — «El caldero en Dart»** ✅ y **arte por código** (pack medieval) en marcha: motor, validador, esquema, CI,
pantalla de cuentos, 6 personajes animados con 10 clips reutilizables, 5 lugares y **Taller de personajes** con medidor de fps.
**MVP de prueba:** el pack «Reino de la Luna» (`content/packs/medieval`: 6 personajes, 5 lugares, 3 enseñanzas, 3 premisas) se lee con **dibujos animados en cada escena del cuento** (sin música ni voz todavía). Tras la [auditoría](docs/13-auditoria-de-historias.md), los cuentos nacen de **premisas** con hilo (3 premisas, ≈ 6 min leídas, reglas de coherencia en CI) y se mejoran por vueltas de revisión ([14](docs/14-rubrica-editorial.md)).
**Valoración 1–5 al final de cada cuento** (lo único que se recoge, anónimo; [docs/12](docs/12-valoraciones-y-mejora-continua.md)) lista en la app; falta el servidor que la reciba.
Pendiente: probar en Android/iOS reales y medir rendimiento ([docs/11 §9](docs/11-pipeline-de-arte-por-codigo.md)). Ver [docs/07-backlog.md](docs/07-backlog.md).
