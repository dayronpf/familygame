# Mapa de reconocimiento: Readmio (Android, versión 2.7.2)

- **Alcance:** la app completa (inicio, explorar, ficha, lector, audio, biblioteca, progreso, familia, ajustes, pago, extras), **sin** la lectura con micrófono que dispara sonidos y **sin** su catálogo de cuentos.
- **Para:** Mininoches, un producto para vender. La columna `clone` de `features.csv` es lo que **Mininoches ya tiene hoy**, no un clon desde cero.
- **Fecha:** 2026-11-17

Este estudio sigue las reglas de sala limpia: estudia qué hace la app y cómo se mueve el usuario, nunca su código, su arte, sus textos ni su mascota (ver [docs/04](../docs/04-contenido-y-derechos.md)). Las capturas de referencia están en `adjuntos/` (fuera de git) y **nunca** entran en la app.

## Fuentes

| # | fuente | URL | notas |
| --- | --- | --- | --- |
| 1 | Ficha de Google Play | https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419 | La página no se pudo leer como texto. Las capturas de la app Android las cubre la fuente 5. |
| 2 | Ficha de App Store | https://apps.apple.com/app/id1473021827 | Funciones, precios, etiquetas de privacidad e **historial de versiones** desde la 1.11 hasta la 2.7.2. Leída el 2026-11-17. |
| 3 | Web oficial y preguntas frecuentes | https://www.readmio.com/ | Posicionamiento, prueba gratis «Explorer» y más de 500 cuentos. Las preguntas frecuentes están en la portada. |
| 4 | Política de privacidad | https://www.readmio.com/privacy-policy | Correo, cookies, Google Analytics y reconocimiento de voz en el teléfono. Nombra unos «Terms and Conditions» sin enlace. |
| 5 | Capturas de la app (Android 2.7.2) | `adjuntos/1000630840…859.jpg` (19) | Llegaron por correo del dueño del producto. Están analizadas en [docs/28](../docs/28-referencia-readmio-y-plan.md). |
| 6 | Otras páginas públicas | https://www.readmio.com/coloring-pages · https://www.readmio.com/audiobooks-for-kids · https://www.readmio.com/school-and-preschool | Imprimibles, audiolibros y escuelas. Solo los enlaces de la portada. |

**Términos de uso:** no encontré un texto público de términos. La política de privacidad no prohíbe usar el servicio para hacer un producto parecido. Trabajamos solo con fuentes públicas y capturas, sin entrar en ninguna cuenta.

## Ciclo central

El adulto abre la app de noche, recibe una recomendación, elige un cuento corto con una enseñanza («valores») y se lo lee al niño o lo pone en audio. La suscripción desbloquea el catálogo completo y el audio. Lo que se paga es **la rutina de cada noche con cuentos nuevos**, no un cuento suelto.

## Pantallas

**Estados vistos:**
- La columna «estados vistos» dice qué se vio en las capturas y la ficha.
- «inferido» marca lo deducido de las notas de versión o de la web, sin captura.

**Columna «En Mininoches»** (lo que la app ya tiene): ✅ sí, 🟡 a medias, ☐ no.

