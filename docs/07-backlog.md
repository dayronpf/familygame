# 07 · Backlog de producto

Formato: `ID · Historia · Talla (S/M/L) · Prioridad (Must/Should/Could)`. Las historias L se parten antes de entrar a un sprint.
Los sprints 0–3 están detallados; el resto se refina cuando se acerca («Ahora / Siguiente / Después»).

## Épicas

| ID | Épica | Release |
|---|---|---|
| E1 | Fundamentos del proyecto (repo, CI, nombre, cuentas) | S0 |
| E2 | Motor de cuentos y modelo de contenido | 0.1 |
| E3 | Flujo editorial y producción de contenido | 0.1 → continuo |
| E4 | Lector y experiencia nocturna | 0.1–0.3 |
| E11 | **Backend, API y sincronización de packs** ([09](09-backend-y-panel-admin.md)) | 0.2 → 1.0 |
| E12 | **Panel de administración web** (contenido, publicación, ventas) | 0.2 → 1.0 |
| E5 | Narración (voz) | 0.3 |
| E13 | **Arte y pipeline visual** ([10](10-arte-y-estilo-visual.md)) | 0.2 → 0.4 |
| E6 | Escenas y animación | 0.4 |
| E7 | Modo holograma | 0.5 |
| E8 | Compras, suscripciones y freemium (cliente + servidor) | 1.0 |
| E9 | Cumplimiento legal, privacidad y publicación | 1.0 |
| E10 | Crecimiento: idiomas, personalización, packs nuevos, compositor | Post-1.0 |

## Sprint 0 · Fundamentos (objetivo: «tenemos plan, reglas y un caldero que funciona»)

| ID | Historia | Talla | Pri. | Estado |
|---|---|---|---|---|
| E1-01 | Visión, metodología y roadmap documentados | M | Must | ✅ |
| E1-02 | Reglas de contenido y derechos de autor | M | Must | ✅ |
| E2-S01 | **Spike:** prototipo del caldero y modelo de contenido | M | Must | ✅ |
| E1-03 | Elegir nombre definitivo y comprobar marca/dominio | S | Must | ☐ |
| E1-04 | Crear proyecto Flutter + estructura de carpetas | S | Must | ✅ |
| E1-05 | CI en GitHub Actions (lint + test + validar packs) | M | Must | ✅ escrito; pendiente de primera ejecución en GitHub |
| E1-06 | Crear cuentas de desarrollador (Google Play, Apple) | S | Should | ☐ |

## Sprint 1 · «El caldero en Dart» (objetivo: generar un cuento desde la app)

| ID | Historia | Criterios de aceptación | Talla | Estado |
|---|---|---|---|---|
| E2-01 | Como autor, quiero un **esquema JSON de pack** versionado para validar el contenido | Esquema publicado; el pack demo lo cumple; versión de esquema en el pack | S | ✅ `content/schema/pack.schema.json` + `tools/validate_schema.py`; rechaza packs rotos |
| E2-02 | Como app, quiero un **motor de cuentos en Dart** equivalente al prototipo | Misma semilla + pack ⇒ mismo cuento (determinista); pruebas | M | ✅ 24 pruebas (RNG contrastado con la implementación de referencia, 1000 semillas × 3 enseñanzas, cuento «golden»). *Cambio:* ya no se exige paridad con Python (otro generador aleatorio); se exige determinismo propio. |
| E2-03 | Como equipo, quiero el **validador de packs** en CI | Falla en token inexistente, frase mal cerrada, artículo mal capitalizado, contracción faltante y falta de cobertura | M | ✅ `dart run caldero_engine:validate_pack` |
| E1-07 | Como equipo, quiero el **libro de licencias de assets** | Plantilla creada y regla en la Definición de Terminado | S | ✅ `ASSETS_LICENSES.md` |
| E4-01 | Como adulto, quiero **elegir una enseñanza y generar un cuento** | Selector + «Crear cuento» + texto | M | ✅ 5 pruebas de widgets; recorrido verificado en un navegador (build web temporal) |

**Lo que aprendimos:** el validador encontró 2 errores reales de contracción en el pack («a el erizo», «consejos de el»)
que ya están corregidos y cubiertos por una prueba de regresión. **Pendiente de verificar:** compilación y ejecución en
Android/iOS reales (el entorno de desarrollo actual no tiene SDK de Android ni Xcode).

## Sprint 2 · «Un cuento que da gusto leer» (objetivo: lectura nocturna agradable)

