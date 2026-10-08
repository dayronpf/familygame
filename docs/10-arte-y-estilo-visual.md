# 10 · Arte y estilo visual

Objetivo: gráficos **bonitos, juveniles y modernos**, **sin riesgo de derechos de autor** y **ligeros** para el teléfono
(batería, calor, memoria y tamaño de descarga). La clave es que las tres cosas se resuelven con la **misma decisión**:
un sistema visual **modular y vectorial, propio y de autoría clara**.

## 1. Estilo propuesto: «papel luminoso nocturno»

- **Formas geométricas suaves** (círculos, óvalos, esquinas redondeadas) con **degradados cálidos** y un **brillo interior** (luz de farol / luciérnaga) en los bordes. Siluetas simples y muy legibles.
- **Capas tipo teatro de papel** con *parallax* (fondo lejano, medio, primer plano) y partículas suaves (luciérnagas, estrellas).
- **Paleta nocturna** coherente con el modo noche de la app: fondos azul-violeta profundo y marrón cálido, personajes con colores saturados y un acento ámbar.
- **Por qué funciona:** es moderno y atractivo para niños y adultos, se produce rápido, escala a cientos de personajes y no se parece a ningún estudio concreto si definimos reglas propias (§5).
- **Beneficio para el holograma:** siluetas luminosas sobre negro son justo lo que mejor se ve en la pirámide (ver docs/03 §4).

## 2. Cómo se evitan los problemas de derechos de autor

La forma más segura es que **la propiedad esté clara desde el origen** y que el sistema impida publicar lo que no tiene papeles.

| Vía de producción | Riesgo legal | Coste | Recomendación |
|---|---|---|---|
| **Ilustrador/animador contratado** con contrato de *cesión de derechos* (obra por encargo) | Muy bajo | Medio | **Vía principal** para el estilo base, el primer set de personajes y los fondos |
| **Hecho por el equipo** con herramientas vectoriales | Bajo | Tiempo | Para piezas modulares y variaciones |
| **Material CC0 / dominio público** verificado | Bajo | Bajo | Solo para prototipos y efectos de sonido; nunca como identidad visual |
| **IA generativa** | Medio-alto e incierto | Bajo | **Solo para explorar ideas** (moodboards, bocetos). **No** como arte final: la protección legal del material generado por IA es incierta y varía por país, y puede parecerse a obras existentes. Todo lo final lo redibuja una persona. |
| Copiar/«inspirarse de cerca» en personajes famosos | Alto | — | **Prohibido** |

Reglas de la política de arte (se suman a docs/04):

1. **Contrato de cesión** por escrito con cada artista, guardado en el panel, con derecho de uso comercial en apps.
2. **Nada de nombres de artistas, estudios ni marcas** en encargos ni en *prompts* de exploración.
3. **Prueba de parecido antes de aprobar un diseño:** búsqueda inversa de imágenes (Google Lens/TinEye) y comparación de silueta con una lista de personajes famosos de la categoría. Si se parece, se rediseña.
4. **Cada asset tiene su fila de licencia** (autor, fuente, licencia, prueba) en `assets`/`asset_licenses`; el panel **bloquea la publicación** si falta.
5. **Registro de marca** del nombre de la app y de sus personajes principales cuando se decida el lanzamiento.
6. Fuentes tipográficas con licencia abierta (OFL) y música/voz con licencia comercial verificada.

## 3. Sistema modular: de pocas piezas a cientos de personajes

En lugar de dibujar y animar cada personaje desde cero, se construye un **kit de piezas**:

```
Plataforma de cuerpo (rig)   +   Piezas                     +   Paleta        =   Personaje
  • cuadrúpedo                    • cabeza/orejas/hocico         • colores
  • bípedo                        • cola / alas / caparazón      • patrón
  • ave                           • accesorios (bufanda, farol)  • expresión
  • reptil / criatura                                              
```

