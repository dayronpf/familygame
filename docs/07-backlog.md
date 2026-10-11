# 07 · Backlog de producto

Formato: `ID · Historia · Talla (S/M/L) · Prioridad (Must/Should/Could)`. Las historias L se parten antes de entrar a un sprint.
Los sprints 0–3 están detallados; el resto se refina cuando se acerca («Ahora / Siguiente / Después»).

> **Estado a 11 de octubre de 2026.** El cliente (app, motor, voz, arte, modos de contar) va muy por delante de lo previsto; el
> servidor y las compras no se han empezado. Las tablas de abajo dicen qué está hecho (✅), a medias (🟡) o sin empezar (☐); lo
> que falta de verdad está al final, en **Lo que falta** (la hoja de ruta por releases está en [02](02-roadmap.md)).

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
| E14 | **Valoraciones y mejora continua** ([12](12-valoraciones-y-mejora-continua.md)) | 0.1 → continuo |
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
| E1-03 | Elegir nombre definitivo y comprobar marca/dominio | S | Must | 🟡 candidatos y dominios en [19](19-nombres-y-dominios.md); el nombre vive en un solo sitio (`app/lib/src/brand.dart`) y se cambia con `tools/rename_app.py`; **falta elegirlo** y comprobar marca |
| E1-04 | Crear proyecto Flutter + estructura de carpetas | S | Must | ✅ |
| E1-05 | CI en GitHub Actions (lint + test + validar packs) | M | Must | ✅ en cada subida: formato, análisis, pruebas del motor, los rigs y la app, validación de packs, arte reproducible, esquema y APK de prueba |
| E1-06 | Crear cuentas de desarrollador (Google Play, Apple) | S | Should | ☐ |

## Sprint 1 · «El caldero en Dart» (objetivo: generar un cuento desde la app)

| ID | Historia | Criterios de aceptación | Talla | Estado |
|---|---|---|---|---|
| E2-01 | Como autor, quiero un **esquema JSON de pack** versionado para validar el contenido | Esquema publicado; el pack demo lo cumple; versión de esquema en el pack | S | ✅ `content/schema/pack.schema.json` + `tools/validate_schema.py`; rechaza packs rotos |
| E2-02 | Como app, quiero un **motor de cuentos en Dart** equivalente al prototipo | Misma semilla + pack ⇒ mismo cuento (determinista); pruebas | M | ✅ 24 pruebas (RNG contrastado con la implementación de referencia, 1000 semillas × 3 enseñanzas, cuento «golden»). *Cambio:* ya no se exige paridad con Python (otro generador aleatorio); se exige determinismo propio. |
| E2-03 | Como equipo, quiero el **validador de packs** en CI | Falla en token inexistente, frase mal cerrada, artículo mal capitalizado, contracción faltante y falta de cobertura | M | ✅ `dart run caldero_engine:validate_pack` |
| E2-07 | **Motor de premisas** (esquema 2) y reglas de coherencia en el validador | Presentaciones, viajes contados, causas, longitud; pruebas negativas | L | ✅ ver [13](13-auditoria-de-historias.md) y ADR-018 |
| E1-07 | Como equipo, quiero el **libro de licencias de assets** | Plantilla creada y regla en la Definición de Terminado | S | ✅ `ASSETS_LICENSES.md` |
| E4-01 | Como adulto, quiero **elegir una enseñanza y generar un cuento** | Selector + «Crear cuento» + texto | M | ✅ 5 pruebas de widgets; recorrido verificado en un navegador (build web temporal) |

**Lo que aprendimos:** el validador encontró 2 errores reales de contracción en el pack («a el erizo», «consejos de el»)
que ya están corregidos y cubiertos por una prueba de regresión. **Pendiente de verificar:** compilación y ejecución en
Android/iOS reales (el entorno de desarrollo actual no tiene SDK de Android ni Xcode).

## Sprint 2 · «Un cuento que da gusto leer» (objetivo: lectura nocturna agradable)

