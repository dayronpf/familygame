# 17 · Interfaz pensada para niños (v0.2.0)

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
| **Splash** (`ui/splash_page.dart`) | Noche de cuento: un caldero hierve, de él suben estrellitas y la luna; aparece «Caldero de Cuentos», «Cuentos para soñar» y, abajo y muy pequeña, `v0.2.0`. Dura al menos 3 s y espera a que el arte esté cargado (así el inicio ya está listo cuando cae). Con «reducir movimiento» salta la animación y cae en cuanto carga. |
| **Inicio** | Portada viva (el castillo de noche con Mara y el mago, que respiran y parpadean) con «¡Hola! ¿Qué cuento quieres esta noche?»; **¿Qué quieres aprender hoy?** con cuatro tarjetas (Sorpréndeme + las enseñanzas del pack, cada una con su color e icono); **Oír otra vez** (el último cuento); y el botón grande **Crear cuento**, fijo abajo. La valoración pendiente (una sola, con calma) sigue apareciendo arriba. |
| **Paquetes** | «Tus paquetes»: el Reino de la Luna, a color y con su castillo. «Próximamente»: otros cuatro mundos en **escala de grises**, con candado y cinta «Pronto»; al tocarlos se explica qué traerán y que serán **de pago** (los del Reino de la Luna siguen gratis). Es un catálogo de maqueta: `packCatalog` en `packs/pack_catalog.dart`; el contenido real de cada paquete vive en `content/packs/<id>`. |
| **Mis cuentos** | Favoritos (el corazón del cuento) y los 12 últimos que se contaron. Tocar uno lo cuenta **igual** otra vez (misma semilla y misma enseñanza elegida). Se guarda solo en el teléfono (`shelf/story_shelf.dart`). |
| **Compartir** | Icono en la barra, tarjeta en Paquetes y botón en las hojas de «Pronto» y en Ajustes: abre el menú del teléfono con un mensaje y el enlace (`share.dart`; hoy el APK de prueba, mañana la tienda). Si el teléfono no puede, copia el mensaje. |
| **Temporizador para dormir** | La lunita en los modos cine y holograma: 10, 20 o 30 min; al cumplirse calla la voz y el fondo y dice «Dulces sueños». |
| **Ajustes (adultos)** | Tras la pregunta de multiplicar: valoraciones y transparencia, recomendar, el Taller de personajes (herramienta de prueba, ya fuera de la pantalla de los niños) y la versión. |

## Funcionalidades estudiadas

Se descartó lo que no encaja con una app de cuentos para dormir y se dejó para después lo que necesita servidor o cuentas.

| Idea | Decisión |
|---|---|
| Temporizador para dormir, pantalla encendida solo mientras suena, barras ocultas | **Hecho** (cine y holograma) |
| Favoritos y «oír otra vez» sin cuentas | **Hecho** |
| Ver todos los paquetes y los que llegarán, de pago | **Hecho** (maqueta, sin cobro) |
| Recomendar a un amigo | **Hecho** |
| Accesibilidad: letra grande, «reducir movimiento», lector de pantalla con etiquetas en tarjetas | **Hecho** (probado a 1,3× en pantallas estrechas) |
| Compras dentro de la app (pago de paquetes) | Después: necesita las tiendas y el control de adultos ya hecho (`askAdult`) |
| Nombre del niño como protagonista | Después: toca el motor de premisas |
| Descarga de cuentos sin conexión por paquete | Ya funcionan sin conexión (todo va en la app); se revisará con paquetes grandes |
| Recordatorio a la hora de dormir | Después: notificaciones; pide permiso y no aporta a un MVP |
| Cuentas, anuncios, perfiles | **No**: privacidad ante todo (docs/12) |

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