| ID | pantalla | cómo se llega | para qué | componentes clave | estados vistos | En Mininoches |
| --- | --- | --- | --- | --- | --- | --- |
| S01 | Arranque | Abrir la app | Animación corta de la mascota | Animación a pantalla completa | Cargando | ✅ `ui/splash_page.dart` |
| S02 | Inicio | Pestaña 1 | Saludo nocturno, regalo, avisos y recomendados | Saludo, tarjeta de regalo con *Pulsar y obtener*, carrusel de avisos cerrables, tarjetas grandes de cuento, desplegable de criterio | Con datos y avisos cerrados | ✅ `home_page.dart` (saludo, «Para Ana», avisos). El regalo es los 3 cuentos gratis. |
| S03 | Explorar | Pestaña 2 | Buscar y ojear por categorías | Buscador, carrusel *Novedades*, cuadrícula de categorías con icono y contador | Con datos. Sin resultados: inferido. | ✅ `catalog/explore_tab.dart` |
| S04 | Lista de una categoría | S03, tocar una categoría | Ver los cuentos de un tema o edad | Chips *Todo / No leído / Favoritos / Audio*, filas con miniatura, valores, minutos, ilustraciones e icono de audio | Con datos | ✅ filtros (R-04) |
| S05 | Ficha del cuento | Tocar cualquier tarjeta | Decidir qué cuento leer | Ilustración, valores, compartir, guardar, botón partido **Leer / Escuchar**, minutos, nº de ilustraciones, ⭐ nota media, edad, sinopsis, «Vista previa gratuita · 🔒 Desbloquear» | Libre y bloqueado | 🟡 `catalog/story_detail_page.dart`, sin nota media ni vista previa de escena |
| S06 | Lector | S05 → *Leer* | El adulto lee en voz alta | Texto con palabras en negrita (señales de sonido), solo la portada como dibujo, opciones de texto (todo en MAYÚSCULAS, letra para dislexia) | Inferido de la web y las notas 2.3.0 | ✅ distinto: `shared_reading_page.dart` y `story_page.dart` con escenas dibujadas. Sin opciones de letra. |
| S07 | Reproductor de audio | S05 → *Escuchar* | Audiolibro (coche, adulto cansado) | Reproducir y pausar, avance, listas de reproducción | Inferido de las notas 2.2.x | 🟡 `audio_only_page.dart` con voz del teléfono, sin listas |
| S08 | Muro de pago | Cuento 🔒, Ajustes → Suscripción | Empezar la prueba | Línea de tiempo *Hoy / Día 5 aviso / Día 7 cobro*, plan anual con equivalente mensual, «Ver otros planes», «Canjear código», ✕ | Con planes | ✅ `store/paywall_page.dart` |
| S09 | Biblioteca | Pestaña 3 | Lo guardado y lo leído | Mismos chips de filtro, filas | Con datos. Vacía: inferido. | ✅ `shelf/my_stories_tab.dart` |
| S10 | Perfil y progreso | Pestaña 4 | Ver el hábito | Contadores *Tiempo de lectura*, *Semanas lectoras*, *Cuentos leídos*; premios en gris hasta ganarlos; «Ver todo»; aviso «Inicia sesión para guardar tu progreso» | Con datos | ✅ `progress/progress_tab.dart`, sin cuenta |
| S11 | Todos los premios | S10 → *Ver todo* | Colección completa | Cuadrícula de insignias ganadas y por ganar | Con datos | ✅ en la pestaña Premios |
| S12 | Configuración | Icono de ajustes | Preferencias y cuenta | Idioma de los cuentos ≠ idioma de la app, celebración del premio, ilustraciones animadas, notificaciones, grabaciones, cuenta, suscripción, widgets, valorar, contacto, acerca de | Con datos | ✅ `settings_page.dart`, detrás de la pregunta para adultos |
| S13 | Acerca de | S12 | Versión, términos, licencias, privacidad, vídeo de introducción | Lista de enlaces | Con datos | 🟡 dentro de Ajustes |
| S14 | Familia | S12 (notas 2.6.0) | Hasta 5 miembros, cada uno con su biblioteca y sus premios | Lista de miembros, añadir | Inferido | ✅ `ui/children_page.dart`, hasta 6 niños, con progreso por niño |
| S15 | Tus grabaciones | S12, ficha | Grabar la lectura del adulto y las conversaciones, copia en la nube, importar y exportar, compartir con la familia | Lista de grabaciones, grabar, compartir | Visto en Ajustes | ☐ Fase 4, al final |
| S16 | Radio y música para dormir | Inicio o tras el cuento (notas 1.11 y 2.6.0) | Música suave con duración elegible, 2 emisoras | Reproductor, duración | Inferido | 🟡 música de ambiente y `ui/sleep_timer.dart`, sin emisoras |
| S17 | Imprimibles | Ficha o web | Páginas para colorear, cuento impreso, hojas de actividades con preguntas | PDF | Inferido de la web | 🟡 solo el PDF del holograma |
| S18 | Widgets de inicio del teléfono | Fuera de la app (notas 2.7.0) | Música para dormir, cuento al azar, cuento gratis del día | Widget nativo | Inferido | ☐ R-14 |
| S19 | Iniciar sesión y cuenta | S10 o S12 | Sincronizar biblioteca, premios y grabaciones entre teléfonos | Formulario de correo | Inferido de las notas 2.5.x | ☐ Decisión: sin cuentas, por privacidad |
| S20 | Canjear código | S08 o S12 | Regalos y promociones | Campo de código | Visto en el muro de pago | ✅ canje de la tienda |

