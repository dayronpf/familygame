# 07 · Backlog de producto

Formato: `ID · Historia · Talla (S/M/L) · Prioridad (Must/Should/Could)`. Las historias L se parten antes de entrar a un sprint.
Los sprints 0–3 están detallados; el resto se refina cuando se acerca («Ahora / Siguiente / Después»).

## Épicas

| ID | Épica | Release |
|---|---|---|
| E1 | Fundamentos del proyecto (repo, CI, nombre, cuentas) | S0 |
| E2 | Motor de cuentos y modelo de contenido | 0.1 |
| E3 | Flujo editorial y producción de contenido | 0.1 → continuo |
| E4 | Lector y experiencia nocturna | 0.1–0.2 |
| E5 | Narración (voz) | 0.2 |
| E6 | Escenas y animación | 0.3 |
| E7 | Modo holograma | 0.4 |
| E8 | Packs, compras y freemium | 1.0 |
| E9 | Cumplimiento legal, privacidad y publicación | 1.0 |
| E10 | Crecimiento: idiomas, personalización, packs nuevos | Post-1.0 |

## Sprint 0 · Fundamentos (objetivo: «tenemos plan, reglas y un caldero que funciona»)

| ID | Historia | Talla | Pri. | Estado |
|---|---|---|---|---|
| E1-01 | Visión, metodología y roadmap documentados | M | Must | ✅ |
| E1-02 | Reglas de contenido y derechos de autor | M | Must | ✅ |
| E2-S01 | **Spike:** prototipo del caldero y modelo de contenido | M | Must | ✅ |
| E1-03 | Elegir nombre definitivo y comprobar marca/dominio | S | Must | ☐ |
| E1-04 | Crear proyecto Flutter + estructura de carpetas | S | Must | ☐ |
| E1-05 | CI en GitHub Actions (lint + test + validar packs) | M | Must | ☐ |
| E1-06 | Crear cuentas de desarrollador (Google Play, Apple) | S | Should | ☐ |

## Sprint 1 · «El caldero en Dart» (objetivo: generar un cuento desde la app)

| ID | Historia | Criterios de aceptación | Talla |
|---|---|---|---|
| E2-01 | Como autor, quiero un **esquema JSON de pack** versionado para validar el contenido | Esquema publicado; el pack demo lo cumple; versión de esquema en el pack | S |
| E2-02 | Como app, quiero un **motor de cuentos en Dart** equivalente al prototipo | Misma semilla + pack ⇒ mismo cuento que el prototipo (pruebas de paridad) | L→M+M |
| E2-03 | Como equipo, quiero el **validador de packs** en CI | Falla en token inexistente, frase mal cerrada, artículo mal capitalizado y falta de cobertura | M |
| E1-07 | Como equipo, quiero el **libro de licencias de assets** (`ASSETS_LICENSES.md`) | Plantilla creada y regla en la Definición de Terminado | S |
| E4-01 | Como adulto, quiero **elegir una enseñanza y generar un cuento** | Pantalla con selector y botón «Crear cuento» que muestra el texto | M |

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

## Spikes planificados (resultados = decisión escrita)

| ID | Spike | Cuándo | Pregunta a responder |
|---|---|---|---|
| S-02 | Voz | S3–S4 | ¿Qué voz (sistema / neuronal offline / nube) gusta a las familias y cumple licencias y peso? |
| S-03 | Holograma | S5–S6 | ¿Funciona en 3 teléfonos con una pirámide de 6–10 cm? ¿Qué diseño visual lo hace brillar? |
| S-04 | Animación | S5 | ¿Capas + Lottie/Rive alcanzan 60 FPS y el estilo deseado? |
| S-05 | Entrega de packs | S10 | ¿Descarga bajo demanda con hash/firma en ambas tiendas? |

## Release 0.2 – 1.0 (nivel épica; se detalla al acercarse)

- **E5:** modo Escucha, modo Lectura compartida con voz, temporizador de sueño, sincronización texto-voz.
- **E6:** motor de escenas, kit visual (10 personajes, 6 fondos), ambientes y efectos de sonido, sincronización por frase.
- **E7:** vista de 4 espejos, calibración, wakelock, bloqueo táctil, plantilla PDF y guía de montaje.
- **E8:** manifiesto de packs, descarga y caché, compras integradas, restaurar, puerta parental, pack «Bosque Encantado».
- **E9:** política de privacidad, formularios de tiendas, revisión legal, prueba cerrada, ficha de tienda.

## Ideas para después (Could)

Cuento con el nombre del niño · segundo idioma · modo solo audio con pantalla apagada · sonidos para dormir ·
más tamaños de pirámide · logros suaves sin presión · compartir una semilla («el cuento de hoy») · modo cuentacuentos para abuelos a distancia (solo si se resuelve privacidad).
