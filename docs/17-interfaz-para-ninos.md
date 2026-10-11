# 17 · Interfaz pensada para niños (v0.5.0)

> Regla: un niño de 4–7 años (con un adulto al lado) entiende la pantalla de inicio sin leer instrucciones: una portada
> viva, tarjetas grandes con color e icono, y **un** botón enorme. Lo de adultos (ajustes, compras futuras) está detrás de
> una pregunta de multiplicar.

## Qué había (y por qué se rehízo)

La primera pantalla era una lista: título, frase, fichas pequeñas («chips»), la tarjeta de valoración pendiente, «Crear cuento»
y un botón de pruebas («Taller de personajes»). Tenía de todo mezclado, sin jerarquía y sin identidad: no se veía que fuera
una app de cuentos de noche.

## Cómo es ahora

| Pieza | Qué hace |
|---|---|
| **Splash** (`ui/splash_page.dart`) | Todo centrado en vertical. Sale la luna; el caldero aparece con un rebote y se enciende; de él salen volando cuentos (libro, castillo, corona, sombrero de mago) entre luciérnagas; el nombre se revela letra a letra con un destello y aparece «Cuentos para soñar»; abajo y muy pequeña, `v0.5.0`. Dura al menos 3,6 s, espera a que el arte esté cargado y se desvanece al caer. Con «reducir movimiento» salta la animación y cae en cuanto carga. |
| **Inicio** | Portada viva (el castillo de noche con Mara y el mago, que respiran y parpadean) con «¡Hola! ¿Qué cuento quieres esta noche?»; **¿Qué quieres aprender hoy?** con cuatro tarjetas (Sorpréndeme + las enseñanzas del pack, cada una con su color e icono); **Oír otra vez** (el último cuento); y el botón grande **Crear cuento**, fijo abajo. La valoración pendiente (una sola, con calma) sigue apareciendo arriba. |
| **Paquetes** | «Tus paquetes»: el Reino de la Luna, a color y con su castillo. «Próximamente»: otros cuatro mundos en **escala de grises**, con candado y cinta «Pronto»; al tocarlos se explica qué traerán y que serán **de pago** (los del Reino de la Luna siguen gratis). Es un catálogo de maqueta: `packCatalog` en `packs/pack_catalog.dart`; el contenido real de cada paquete vive en `content/packs/<id>`. |
| **Mis cuentos** | Favoritos (el corazón del cuento) y los 12 últimos que se contaron. Tocar uno lo cuenta **igual** otra vez (misma semilla y misma enseñanza elegida). Se guarda solo en el teléfono (`shelf/story_shelf.dart`). |
| **Compartir** | Icono en la barra, tarjeta en Paquetes y botón en las hojas de «Pronto» y en Ajustes: abre el menú del teléfono con un mensaje y el enlace (`share.dart`; hoy el APK de prueba, mañana la tienda). Si el teléfono no puede, copia el mensaje. |
| **Temporizador para dormir** | La lunita en los modos cine, holograma y solo audio: 10, 20 o 30 min. **No corta de golpe:** en los últimos 90 s (la mitad si el temporizador es más corto) baja a la vez el volumen de la voz y de la música (en escala de oído, `nivel²`) y el brillo de la pantalla (`ScreenBrightness`, solo el de la app, sin permisos); al cumplirse calla todo y dice «Dulces sueños». Quitarlo a mitad del fundido, pulsar reproducir o salir de la pantalla devuelve volumen y brillo (`SleepFade` en `player_support.dart`, `ui/sleep_timer.dart`). |
| **Solo audio** | Menú ⋮ del cuento → «Solo audio» (`audio_only_page.dart`): pantalla negra con el brillo al mínimo (apagada del todo en una pantalla OLED), la pantalla encendida y el cuento sonando; un toque enseña unos segundos pausa, escenas, música y temporizador. Si el adulto bloquea el teléfono a mano, que siga sonando lo decide el teléfono (la voz del sistema suele seguir un buen rato, pero no está garantizado; un servicio en primer plano lo resolvería y queda pendiente). |
| **Leemos juntos** | Menú ⋮ → «Leemos juntos» (`shared_reading_page.dart`): una escena por página, con su dibujo y el texto **grande** en colores de noche (letra ajustable), que se pasa deslizando o con los botones; nada suena solo. «Escuchar esta escena» deja que la voz lea esa página (frase resaltada). Con **«Turnos con la voz»** la voz lee las escenas 1, 3, 5… y al adulto le toca leer las otras en voz alta. |
| **Niños** | Ajustes → «Niños» (`ui/children_page.dart`): hasta 6 niños, cada uno con nombre (opcional), edad y género del protagonista; la voz, la velocidad y la música son del teléfono. El activo es el del inicio («¡Hola, Ana!»); con más de uno aparece su carita en la barra para cambiar sin pregunta de adultos. Cada niño ve solo **sus** cuentos guardados (`ShelfEntry.childId`; lo guardado antes de los perfiles lo ven todos) y quitar a un niño borra los suyos. |
| **Ajustes (adultos)** | Tras la pregunta de multiplicar: valoraciones y transparencia, recomendar, el Taller de personajes (herramienta de prueba, ya fuera de la pantalla de los niños) y la versión. |