## Recorridos

```
F01 Leer el cuento de esta noche (el ciclo central)
    S02 tarjeta recomendada -> S05 ficha -> S06 Leer -> fin (premio si toca)
    clics en el camino feliz: 3
    casos límite: cuento bloqueado (-> F02), sin conexión con un cuento no descargado, niño se duerme a mitad

F02 Probar gratis y suscribirse
    S05 🔒 -> S08 muro de pago -> hoja de la tienda -> S05 desbloqueado
    clics: 3 (+ confirmar en la tienda)
    casos límite: prueba ya usada, pago rechazado, restaurar en otro teléfono, canjear código

F03 Buscar por tema o edad
    S03 -> buscar o tocar una categoría -> S04 -> chip de filtro -> S05
    clics: 3
    casos límite: búsqueda sin resultados, todo leído en esa categoría

F04 Escuchar como audiolibro (en el coche)
    S05 Escuchar -> S07 -> (lista de reproducción, siguiente)
    clics: 2
    casos límite: pantalla apagada, llamada entrante, auriculares desconectados

F05 Grabar mi voz y compartirla
    S05 o S12 -> S15 grabar -> guardar -> compartir con la familia
    clics: 4 o más
    casos límite: permiso de micrófono negado, poco espacio, otro teléfono (copia en la nube)

F06 Ver el progreso y los premios
    S10 -> S11
    clics: 2

F07 Añadir a otro niño de la familia
    S12 -> S14 -> añadir -> nombre
    clics: 3
    casos límite: máximo de miembros, borrar a un miembro con progreso

F08 Música para dormir después del cuento
    S06 fin -> S16 -> elegir duración
    clics: 2
    casos límite: temporizador acaba con la pantalla bloqueada

F09 Cuento al azar
    S02 o S18: agitar el teléfono o tirar el dado -> S05
    clics: 1

F10 Recibir el recordatorio de la noche
    notificación -> S02
    clics: 1
```

**Número a superar:** Readmio pide 3 clics del inicio a leer. Mininoches pide 2 o 3 (tarjeta «Para Ana» → ficha → *Ver y escuchar*).

## Componentes

| componente | variantes | estados | dónde |
| --- | --- | --- | --- |
| Tarjeta grande de cuento | recomendada, con insignia *Nuevo* o 🔒 | normal, bloqueada, leída | S02 |
| Fila de cuento | con miniatura, con icono de audio | normal, favorito, leído | S04, S09 |
| Chip de filtro | Todo, No leído, Favoritos, Audio | elegido o no | S04, S09 |
| Tarjeta de categoría | por edad, por tema | con contador | S03 |
| Carrusel | Novedades, avisos con puntos de página | con ✕ para cerrar | S02, S03 |
| Botón partido | Leer / Escuchar | bloqueado (vista previa) | S05 |
| Datos del cuento | minutos, ilustraciones, nota, edad | — | S05, S04 |
| Línea de tiempo de la prueba | Hoy, Día 5, Día 7 | — | S08 |
| Plan de precio | anual (destacado), mensual, de por vida | elegido | S08 |
| Contador de progreso | tiempo, semanas, cuentos | — | S10 |
| Insignia de premio | ganada (color), por ganar (gris) | — | S10, S11 |
| Interruptor de ajuste | — | encendido o apagado | S12 |
| Barra de pestañas | 4 pestañas | activa | todas |
| Celebración de premio | — | se puede apagar | fin del cuento |