- Una **animación base por rig** (reposo, caminar, saltar, sorpresa, alegría, miedo, esconderse) se comparte entre todos los personajes del mismo rig. Un personaje nuevo = piezas nuevas + paleta, **sin animar de nuevo**.
- Con ~6 rigs × ~40 piezas × paletas se obtienen cientos de personajes con **coherencia visual** garantizada.
- **Lugares** con el mismo principio: composiciones base (bosque, cueva, río, colina, playa…) × paleta × props × partículas = cientos de variantes.
- **Encaja con el backend:** el personaje deja de ser un dibujo y pasa a ser **datos** (qué rig, qué piezas, qué colores). En una fase posterior el panel tendrá un **compositor de personajes** para que el equipo cree nuevos sin tocar el código ni volver a pedir animación (fase B5).
- **Encaja con el motor de cuentos:** los campos `scene` de cada fragmento (`bg`, `actors`, `mood`) ya describen qué se ve; se añadirán `rig`, `parts` y `palette` por personaje en el esquema 2 del pack.

## 4. Presupuesto de rendimiento (para no cargar el teléfono)

Metas **medibles** (se verifican en el spike S-04 y en cada sprint de la versión 0.4):

| Recurso | Meta |
|---|---|
| Fluidez | 60 FPS en un teléfono de gama media; 30 FPS en escenas quietas para ahorrar batería |
| Tamaño por personaje | ≈ 50–150 KB (vectorial animado) |
| Tamaño por fondo | ≤ 200 KB (vectorial) o WebP ≤ 150 KB |
| Peso por pack de arte | ≈ 15–25 MB (los packs se descargan por tema) |
| Escena | ≤ 2 personajes animados + 3 capas de parallax + partículas simples |
| Memoria | Solo la escena actual y la siguiente en memoria; liberar al cambiar |
| Batería/calor | Pausar animaciones si se pausa la narración; sin sombras ni desenfoques en tiempo real |

Técnicas:
- **Vectorial en lugar de imágenes grandes:** pesa KB en vez de MB y se ve nítido en cualquier pantalla.
- **Brillos «horneados»** (degradados y brillos pre-dibujados) en lugar de efectos de luz en tiempo real.
- **Partículas procedurales** (luciérnagas, estrellas) dibujadas con pocas formas.
- **Holograma:** la escena cuesta cuatro veces más si se dibuja cuatro veces. Se registra **una vez por cuadro** y se repite en las 4 orientaciones (en Flutter, grabar un `Picture` y dibujarlo 4 veces), con tope de 30 FPS si hace falta. Esto se mide en el spike S-03.
- **Modo bajo consumo** en ajustes para teléfonos antiguos (menos partículas, 30 FPS).

## 5. Tecnología de animación (se decide con un spike)

| Opción | Ventajas | Cuidados |
|---|---|---|
| **Rive** (animación vectorial con *state machines*) | Archivos muy pequeños, rigs compartidos, buen rendimiento, ideal para emociones por estado | Verificar el plan/licencia vigente del editor y del tiempo de ejecución |
| **Lottie** | Muy extendido | Suele requerir After Effects (de pago) y es menos flexible para rigs compartidos |
| **Dibujo propio en Flutter** (`CustomPainter` con rutas vectoriales) | Cero dependencias y todo es nuestro; encaja con el compositor de piezas | Hay que construir las herramientas |

**Spike S-04 (Sprint 5):** se hace *un* personaje (por ejemplo Nilo, el erizo) y *un* fondo en las dos o tres opciones, se mide FPS/memoria/tamaño en un teléfono de gama media y se elige. Resultado: ADR-005 final.

## 6. Qué se necesita de ti / del equipo

1. **Referencias de gusto** (3–5 imágenes que te gusten *como sensación*, sin copiarlas) para fijar la guía de estilo.
2. **Presupuesto y vía de producción** (ilustrador contratado vs. hacerlo en casa), porque define el calendario de las versiones 0.4 y 1.0.
3. **Un teléfono de gama media** (Android) para medir rendimiento real.

## 7. Entregables de arte por etapa

| Versión | Entrega |
|---|---|
| 0.2 (S5) | Spike S-04, guía de estilo v1 (paleta, formas, reglas anti-parecido), primer personaje y fondo de prueba |
| 0.4 «Vida» | Kit del pack gratuito: 3–4 rigs, ~10 personajes, ~6 fondos, partículas y ambientes |
| 0.5 «Holograma» | Variante de iluminación para pirámide y pruebas con familias |
| 1.0 | Pack gratuito completo + primer pack premium con arte nuevo |
| Post-1.0 | Compositor de personajes en el panel y packs temáticos de forma continua |
