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
| [docs/15-modo-cine-y-holograma.md](docs/15-modo-cine-y-holograma.md) | Modo cine y modo holograma (voz en off, fondo, geometría del prisma) |
| [docs/16-coherencia-texto-imagen.md](docs/16-coherencia-texto-imagen.md) | Lo que se lee es lo que se ve: hora, estación, primeros planos, reglas del validador y revisión con imágenes |
| [docs/17-interfaz-para-ninos.md](docs/17-interfaz-para-ninos.md) | Interfaz para niños: splash, inicio, paquetes (los que llegarán, en gris), Mis cuentos, compartir y temporizador para dormir |
| [docs/18-voz-edades-y-wizard.md](docs/18-voz-edades-y-wizard.md) | Voz (bug de adelantar, `texto_voz`), perfiles de edad, wizard de primer uso y Ajustes; lo diferido y por qué |
| [docs/19-nombres-y-dominios.md](docs/19-nombres-y-dominios.md) | Nombres posibles del juego con su disponibilidad de dominio (.com, .app, .net, .org) y lo que falta comprobar (marca, tiendas) |
| [docs/20-caminos-elegibles.md](docs/20-caminos-elegibles.md) | Valoración, diseño técnico y estado de «el niño decide»: una pregunta por cuento, tres ramas que vuelven al mismo desenlace, plan por fases y riesgos (sueño, privacidad). Fase 0 construida en v0.6.0 |
| [docs/11-pipeline-de-arte-por-codigo.md](docs/11-pipeline-de-arte-por-codigo.md) | Arte generado por código (sin presupuesto ni herramientas de pago), pack medieval, 3D y límites |

## Estructura del repositorio

```
app/                      App Flutter (Android + iOS)
packages/caldero_engine/  Motor de cuentos en Dart puro (con pruebas y validador de packs)
packages/caldero_rig/     Rigs 2D, clips de animación y escenas (Dart puro, con pruebas)
content/packs/            Packs de contenido (fuente de verdad) y su esquema JSON
tools/                    Prototipo en Python, validador de esquema, sincronía de assets
tools/art/                Generadores de personajes y escenas (arte por código)
tools/rename_app.py       Cambia el nombre del juego en todos los sitios que lo escriben a mano (cuando se elija el definitivo)
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

**Qué hay (11 de octubre de 2026).** Una app Flutter (Android; iOS sin probar) que cuenta cuentos originales de dormir, generados por
un motor determinista a partir de **premisas** con hilo y una enseñanza, con **dibujos animados por código** en cada escena, **voz** del
teléfono, sonido de fondo y un **modo holograma** (prisma sobre la pantalla; guía PDF «Holograma en casa»).

* **Contenido:** el pack gratuito «Reino de la Luna» (`content/packs/medieval`): 15 cuentos (3 para 2–3 años, 6 para 4–5, 6 para 6–8),
  15 personajes, 8 lugares y 3 enseñanzas, con las reglas de coherencia texto↔imagen, de edad y de vocabulario en CI.
* **Para la familia:** asistente de primer uso, **el nombre del niño como protagonista**, **varios niños** con su propio estante,
  modos cine, holograma, **solo audio** y **«Leemos juntos»**, **temporizador de sueño con bajada gradual** de volumen y brillo,
  «Mis cuentos», compartir y valoración anónima 1–5 (lo único que se recoge; [docs/12](docs/12-valoraciones-y-mejora-continua.md)).
* **Arte:** personajes con cara animable y brazos con codo ([docs/16](docs/16-coherencia-texto-imagen.md)), generados por código y
  reproducibles en CI.

**Lo que falta:** probar en teléfonos reales y con familias; elegir el nombre definitivo (se cambia en un solo sitio con
`tools/rename_app.py`); más contenido; el servidor de catálogo y las compras; y más caminos elegibles ([docs/20](docs/20-caminos-elegibles.md): hay una primera pregunta al niño en «La linterna apagada»; falta
probarla de noche con familias). El estado historia por historia está en [docs/07-backlog.md](docs/07-backlog.md) y la hoja de ruta en [docs/02-roadmap.md](docs/02-roadmap.md).