## Modelo de datos deducido

```
Cuento        id, título, valores[], minutos, edad_min, nº_ilustraciones, nota_media, sinopsis,
              temas_de_conversación[], tiene_audio, es_nuevo, es_gratis, categorías[], señales_de_sonido[]
              evidencia: S04, S05, web («temas para conversar», negritas)     confianza: alta
Categoría     id, nombre, icono, tipo (edad | tema), nº_cuentos
              evidencia: S03                                                  confianza: alta
Cuenta        correo, idioma_app, idioma_cuentos
              evidencia: S12, S19, privacidad (correo)                        confianza: media
Miembro       id, cuenta_id, nombre (hasta 5)
              evidencia: notas 2.6.0                                          confianza: media
Biblioteca    miembro_id, cuento_id, guardado, favorito, terminado, último_uso
              evidencia: S09, notas 2.5.x (sincroniza guardado, favorito, terminado)  confianza: alta
Progreso      miembro_id, minutos_lectura, semanas_lectoras, cuentos_leídos
              evidencia: S10                                                  confianza: alta
Premio        id, nombre, regla, ganado_en
              evidencia: S10, S11                                             confianza: alta
Grabación     miembro_id, cuento_id, tipo (lectura | conversación), audio, en_la_nube
              evidencia: S15, notas 2.4.x                                     confianza: media
Suscripción   producto, periodo (mes | año | de por vida), prueba_días, tienda, estado
              evidencia: S08, compras de la App Store                         confianza: alta
Aviso         id, texto, cerrado
              evidencia: S02                                                  confianza: alta
Emisora       id, nombre, pistas[]
              evidencia: notas 2.6.0                                          confianza: suposición
```

**Relaciones:**
- Cuenta 1-n Miembro.
- Miembro 1-n Biblioteca, 1-n Premio, 1-n Grabación y 1-1 Progreso.
- Cuento n-n Categoría.
- Cuenta 1-1 Suscripción.

**En Mininoches** el «cuento» es una **premisa con su enseñanza, un reparto y una semilla**, generado en el teléfono. No hay cuenta: el «miembro» es el `ChildProfile` y todo vive en el teléfono.

## Matriz de funciones

La matriz está en `features.csv`, con **53 filas**:

| prioridad | filas |
| --- | --- |
| must | 18 |
| should | 16 |
| could | 14 |
| skip | 5 |

**Primera medida** (`parity.py`): Mininoches cubre **79,5 de 100** y tiene hechas 17 de las 18 funciones obligatorias. La que falta es el **audiolibro con voz de calidad**, que se dejó para el final a propósito. Hoy usa la voz del teléfono.

## Fuera de alcance (no se puede o no se debe copiar)

- **Lectura con micrófono que dispara sonidos:** el dueño del producto decidió no copiarla ([docs/28](../docs/28-referencia-readmio-y-plan.md) §3.5).
- **Su catálogo de más de 500 cuentos, la mascota, el arte, los textos y la radio con su música:** son su contenido con derechos. Mininoches genera los suyos.
- **Su base de usuarios, sus 52.000 valoraciones y su programa con escuelas:** son su red, no una función.
- **Apple Vision Pro y la versión web:** otras plataformas, fuera de este alcance.

## Tamaño

- **Cantidad:** 20 pantallas, 10 recorridos y 11 entidades.
- **Partes difíciles:**
  1. Grabar la voz y sincronizarla (micrófono, almacenamiento y nube; choca con «sin cuentas»).
  2. Widgets nativos en Android e iOS.
  3. Sincronizar entre teléfonos sin pedir datos personales.
- **Talla:** clonar Readmio desde cero sería **L**. Lo que **le falta a Mininoches** es **M**: unas pocas semanas sin grabaciones ni cuenta, y **L** si se suman las dos.
