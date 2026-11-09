# 28 · Lo que aprendimos de Readmio y plan para traerlo a la app

> Fuente: 19 capturas de Readmio 2.7.2 (Android) guardadas en `adjuntos/` (8 de noviembre de 2026).
> Las usamos **solo para entender funciones**. No se copia su nombre, mascota, arte, textos ni catálogo
> (ver [04](04-contenido-y-derechos.md)). Todo lo que hagamos sale de nuestro motor y nuestro arte.

## 1. Qué hace cada pantalla

| # | Pantalla (capturas) | Qué ofrece | ¿Lo tenemos? |
|---|---|---|---|
| 1 | **Arranque** (`…840`) | Animación corta de la mascota en un cohete sobre cielo estrellado. | ✅ `ui/splash_page.dart` |
| 2 | **Inicio · saludo y regalo** (`…841`) | Pregunta nocturna («¿leemos un cuento antes de dormir?»), tarjeta «Cuento gratis» con lazo: *Pulsar y obtener* desbloquea un cuento premium. | 🟡 tenemos inicio con «Crear cuento», sin regalo |
| 3 | **Inicio · comunicados** (`…842`) | Carrusel de avisos con puntos de página y botón ✕ para cerrar cada uno (novedades, «historias gratis»). | ☐ |
| 4 | **Inicio · recomendado** (`…843`, `…844`) | Lista vertical de tarjetas grandes: ilustración, insignia *Nuevo* o 🔒, título, valores (p. ej. «Sinceridad, Perseverancia»), ⏱ minutos, edad «5+», etiqueta *Audio*. Desplegable para cambiar el criterio. | 🟡 «Mis cuentos» y paquetes, sin recomendaciones |
| 5 | **Ficha del cuento** (`…845`, `…847`, `…851`) | Ilustración arriba; valores; **compartir** y **guardar**; título; botón partido **Leer / Escuchar**; minutos, nº de ilustraciones, ⭐ nota media, edad; «Vista previa gratuita · 🔒 Desbloquear»; sinopsis. | ☐ (vamos directo al cuento) |
| 6 | **Muro de pago** (`…846`, `…852`) | Línea de tiempo de la prueba: *Hoy* acceso, *Día 5* aviso, *Día 7* empieza el cobro; «Canjear código»; botón *Iniciar prueba gratuita*; precio anual y mensual equivalente; «Ver otros planes»; ✕. | ☐ (E8 sin empezar) |
| 7 | **Catálogo** (`…848`, `…849`) | Buscador; *Novedades* en carrusel horizontal; *Categorías* con icono y número de cuentos: por edad (+3, +5, +8, pequeñines), *Cuentos cortos*, *Para dormir*, *Mi cuerpo*, *Salud*, *Emociones y empatía*… | 🟡 pestaña «Paquetes»; sin búsqueda ni categorías |
| 8 | **Lista de una categoría** (`…850`) | Chips de filtro *Todo / No leído / Favoritos / Audio*; filas con miniatura, título, valores, minutos, ilustraciones, icono de audio. | ☐ |
| 9 | **Biblioteca** (`…853`) | Lo guardado, con los mismos filtros. | 🟡 «Mis cuentos» (favoritos y 12 últimos), sin filtros |
| 10 | **Perfil · progreso** (`…854`, `…859`) | Contadores: *Tiempo de lectura*, *Semanas lectoras*, *Cuentos leídos*. *Premios* en gris hasta ganarlos (semana perfecta, primeros brotes, flor, arbusto, roble, aprendiz, cazador, devoralibros…) con «Ver todo». Aviso «Guarda tu progreso: inicia sesión». | ☐ |
| 11 | **Configuración** (`…856`, `…857`) | Idioma de los cuentos ≠ idioma de la app; *Mostrar celebración del premio*; *Ilustraciones animadas*; *Notificaciones*. **Tus grabaciones**: nube, importar, exportar. Cuenta. Suscripción: familia, canjear código, adquirir, restaurar. Galería de widgets, reseña en tienda, contacto, acerca de. | 🟡 idioma, voz, edad, música, efectos, privacidad, recomendar |
| 12 | **Acerca de** (`…858`) | Familia de la mascota, versión, lema, vídeo de introducción, términos, colaboradores, licencias, privacidad. | 🟡 versión y licencias en ajustes |

