# 15 · Modo cine y modo holograma

> Dos formas de vivir el cuento sin leerlo: **cine** (a pantalla completa, con voz y subtítulos) y **holograma**
> (solo dibujo, voz en off y fondo, para un prisma transparente sobre la pantalla). Ambos salen de los mismos
> datos del cuento (texto + escenas), no hay un segundo contenido que mantener.

## Qué hace cada uno

| | Cine | Holograma |
|---|---|---|
| Pantalla | Cielo de estrellas, una escena grande por vez, transición suave | Negro total; **cuatro copias** de la escena alrededor del centro |
| Texto | Subtítulos grandes con la frase que suena resaltada | **Ninguno** (los controles son iconos y se ocultan solos) |
| Voz | Voz del teléfono, en español, algo más lenta que lo normal | Igual |
| Fondo | Colchón suave con campanitas (sintetizado) | Igual |
| Avance | Solo, al ritmo de la voz; pausa, anterior, siguiente | Igual (tocar la pantalla muestra los controles) |

Se abren desde el cuento (iconos de la barra superior). Desde el cine hay un atajo al holograma.

## Cómo funciona el holograma (la geometría)

El prisma es una pirámide transparente **con la punta hacia abajo**, apoyada en el centro del móvil. Cada cara
refleja una de las cuatro copias. Para que la figura «flote» derecha dentro del prisma:

1. **Pies hacia el centro, cabeza hacia fuera.** Lo cercano a la punta se ve más abajo en el reflejo.
2. **Cada copia está reflejada** (un espejo): cada espectador ve «su» copia por una sola reflexión, que invierte
   izquierda y derecha; reflejarla antes lo compensa. Equivale a: copia de abajo = volteada en vertical, copia de
   arriba = volteada en horizontal, laterales = transpuestas (probado en `app/test/show_test.dart`).
3. **Cuñas de 90°.** Las caras a 45° solo reflejan lo que cae en una cuña que arranca en la base del prisma, así
   que cada copia se recorta a su cuña (las cuatro no se pisan) y la escena se pega a la base.
4. **Encuadre cerrado y personajes juntos.** Con 1–2 personajes se ve el 55 % del ancho de la escena, con 3 el 68 %,
   con 4 o más el 82 %; los personajes se acercan al centro para caber en la cuña.
5. **Sin fondo**: el negro no se refleja, así solo «flotan» personajes y objetos, con una luz tenue en el suelo y
   motitas de luz.

Se dibuja la escena **una sola vez** por fotograma y se repite cuatro veces (coste ≈ el del modo normal).

### Medidas de referencia del prisma

Plantilla clásica (artículo de referencia sobre cómo hacer un holograma con el móvil): **cuatro trapecios de plástico**
(carcasa transparente de CD/DVD) de **1 cm (base pequeña) × 6 cm (base grande) × 3,5 cm (altura)**, o el doble
(2 × 12 × 7 cm) para una pantalla mayor; el prisma se apoya sobre la pantalla, con la punta (la base pequeña) hacia abajo,
en una habitación lo más oscura posible y con el plástico bien limpio. Con la cara inclinada a 45°, cada trapecio se
proyecta como una cuña de 45° que arranca en la base de 1 cm: justo la cuña de 90° en la que se recorta cada copia.
Por eso el valor por defecto de la base es **0,16 del lado corto** (1 cm sobre un móvil de ≈ 6,5 cm).

### Ajustes (iconos del holograma, se recuerdan)

- **Guía** (visible mientras se ven los controles): contorno de la base del prisma y de las cuatro cuñas, para colocar
  el prisma centrado y alineado.
- **− / +**: tamaño de la base del prisma (por defecto el 16 % del lado corto de la pantalla). Medid vuestro prisma.
- **Pies dentro/fuera** y **Reflejar**: si la figura se viese al revés o con izquierda/derecha cambiadas con
  vuestro prisma, se corrige con un toque. (No he podido probarlo con un prisma físico; estos dos botones existen
  precisamente por eso.)

Consejos: habitación en penumbra, brillo al máximo, móvil apoyado plano; el modo mantiene la pantalla encendida.

## Voz y sonido

- **Voz:** `flutter_tts` usa la voz del sistema (Android/iOS), gratis y sin conexión si el teléfono tiene voz
  española instalada. Cada frase se narra por separado (así se resalta y la voz respira). Si no hay voz o falla,
  el cuento sigue **por tiempo** (≈ 2,2 palabras/s) en silencio y se puede leer en pantalla. Pendiente: voz
  humana o neural por pack (decisión de producto, ADR futuro).
- **Fondo:** `app/assets/audio/ambient.ogg`, 48 s en bucle, **sintetizado desde cero** con
  `tools/audio/make_ambient.py` (acordes La menor–Fa–Do–Sol + campanitas pentatónicas). No usa muestras ni música
  de terceros: sin riesgo de derechos (registrado en `ASSETS_LICENSES.md`).
- Se narra el título, cada escena y, al final, «La enseñanza de hoy: …».

## Límites conocidos

- No probado con prisma ni con la voz real en un teléfono (las pruebas usan voces simuladas; la geometría está
  verificada por pruebas y por imágenes generadas).
- Las animaciones siguen siendo las de cada escena (gestos en bucle, entrada caminando, cambio de escena con
  fundido); falta animar «al ritmo de la frase» (gestos según el diálogo) y un narrador más expresivo.
- Un teléfono sin voz en español cae al modo por tiempo.