| ID | Historia | Criterios de aceptación | Talla | Estado |
|---|---|---|---|---|
| E4-02 | Lector de **texto grande en modo noche** (tonos cálidos, bajo brillo) | Legible a 1 m; sin blancos puros; ajuste de tamaño | M | ✅ paleta de noche sin blanco puro; «Leemos juntos» con letra ajustable (20–42) |
| E4-03 | **Lectura compartida:** avanzar por escenas con toque/deslizar | Retroceder/avanzar; barra de progreso discreta | M | ✅ «Leemos juntos» ([17](17-interfaz-para-ninos.md)), también con turnos con la voz |
| E4-04 | Guardar **historial y favoritos** localmente + repetir cuento por semilla | Se reabre el mismo cuento | M | ✅ «Mis cuentos» (favoritos y 12 últimos, uno por niño) |
| E2-04 | Parámetros de generación: **edad, duración, nivel de susto** | Cambian la selección de fragmentos; pruebas | M | ✅ edad (perfiles 2–3, 4–5, 6–8, 9–12: longitud, oración, vocabulario, sin villano en 2–5; [18](18-voz-edades-y-wizard.md)). La duración y el susto salen del perfil, no son mandos aparte |
| E3-01 | **Guía editorial** y plantilla de autor de fragmentos | Documento + 10 fragmentos de ejemplo revisados | S | ✅ [06](06-modelo-de-contenido.md), [14](14-rubrica-editorial.md) y las reglas del validador |

## Sprint 3 · «Hay muchos cuentos» (objetivo: pack semilla y primera prueba con familias)

| ID | Historia | Criterios de aceptación | Talla | Estado |
|---|---|---|---|---|
| E3-02 | **Pack semilla**: ~25 personajes, ~15 lugares, ~120 fragmentos, 6 enseñanzas | Pasa validador y revisión editorial | L (contenido) | 🟡 15 cuentos (6 de 6–8, 6 de 4–5, 3 de 2–3), 15 personajes con arte, 8 lugares, 3 enseñanzas; **faltan** 3 enseñanzas, más cuentos por edad (hoy 3 de 2–3) y 9–12 |
| E2-05 | **Personajes elegidos por el niño** (héroe y lugar) | Reparto respeta la elección | M | 🟡 **su nombre y su género** ✅ (el héroe lleva su nombre; nunca viaja en la receta); elegir el lugar ☐ |
| E2-06 | Casos de gramática: plurales y `article_override` | Pruebas con *los tres hermanos*, *el agua* | S | ✅ artículos, contracciones, género del héroe (`{hero.o}`) y el validador de género fijo |
| E4-05 | Build interno para testers (TestFlight / pista interna) | 5 testers instalan sin ayuda | S | 🟡 APK de prueba en cada petición (Android); iOS ☐ |
| UX-01 | **Prueba con 10 familias** (guion de observación y encuesta corta) | Resultados documentados; decisión de continuar/ajustar | M | ☐ |
| E11-01 | **Contrato OpenAPI v1** (catálogo, descarga, instalaciones, entitlements) + servidor simulado | La app puede sincronizar contra el simulado; contrato revisado | M | 🟡 solo el de valoraciones (`docs/api/feedback.openapi.yaml`); catálogo, descargas y compras ☐ |
| E11-02 | **Spike S-07:** elegir tecnología de backend y de panel (coste, privacidad, operación) | Decisión escrita (ADR) con comparativa | S | ☐ |

## Pack inicial medieval y arte por código (añadido tras decidir presupuesto cero)

El primer pack, gratuito, es medieval («Reino de la Luna», nombre provisional). El arte nace del código ([11](11-pipeline-de-arte-por-codigo.md)).