### Lo más valioso para nosotros

1. **Ficha antes del cuento** con *Leer / Escuchar*: encaja exacto con nuestra visión (lectura compartida por defecto, escucha opcional).
2. **Progreso de la familia** («semanas lectoras»): es casi nuestra métrica estrella ([00](00-vision.md)). Lo hacemos sin presión ni rachas que se pierden.
3. **Grabar la voz del adulto**: el adulto sigue siendo protagonista, y el niño escucha a mamá o papá aunque no estén.
4. **Explorar por tema y edad, con búsqueda**: hoy todo pasa por el asistente de crear cuento.
5. **Muro de pago claro** (prueba con aviso el día 5): buena práctica para cuando llegue E8.

### Diferencia de fondo

Readmio es un **catálogo fijo** (250+ cuentos escritos). Nosotros **generamos** cuentos con premisas, enseñanzas,
reparto y semilla. Por eso «un cuento» en su catálogo equivale para nosotros a **una premisa + enseñanza** (lo que el
niño elige) y «leído» se guarda por **semilla** en el estante. Las categorías salen de los metadatos de las premisas
(edad, enseñanza, duración, «para dormir»), no de una lista a mano.

## 2. Plan por fases

Tallas S/M/L como en [07](07-backlog.md). Las fases 1–3 no necesitan servidor ni compras y se pueden empezar ya.

### Fase 1 · Explorar y elegir mejor (sin servidor) — release 0.12

> **Estado (8-nov-2026):** ✅ R-01, R-02, R-03 y R-04 hechos (sin commit). R-02 se resolvió **sin tocar el esquema**: los
> minutos salen de la longitud de las escenas (≈ 850 caracteres por minuto), la sinopsis es el principio real del cuento
> (semilla fija por cuento, así la ficha y la lectura coinciden) y los valores son la enseñanza y el paquete. «Para dormir»
> queda para cuando el esquema tenga esa marca. El motor acepta `StoryOptions.premiseId`. Pendiente: R-05 (inicio renovado).

| ID | Historia | Dónde | Talla |
|---|---|---|---|
| R-01 | **Ficha del cuento**: ilustración de la escena inicial (nuestro `StoryStage`), enseñanza y valores, minutos estimados, edad, nº de escenas, sinopsis de 2–3 líneas generada del primer fragmento, ♥ guardar, compartir; botón partido **Leer juntos / Escuchar** (abre `shared_reading_page` o `story_page`/`audio_only_page`). Se muestra al tocar un cuento del estante, una recomendación o una categoría. | `story_detail_page.dart` nuevo, `story_flow.dart`, `home_page.dart` | M |
| R-02 | **Metadatos de premisa**: `duration_min`, `tags` (valores), `bedtime: true`, `synopsis` opcional. Esquema + validador + paquetes existentes. | `content/schema/pack.schema.json`, `caldero_engine/models.dart`, `validator.dart`, `content/packs/*` | M |
| R-03 | **Pestaña Explorar** (renombra o amplía «Paquetes»): buscador (título, enseñanza, personaje), *Novedades* en carrusel, *Categorías* automáticas con contador: por edad (2–3, 4–5, 6–8, 9–12), *Cortos* (≤ 6 min), *Para dormir*, una por enseñanza, una por paquete. | `packs/packs_tab.dart` → `explore/explore_tab.dart`, `explore/category_page.dart` | M |
| R-04 | **Filtros** en categoría y en «Mis cuentos»: *Todos / Sin terminar / Favoritos / Por niño*. Requiere guardar `finished` y `minutesListened` en `ShelfEntry`. | `shelf/story_shelf.dart`, `shelf/my_stories_tab.dart` | S |
| R-05 | **Inicio renovado**: saludo según la hora y el niño activo; tarjeta «Cuento de esta noche» (recomendado: enseñanza no usada en la última semana + edad del niño); 2–3 tarjetas grandes «Recomendado para Ana» con insignias *Nuevo* / 🔒; carrusel de **avisos** locales cerrables (JSON en assets, se recuerda cuáles se cerraron). | `home_page.dart`, `ui/hero_banner.dart`, `assets/news.json` | M |