## Funcionalidades estudiadas

Se descartó lo que no encaja con una app de cuentos para dormir y se dejó para después lo que necesita servidor o cuentas.

| Idea | Decisión |
|---|---|
| Temporizador para dormir (con bajada gradual), pantalla encendida solo mientras suena, barras ocultas | **Hecho** (cine, holograma y solo audio) |
| Modo solo audio con la pantalla apagada | **Hecho a medias**: pantalla negra y encendida; con el teléfono bloqueado depende del sistema (falta el servicio en primer plano) |
| Lectura compartida (el adulto lee, el niño mira) | **Hecho** («Leemos juntos», con turnos con la voz) |
| Varios niños en el mismo teléfono | **Hecho** (perfiles con su estante; sin cuentas) |
| Favoritos y «oír otra vez» sin cuentas | **Hecho** |
| Ver todos los paquetes y los que llegarán, de pago | **Hecho** (maqueta, sin cobro) |
| Recomendar a un amigo | **Hecho** |
| Accesibilidad: letra grande, «reducir movimiento», lector de pantalla con etiquetas en tarjetas | **Hecho** (probado a 1,3× en pantallas estrechas) |
| Compras dentro de la app (pago de paquetes) | Después: necesita las tiendas y el control de adultos ya hecho (`askAdult`) |
| Nombre del niño como protagonista | **Hecho** (docs/18 §3 bis) |
| Descarga de cuentos sin conexión por paquete | Ya funcionan sin conexión (todo va en la app); se revisará con paquetes grandes |
| Recordatorio a la hora de dormir | Después: notificaciones; pide permiso y no aporta a un MVP |
| Cuentas y anuncios | **No**: privacidad ante todo (docs/12). Los perfiles de niños viven solo en el teléfono |

## Cómo se revisa

```
cd app
UI_OUT=/tmp/ui flutter test test/ui_shots_manual_test.dart
```

Guarda capturas (splash, inicio, paquetes, cuento, Mis cuentos) a tamaño de teléfono y con la letra real para revisarlas a
ojo. Las pruebas automáticas están en `test/ui_redesign_test.dart` (splash, pestañas, paquetes en gris, estante, compartir,
temporizador) y `test/app_test.dart`.

## Una lección del splash

Con «reducir movimiento» la animación de entrada se salta poniéndole el valor final, y eso **cancela** el futuro de
`forward()`: el splash se quedaba esperando para siempre. Ahora se espera por el estado de la animación (completada), no por
ese futuro. Lo atrapó la prueba «no se queda colgado».