| ID | Historia | Criterios de aceptación | Talla | Estado |
|---|---|---|---|---|
| E13-01 | Generador de personajes humanoides por rig + paleta | 6 personajes originales, poses y animación de reposo, vista previa | M | ✅ `tools/art/medieval_kit.py` |
| E13-02 | Escena de fondo por capas con animación | Castillo, molino, luna y luciérnagas; capas separadas | M | ✅ `tools/art/scene_castle.py` |
| E13-03 | Especificaciones de personajes en JSON (no en código) | El generador las lee; el panel podrá editarlas | S | ✅ `art/medieval/specs/` |
| E13-04 | **Renderizador Flutter** de rigs y escenas + pantalla de prueba | Mismas poses que la vista previa; FPS y memoria medidos en Android de gama media | L | 🟡 renderizador y taller hechos y verificados en navegador (0,17 % de píxeles distintos de la referencia); medido en un teléfono de 120 Hz: 116–121 fps con hasta 24 personajes ([11 §9](11-pipeline-de-arte-por-codigo.md)); **falta un Android de gama media/baja** |
| E13-05 | Rig de criatura (dragón) | Cuerpo, alas y cola articulados; se ve bien junto a los humanoides | M | ☐ A3 |
| E13-06 | Biblioteca de animaciones (caminar, correr, sorpresa, miedo, alegría, parpadeo) | Clips como datos, reutilizables por rig | M | ✅ 30 clips de personajes + 14 de objetos, paridad Python↔Dart comprobada |
| E13-09 | **Expresión por acción:** cara animable (cejas, boca, mirada) y brazos con codo | Cada acción tiene su cara y su pose; revisión con imágenes | M | ✅ [16](16-coherencia-texto-imagen.md) §6: cinemática inversa al generar los clips; clips nuevos `eat`, `blow`, `yawn`, `proud`, `wonder` |
| E13-08 | **Mostrar el arte en los cuentos:** cada fragmento elige escena, personajes y clip (`scene.bg/actors/mood`) | El lector anima la escena del fragmento que se narra | M | ✅ Escenario animado por escena: hasta 6 personajes (principales y secundarios), objetos animados, luz, entrada caminando y cámara; regla texto↔ilustración en el validador |
| E13-07 | Kit de fondos del pack (aldea, bosque, cueva, río, interior) | 15 lugares con capas y paletas | L | 🟡 8 de ~15 lugares (castillo, bosque, cueva, río, aldea, cocina de Rosa, cuarto, campanario), con día/atardecer/noche y estaciones |
| E3-03 | **Contenido del pack medieval:** ~25 personajes, ~15 lugares, 6 enseñanzas y ~120 fragmentos | Pasa el validador; revisión editorial | L (contenido) | 🟡 15 premisas (6 de 6–8 con 580–930 palabras, 6 de 4–5 con ≈ 300–350, 3 de 2–3 con ≈ 180) y 3 enseñanzas (honestidad, generosidad, valentía); faltan 3 enseñanzas (humildad, perseverancia, amistad), cuentos de 9–12 y más variantes por cuento |

## Valoraciones y mejora continua (E14) — prioridad desde el primer día

Cada cuento termina pidiendo una nota de 1 a 5; es el único dato que se recoge. Diseño y evidencia en [12](12-valoraciones-y-mejora-continua.md).

| ID | Historia | Estado |
|---|---|---|
| E14-01 | Receta del cuento (pack, versión, semilla, enseñanza, reparto, fragmentos) y versión del motor | ✅ motor, 33 pruebas |
| E14-02 | Ficha de 5 caritas al final del cuento, con «Ahora no» y tono nocturno | ✅ verificada en pantalla |
| E14-03 | Cola local sin conexión (tope 200), envío por lotes de 50, reintentos con retroceso 1 min → 6 h, idempotencia y sin pérdidas con envíos concurrentes | ✅ 32 pruebas |
| E14-04 | Recordatorio de la mañana siguiente para cuentos leídos hasta el final y sin valorar (máx. 3, caduca a 3 días) | ✅ |
| E14-05 | Ajustes para adultos (pregunta de multiplicar): interruptor, qué se envía/no, ejemplo exacto, borrado al desactivar | ✅ |
| E14-06 | Contrato OpenAPI de `POST /v1/feedback` + pruebas de contrato en app y esquema (rechaza cualquier campo extra) | ✅ |
| E14-07 | Análisis (regresión ridge) e informe de fragmentos/transiciones a revisar; simulación de cuántas notas hacen falta | ✅ 8 + 8 pruebas |
| E14-08 | Peso por fragmento en el motor y el esquema del pack (0 = desactivado) | ✅ |
| E14-09 | **Servidor** `/v1/feedback`: validar contra el catálogo publicado, idempotencia, límite de ritmo, tabla `story_ratings` | ☐ S4–S5 (con E11) |
| E14-10 | Panel «Calidad»: fragmentos y transiciones marcados, cuentos peor valorados reconstruidos por receta | ☐ S6 (con E12) |
| E14-11 | Propuesta de pesos con aprobación humana (mín. 0,2, ±50 % por versión) | ☐ con ≥ 1 000 valoraciones |
| E14-12 | Motivo opcional para notas ≤ 3 (*No tuvo sentido, Se repitió, Muy largo o muy corto, Dio miedo, No me gustó la enseñanza*), combinable y omitible | ✅ app, contrato, análisis y simulación |
| E14-13 | Análisis por motivo: qué fragmentos provocan cada queja (la causa se identifica en 81–98 % de los casos según la tasa de respuesta) | ✅ |
| E3-04 | Guía editorial: ≥ 3 variantes por etapa y enseñanza (sin variantes no se puede aprender) | ☐ |