**Pruebas:** widgets de ficha y filtros; motor: categorías deterministas por pack; validador rechaza `duration_min` fuera de rango.

### Fase 2 · Progreso y premios suaves — release 0.13

| ID | Historia | Dónde | Talla |
|---|---|---|---|
| R-06 | **Estadísticas locales por niño**: minutos de cuento, cuentos terminados, **semanas con al menos 3 noches de cuento** (nuestra North Star, en vez de «semanas lectoras»). Se cuenta al llegar al final o tras ≥ 80 % de escenas. Solo en el teléfono. | `progress/progress_store.dart` nuevo, ganchos en `story_flow.dart` | M |
| R-07 | **Pestaña Perfil / «Nuestro rincón»** con los 3 contadores y la colección de premios. | `progress/progress_tab.dart`, 4.ª pestaña en `home_page.dart` | M |
| R-08 | **Premios** (~12, arte propio por código, temática de nuestro mundo: semilla → brote → árbol; farol → luna → constelación). Reglas: primer cuento, 5/25/100 cuentos, una semana con 3 noches, probar las 6 enseñanzas, leer juntos 10 veces, terminar un cuento de cada paquete… **Nunca se pierden** ni hay rachas que castiguen ([05](05-modelo-freemium.md): sin mecánicas de ludopatía). | `progress/awards.dart`, `art/awards/` + `tools/art/` | M |
| R-09 | **Celebración** al ganar un premio, al terminar el cuento (no en medio), con sonido suave; interruptor en ajustes «Mostrar celebración». | `ui/award_celebration.dart`, `settings/app_settings.dart` | S |

### Fase 3 · Ajustes y hábito — release 0.14

| ID | Historia | Dónde | Talla |
|---|---|---|---|
| R-10 | **Recordatorio de la hora del cuento** (notificación local diaria a la hora que elija el adulto, días de la semana, apagado por defecto). Paquete `flutter_local_notifications`; permiso en Android 13+ e iOS. | `settings_page.dart`, `notifications/bedtime_reminder.dart` | M |
| R-11 | **Ilustraciones animadas sí/no** (ahorro de batería y para niños sensibles): escena fija en el primer fotograma. | `art/story_stage.dart`, `app_settings.dart` | S |
| R-12 | **Idioma de la app separado del idioma de los cuentos** (cuando haya un segundo idioma; hoy solo dejar el ajuste preparado). | `app_settings.dart` | S |
| R-13 | **Acerca de**: pantalla propia con familia de personajes, versión, lema, términos, privacidad, licencias, contacto y «Valorar en la tienda» (detrás de la puerta para adultos). | `legal/about_page.dart` | S |
| R-14 | **Widget de pantalla de inicio** «Cuento de esta noche» (Android/iOS). | nativo + `home_widget` | L · *Después* |

### Fase 4 · Grabar la voz de mamá o papá — **al final, después de la fase 5**