| ID | Historia | Criterios de aceptación | Talla |
|---|---|---|---|
| E4-02 | Lector de **texto grande en modo noche** (tonos cálidos, bajo brillo) | Legible a 1 m; sin blancos puros; ajuste de tamaño | M |
| E4-03 | **Lectura compartida:** avanzar por escenas con toque/deslizar | Retroceder/avanzar; barra de progreso discreta | M |
| E4-04 | Guardar **historial y favoritos** localmente + repetir cuento por semilla | Se reabre el mismo cuento | M |
| E2-04 | Parámetros de generación: **edad, duración, nivel de susto** | Cambian la selección de fragmentos; pruebas | M |
| E3-01 | **Guía editorial** y plantilla de autor de fragmentos | Documento + 10 fragmentos de ejemplo revisados | S |

## Sprint 3 · «Hay muchos cuentos» (objetivo: pack semilla y primera prueba con familias)

| ID | Historia | Criterios de aceptación | Talla |
|---|---|---|---|
| E3-02 | **Pack semilla**: ~25 personajes, ~15 lugares, ~120 fragmentos, 6 enseñanzas | Pasa validador y revisión editorial | L (contenido) |
| E2-05 | **Personajes elegidos por el niño** (héroe y lugar) | Reparto respeta la elección | M |
| E2-06 | Casos de gramática: plurales y `article_override` | Pruebas con *los tres hermanos*, *el agua* | S |
| E4-05 | Build interno para testers (TestFlight / pista interna) | 5 testers instalan sin ayuda | S |
| UX-01 | **Prueba con 10 familias** (guion de observación y encuesta corta) | Resultados documentados; decisión de continuar/ajustar | M |
| E11-01 | **Contrato OpenAPI v1** (catálogo, descarga, instalaciones, entitlements) + servidor simulado | La app puede sincronizar contra el simulado; contrato revisado | M |
| E11-02 | **Spike S-07:** elegir tecnología de backend y de panel (coste, privacidad, operación) | Decisión escrita (ADR) con comparativa | S |

## Spikes planificados (resultados = decisión escrita)

| ID | Spike | Cuándo | Pregunta a responder |
|---|---|---|---|
| S-07 | Tecnología de backend y panel | S3 | ¿Supabase, Firebase o propio? ¿Panel en React o Flutter Web con el motor compilado a JS? |
| S-04 | Arte y animación | S5 | ¿Rive, Lottie o dibujo propio alcanzan 60 FPS y el estilo deseado con el presupuesto de [10 §4](10-arte-y-estilo-visual.md)? |
| S-02 | Voz | S6–S7 | ¿Qué voz (sistema / neuronal offline / nube) gusta a las familias y cumple licencias y peso? |
| S-06 | Compras y suscripciones | S8 | ¿Capa propia o servicio externo? ¿Cumple las reglas de la categoría infantil? |
| S-03 | Holograma | S9 | ¿Funciona en 3 teléfonos con una pirámide de 6–10 cm? ¿Cuánto cuesta dibujar 4 vistas? |

> La entrega de packs (antes S-05) deja de ser un spike: es el núcleo del release 0.2.

## Releases 0.2 – 1.0 (nivel épica; se detalla al acercarse)

- **0.2 Catálogo (E11, E12, E13):** backend v0 con versiones inmutables y manifiesto firmado; sincronización en la app (hash, firma, instalación atómica, starter embebido); panel v0 (CRUD, validación, vista previa, publicar); guía de estilo y spike de arte.
- **0.3 Voz (E5):** modo Escucha, Lectura compartida con voz, temporizador de sueño, sincronización texto-voz.
- **0.4 Vida (E6, E13):** motor de escenas, rigs modulares, kit del pack gratuito (~10 personajes, ~6 fondos), ambientes y efectos, sincronización por frase.
- **0.5 Holograma (E7):** vista de 4 orientaciones, calibración, wakelock, bloqueo táctil, plantilla PDF y guía de montaje.
- **1.0 (E8, E9, E11, E12):** entitlements y verificación de compras, webhooks, panel de ventas, roles y auditoría, puerta parental, pack «Bosque Encantado», privacidad, formularios de tiendas, revisión legal, prueba cerrada.

## Ideas para después (Could)

Cuento con el nombre del niño · segundo idioma · modo solo audio con pantalla apagada · sonidos para dormir ·
más tamaños de pirámide · logros suaves sin presión · compartir una semilla («el cuento de hoy») · modo cuentacuentos para abuelos a distancia (solo si se resuelve privacidad).