## Spikes planificados (resultados = decisión escrita)

| ID | Spike | Cuándo | Pregunta a responder |
|---|---|---|---|
| S-07 | Tecnología de backend y panel | S3 | ¿Supabase, Firebase o propio? ¿Panel en React o Flutter Web con el motor compilado a JS? |
| S-04 | Arte y animación | S5 (**adelantado**: generador y vista previa hechos; falta medir en Android, paso A2) | Con presupuesto cero se elige **dibujo propio en Flutter** (rigs por código); ¿alcanza 60 FPS y el estilo deseado con el presupuesto de [10 §4](10-arte-y-estilo-visual.md)? Rive/Lottie quedan como plan B. |
| S-02 | Voz | S6–S7 | ¿Qué voz (sistema / neuronal offline / nube) gusta a las familias y cumple licencias y peso? |
| S-06 | Compras y suscripciones | S8 | ¿Capa propia o servicio externo? ¿Cumple las reglas de la categoría infantil? |
| S-03 | Holograma | S9 | ¿Funciona en 3 teléfonos con una pirámide de 6–10 cm? ¿Cuánto cuesta dibujar 4 vistas? |

> La entrega de packs (antes S-05) deja de ser un spike: es el núcleo del release 0.2.

## Lo que ya se hizo del plan de releases (y lo que falta)

El plan original ([02](02-roadmap.md)) ponía el servidor antes que la voz y el arte. Se hizo al revés: con presupuesto cero y los packs
dentro de la app, el cliente avanzó primero.

| Release | Estado | Detalle |
|---|---|---|
| 0.1 Chispa | ✅ | Motor de premisas, validador, receta y valoraciones, favoritos, pack medieval |
| 0.3 Voz (E5) | ✅ casi | Voz del sistema con arreglo de «adelantar», `texto_voz`, wizard y perfiles de edad; modo Escucha (cine), **Leemos juntos**, **solo audio**, **temporizador con bajada gradual**. Falta probar en teléfonos reales y la voz neuronal/pregenerada (decisión S-02) |
| 0.4 Vida (E6, E13) | ✅ casi | Escenario animado, luces y estaciones, expresiones por acción; el rendimiento solo se midió en un teléfono de gama alta |
| 0.5 Holograma (E7) | ✅ casi | Modo holograma, plantilla y guía PDF; **sin probar con una pirámide real** |
| 0.2 Catálogo (E11, E12) | ☐ | Backend, sincronización de packs, manifiesto firmado y panel de administración: sin empezar |
| 1.0 Lanzamiento (E8, E9) | ☐ | Compras y suscripciones, privacidad, formularios y fichas de tiendas, revisión legal, prueba cerrada, id definitivo de la app |

## Lo que falta (ordenado por lo que desbloquea)

1. **Probar en teléfonos reales** (Android gama media, iOS) y con **niños y familias** (UX-01): es lo que más se sabe menos.
2. **Elegir el nombre** y comprobar la marca; después el id técnico de la app, el icono y las fichas.
3. **Más contenido:** cuentos de 9–12 y más para 2–3, tres enseñanzas nuevas, más lugares; y la prueba editorial con lectores
   de los cuentos pequeños (hoy solo los revisó una persona con las imágenes y el validador).
4. **Backend y catálogo (0.2)** para que los paquetes lleguen sin actualizar la app, y **compras (1.0)** para venderlos.
5. **Audio con la pantalla bloqueada:** servicio en primer plano para el modo solo audio.
6. **Caminos elegibles** (el niño decide): diseño hecho en [20](20-caminos-elegibles.md); sin construir.
7. Lo que depende de licencias o cuentas: léxico por edad, voz neuronal, segundo idioma, iOS (TestFlight).

## Ideas para después (Could)

Caminos elegibles ([20](20-caminos-elegibles.md)) · segundo idioma · sonidos para dormir · más tamaños de pirámide ·
logros suaves sin presión · compartir una semilla («el cuento de hoy») · modo cuentacuentos para abuelos a distancia (solo si se resuelve privacidad) ·
recordatorio a la hora de dormir.
(Hechos y ya fuera de esta lista: cuento con el nombre del niño, modo solo audio, varios niños, lectura compartida.)