| ID | Historia | Dónde | Talla |
|---|---|---|---|
| R-15 | **Grabar un cuento**: desde la ficha, «Grabar mi voz»; se graba escena por escena en modo «Leemos juntos» (el texto en pantalla, botón grabar/repetir por escena). Se guarda ligado a la **semilla + elecciones** del cuento (mismo cuento, mismo texto). | `recordings/recorder_page.dart`, paquete `record` | L |
| R-16 | **Escuchar una grabación**: en la ficha aparece «Escuchar con la voz de Papá»; el reproductor usa el audio por escena en vez del TTS y avanza la animación igual que hoy. | `narration/playback.dart` (nueva fuente de voz) | M |
| R-17 | **Exportar / importar grabaciones** (zip con manifiesto) para pasarlas a otro teléfono. Sin nube por ahora. | `recordings/export.dart`, `share_plus` | M |
| R-18 | Privacidad: permiso de micrófono explicado al adulto, grabaciones solo locales, «Borrar mis grabaciones», actualizar política y fichas de tienda ([22](22-privacidad-y-tiendas.md)). | `legal/`, `content/legal/` | S |

### Fase 5 · Compras (depende de E8 y E11) — release 1.0

| ID | Historia | Talla |
|---|---|---|
| R-19 | **Muro de pago** detrás de la puerta para adultos: qué incluye, línea de tiempo honesta de la prueba (hoy / aviso el día 5 / cobro el día 7), precio total y equivalente mensual, «Ver otros planes», ✕ siempre visible, sin cuentas atrás. | M |
| R-20 | `in_app_purchase`: compra por paquete y/o suscripción «Familia», **restaurar compras**, verificación en servidor. | L |
| R-21 | **Canjear código** (regalos, promociones a escuelas). | M |
| R-22 | **Regalo de bienvenida**: «Un cuento premium de regalo» en el inicio que desbloquea una premisa de un paquete de pago (anzuelo amable, sin presión al niño). | S |
| R-23 | **Vista previa** de cuentos bloqueados: la ficha deja leer la primera escena y muestra 🔒 *Desbloquear*. | S |

### Fase 6 · Cuenta y sincronización (opcional, posterior)

Iniciar sesión solo para el adulto, para guardar progreso, premios y grabaciones entre teléfonos. Choca con «no recogemos
datos»; decidir solo si las familias lo piden en la prueba UX-01.

## 3. Decisiones que necesitamos del dueño del producto

1. ~~**Modelo de cobro**~~ — **decidido (8-nov-2026):** suscripción anual con prueba de 7 días + mensual, precio por región ([05](05-modelo-freemium.md)); voz pregrabada para que cuadren los números ([29](29-voz-pregrabada-y-costos.md)).
2. ~~**Grabaciones de voz**~~ — **decidido (8-nov-2026):** toda la narración nueva (grabar la voz del adulto, fase 4, y la voz
   pregrabada con ElevenLabs, [29](29-voz-pregrabada-y-costos.md)) va **al final**, después de las compras. Readmio no narra: lo
   lee el adulto o el niño. La narración con la voz del teléfono que ya tiene la app se queda como está.
5. **No copiamos** la lectura con micrófono de Readmio (el adulto lee en voz alta, la app reconoce la palabra «vaca» y suena
   un mugido). Sí tomamos su estructura de pantallas, su forma de cobrar y el resto de funciones de este documento.
3. **Nombre de la pestaña Perfil**: algo nocturno y familiar («Nuestro rincón», «Nuestras noches») en vez de «Perfil».
4. **Las capturas en `adjuntos/`** son de una app de terceros: recomendamos **no subirlas al repo** (añadir `adjuntos/` a `.gitignore`).

## 4. Orden recomendado

R-02 → R-01 → R-04 → R-03 → R-05 (fase 1, ~2 sprints) · R-06 → R-07 → R-08 → R-09 (fase 2, ~1–2 sprints) ·
R-11, R-10, R-13 (fase 3, ~1 sprint) · fase 5 (compras) junto con E8/E11 · **al final:** fase 4 (grabaciones) y la voz
pregrabada de [29](29-voz-pregrabada-y-costos.md).
