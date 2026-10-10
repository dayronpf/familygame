# 11 · Pipeline de arte generado por código (pack medieval)

> Respuesta a: «sin presupuesto para un diseñador, ¿cómo generamos imágenes, movimientos y animaciones de forma
> sistemática, sin herramientas de pago y sin problemas de derechos?». Esta página documenta lo que se **probó de
> verdad** (spike S-04 adelantado) y lo que **todavía no está verificado**.

## 1. Respuesta corta

**Es viable** con un enfoque concreto: *el arte se escribe como código y datos*, no se dibuja a mano ni se pide a un
generador de imágenes. Claude escribe y mantiene los generadores; tú diriges el estilo y apruebas lo que se ve.

Qué hace y qué no hace «la IA a través de mí»:

| Sí | No |
|---|---|
| Escribo programas que dibujan personajes, fondos y animaciones (vectores) | No genero imágenes con un modelo de difusión (tipo «prompt → foto») |
| Renderizo el resultado, lo **miro** y lo corrijo en ciclos (ver → criticar → arreglar) | No puedo garantizar el nivel de un ilustrador profesional |
| Cada pieza queda como datos reproducibles y versionados en git | No dependo de ninguna plataforma de pago ni de una cuenta externa |

## 2. Lo que se probó (todo ejecutado y revisado a la vista)

Archivos en [`art/medieval/`](../art/medieval/) y generadores en [`tools/art/`](../tools/art/):

| Prueba | Resultado |
|---|---|
| 6 personajes medievales originales (aprendiz de caballero, arquera, mago, rey, duque avaro, bandido) | Estilo coherente; cada uno pesa **≈ 7–8 KB** (JSON) |
| Esqueleto articulado (raíz, torso, cabeza, 2 brazos, 2 piernas, 2 objetos) | Poses de caminar, saludar, celebrar y saltar con el mismo rig |
| Objetos como hueso propio | La espada sigue erguida al mover el brazo (fallo detectado y corregido durante la prueba) |
| Fondo por capas: cielo, colinas, castillo, molino, árboles, luciérnagas | **55 KB** el SVG de la escena completa, con 4 capas independientes (parallax) |
| Animación | Respiración/balanceo de los personajes, aspas del molino y destellos; **≈ 29 000 píxeles cambian** entre fotogramas y el bucle de 3 s cierra sin salto |
| Vistas previas | `preview/sheet.png` (personajes y poses), `preview/scene_castle.gif` (escena animada) |
| **Biblioteca de animaciones** (`art/clips/humanoid.json`, **5 KB**) | 10 clips: `idle`, `walk`, `run`, `wave`, `cheer`, `jump`, `surprised`, `scared`, `talk`, `bow`. Son datos y **sirven a cualquier personaje humanoide**: el mismo `walk` mueve a Aldo, a Mara y al mago. Incluye parpadeo (los ojos son un hueso propio). |
| **Escena como datos** (`art/medieval/scenes/castle_night.json`, 31 KB) | Capas, degradados, animaciones ambientales y lista de personajes. La vista previa SVG sale de estos mismos datos. |
| **Renderizador en Flutter** (`app/lib/src/art/`, paquete `packages/caldero_rig`) | Dibuja rigs y escenas sin dependencias externas. Probado en un **navegador real**: coincide con la referencia de Python (diferencia media 0,42/255; 0,17 % de píxeles distintos, solo bordes suavizados), en 3 ejecuciones. |
| **Paridad Python ↔ Dart** | 280 poses (4 personajes × 10 clips × 7 instantes) y 60 valores ambientales comparados número a número: coinciden (tolerancia 1e-5). |
| Pruebas | 15 en `caldero_rig` y 14 en la app (dibujo a píxeles: cielo oscuro, luna clara, degradado, cada clip distinto, aspas que giran) |
| **Taller de personajes** (pantalla de la app, botón en el inicio) | Elige cualquier clip, aplica una prueba de carga de 1 a 24 personajes y muestra un **medidor de fps** para que midas en tu teléfono |

**Coste por fotograma (independiente del dispositivo):** un personaje tiene ≈ 50 formas; el fondo tiene 120 formas estáticas que se graban **una sola vez** como imagen reproducible y 65 animadas. Un fotograma típico (escena + 3 personajes) dibuja **≈ 214 formas**; con 24 personajes, ≈ 1 260.

Para comparar con tu presupuesto de rendimiento ([10 §4](10-arte-y-estilo-visual.md)): 150 KB por personaje era la meta;
estamos en ~8 KB, unas 20 veces por debajo.

## 3. Cómo funciona

```
Especificación (datos)  →  Generador  →  Rig JSON  →  Pack  →  App (dibuja en vivo)
  piezas + paleta + pose     (Python)    esqueleto     catálogo   y panel (vista previa)
```

1. **Rig JSON** (`art/medieval/rigs/*.json`): árbol de huesos con *pivote*; cada hueso lleva formas vectoriales (rutas SVG),
   colores como *tokens* de paleta (`$primary`, `$skin`…) y los objetos que sostiene como huesos hijos.
2. **Paleta** por personaje: cambiar colores = un personaje nuevo sin redibujar.
3. **Poses y animaciones** son datos: ángulos por hueso (`walkA`, `wave`…) y ciclos de reposo (balanceo ±1–3°). Animar cuesta
   **cero bytes de assets**: es matemática sobre los huesos.
4. **Fondos** igual: cada capa es un grupo con su `id` (`sky`, `far`, `mid`, `near`, `actors`).
5. **Renderizado:** el rig se dibuja con rutas vectoriales. En la app será un `CustomPainter` de Flutter (sin dependencias);
   en el panel web, el mismo JSON en un `<svg>` para vista previa. *(Lo de la app ya está hecho; el panel web aún no.)*

Herramientas, **todas gratuitas**: Python 3, Node + Chromium/Playwright (solo para generar las vistas previas), Pillow (GIF),
Flutter/Dart (la app). Nada de licencias de pago.

Cómo regenerarlo:

```bash
cd tools/art
python3 medieval_kit.py        # rigs, índice y hoja de personajes (lee art/medieval/specs/)
python3 make_clips.py          # biblioteca de animaciones (art/clips/)
python3 scene_castle.py        # escena del castillo (art/medieval/scenes/)
python3 make_fixtures.py       # datos de referencia para las pruebas de Dart
# vistas previas (requieren Node con playwright y Pillow):
node render_png.js ../../art/medieval/preview/sheet.svg ../../art/medieval/preview/sheet.png
python3 scene_castle.py --frames /tmp/svgs --fps 10 --secs 3 && node render_dir.js /tmp/svgs /tmp/pngs
python3 make_gif.py /tmp/pngs ../../art/medieval/preview/scene_castle.gif 10 400
```

## 4. ¿Y un generador de objetos en 3D?

**Técnicamente sí** (puedo escribir scripts de Blender sin interfaz, que es gratuito, o geometría procedural con Three.js, y
renderizar y mirar el resultado igual que hice con el 2D). **No lo recomiendo para esta etapa**, por estas razones:

| Tema | 3D | 2D vectorial por código |
|---|---|---|
| Peso | Mallas, texturas y animaciones: MB por personaje | KB por personaje |
| Batería y calor | Alto en un teléfono de gama media, sobre todo durante 15 min de cuento | Bajo |
| Soporte en Flutter | El 3D en tiempo real sigue siendo inmaduro en Flutter | Nativo y estable |
| Esfuerzo artístico | Modelado, materiales, luces y *rigging* en 3D son mucho más difíciles de dirigir sin un artista | Ya probado en esta página |
| Holograma | Un modelo girando sería espectacular, pero la técnica de pirámide funciona muy bien con 2D | OK |

El «aspecto 3D» de tus referencias isométricas se puede **aproximar en 2D** con sombreado, volumen en las formas y capas con parallax
(profundidad sin geometría 3D). Si más adelante quieres una pieza premium 3D para el holograma, se hace un **spike aparte**
(modelo de baja poligonación procedural exportado a glTF y medido en tu Android de gama media).

## 5. Límites honestos (lo que NO está resuelto)

1. **Calidad artística:** el resultado es «personajes geométricos amables». Es coherente y bonito, pero no iguala a un ilustrador
   profesional (menos matices de luz, expresividad y detalle). Mejora con más iteraciones, y tu criterio es lo que decide si basta.
2. **Un solo tipo de cuerpo probado (humanoide).** El **dragón** de tus referencias necesita otro esqueleto (cuadrúpedo con alas).
   Falta construirlo y comprobar que se ve bien; es el siguiente paso de arte.
3. **Vista frontal.** No hay giro 3/4 ni isométrico (las referencias isométricas serían mucho más costosas de animar).
4. **Animación por huesos:** rotación de piezas, sin deformar formas (sin respiración «blanda», cola ondulante, etc.). Para criaturas
   se añadirán cadenas de huesos.
5. **El rendimiento en un teléfono NO está medido.** El renderizador de Flutter existe y es correcto (ver §2), pero los fps solo
   se pueden medir en un dispositivo real. Las cifras que da un navegador sin GPU (≈ 10 fps) **no son representativas**. Hay que
   ejecutar `flutter run --release` en tu Android de gama media y mirar el medidor del taller (§9).
6. **Las especificaciones de personajes ya son datos** (`art/medieval/specs/characters.json`), pero falta una interfaz para
   editarlas: eso es el compositor del panel de administración (después de la versión 0.2).
7. **Expresión limitada:** los ojos parpadean, pero la boca es fija (no hay movimiento de labios al hablar). Se resuelve con piezas
   de boca intercambiables (visemas) en un paso posterior.
8. **Cada personaje nuevo pide una ronda de revisión visual** (hacer, mirar, corregir). Es barato, pero no es automático del todo.
9. **Solo trazos SVG absolutos** (`M L Q C A Z`). El lector de Dart rechaza con error cualquier otro comando (antes lo ignoraba y dibujaba mal en silencio).

## 6. Derechos de autor (qué cambia con este enfoque)

- **Ventajas:** no hay imágenes de terceros, no hay modelos entrenados con obras ajenas generando los dibujos, y todo es reproducible
  desde código y datos que están en tu repositorio. Los diseños son originales; solo comparten *arquetipos* (caballero, rey, mago,
  arquera), que son de uso común.
- **Tus imágenes de referencia:** no están en el repositorio y **no deben entrar** (ni a la app, ni a la ficha de tienda, ni al sitio).
  Se usaron solo para entender el género (formas planas, colores saturados, siluetas claras). Si quieres, bórralas de tu equipo
  cuando termines de usarlas como guía.
- **Incertidumbre que conviene conocer:** en varios países (por ejemplo, EE. UU.) el derecho de autor exige autoría humana y el
  tratamiento de obras creadas con ayuda de IA aún se está definiendo. Para reforzar tu posición: **tú diriges y apruebas**
  el estilo, la selección y la composición, y lo dejamos documentado (este repositorio es ese registro). Tu **marca** (nombre,
  logotipo, personajes principales) se protege por registro de marca, independiente del dibujo.
- **Antes del lanzamiento 1.0:** revisión con un abogado de propiedad intelectual (ya estaba en el checklist de [04](04-contenido-y-derechos.md)).
- **Control de parecido:** cada personaje pasa por la prueba de silueta/búsqueda inversa de [10 §2](10-arte-y-estilo-visual.md).
  Ojo con los arquetipos muy reconocibles (un mago con sombrero estrellado y barba larga es un arquetipo común, pero evitamos copiar
  un personaje famoso concreto: colores, accesorios y proporciones propios).

## 7. Pack medieval inicial (propuesta de contenido)

Nombre provisional: **«Reino de la Luna»** (tema medieval amable, coherente con el estilo nocturno). Será el pack gratuito.

**Reparto inicial (~25):**

| Rol | Personajes (arquetipos originales) |
|---|---|
| Héroes | Aldo (aprendiz de caballero) ✔, Mara (arquera) ✔, Princesa exploradora, Joven herrero, Pastora valiente |
| Ayudantes | Zafiro (mago) ✔, Rey Bonifacio ✔, Sabia del molino, Monje cocinero, Juglar viajero, Escudero parlanchín |
| Antagonistas «suaves» | Duque Codicio ✔ (avaricia), Sombra ✔ (engaño), Hechicera Embustera (mentira), Ogro Gruñón (orgullo), Troll del puente (egoísmo), Dragón Dormilón (miedo) |
| Criaturas | Dragón pequeño, caballo, búho mensajero, zorro astuto |

(✔ = ya existe como rig de prueba.) Los antagonistas están pensados como **espejo de una enseñanza**: cada defecto se resuelve con un valor.

**Lugares (~15):** castillo ✔, molino ✔, aldea, camino real, bosque encantado, puente del río, torre del mago, mercado, campo de
torneo, cueva del dragón, granja, biblioteca del castillo, colina de las luciérnagas ✔, lago, taberna del pueblo.

**Enseñanzas (6):** honestidad, generosidad, valentía + **humildad, perseverancia, amistad** (se escriben nuevas junto a los fragmentos).

**Contenido que falta escribir:** hoy el pack `medieval` (`content/packs/medieval/`) tiene **3 premisas** completas (≈ 565 palabras cada una,
9–10 escenas) con los 6 personajes dibujados, 5 lugares y 3 enseñanzas; el objetivo es **≥ 3 premisas por enseñanza** y las
6 enseñanzas, escritas con el formato y las reglas de [06](06-modelo-de-contenido.md) y [13](13-auditoria-de-historias.md).

## 8. Próximos pasos de arte (propuesta, en orden)

| # | Paso | Estado |
|---|---|---|
| A1 | Especificaciones de personajes en JSON | ✅ `art/medieval/specs/characters.json` |
| A2 | Renderizador Flutter + pantalla de prueba con medidor de fps | ✅ hecho y verificado en navegador · **falta medir en tu Android** |
| A3 | Rig de criatura (dragón/cuadrúpedo con alas y cola articulada) | ☐ |
| A4 | Biblioteca de clips (caminar, correr, sorpresa, miedo, alegría, hablar, reverencia, parpadeo) | ✅ 10 clips · falta boca/visemas |
| A5 | Kit de fondos (aldea, bosque, cueva, río, interior del castillo) con capas | 🟡 5 de ~15: castillo, bosque, cueva, río y aldea (`tools/art/scenes_story.py`) |
| A6 | Variante de iluminación para el holograma (negro puro, siluetas luminosas) | ☐ |
| A7 | Integrar el arte con los cuentos: que cada fragmento muestre su escena (`scene.bg/actors/mood` → escena y clip) | ☐ |

## 9. Cómo medir en tu teléfono (te toca a ti)

```bash
cd app
flutter run --release            # con el teléfono Android conectado por USB (depuración USB activada)
```
1. En el inicio, toca **«Taller de personajes (prueba)»**.
2. Mira el recuadro de arriba a la izquierda: `fps · ms por fotograma (máx) · % de fotogramas lentos`.
   Si dice «⚠ debug» o «perfil», no es válido: hay que usar `--release`.
3. Prueba con el clip `idle` y luego `run`; activa **«Prueba de carga»** y sube el deslizador (6, 12, 24 personajes); apaga **«Fondo»**.
4. Déjalo 2 minutos y toca la parte trasera del teléfono: ¿se calienta? Anota el modelo del teléfono y los números.
5. **Meta:** ≈ 60 fps y menos del 5 % de fotogramas lentos con la escena y 3–6 personajes.
Con tus números decido si hace falta optimizar (por ejemplo, grabar los personajes quietos como imagen o bajar a 30 fps en reposo).

### Resultados medidos (primer teléfono real)

Teléfono de **120 Hz** (modelo por confirmar), APK `release` del flujo `android.yml`, Taller de personajes:

| Escena | fps | Tiempo por fotograma (medio) | Fotogramas lentos |
|---|---|---|---|
| 3 personajes | 119–121 | 6,0–8,4 ms | ≈ 0 % |
| 24 personajes (prueba de carga) | 116–121 | 8,8–12,0 ms | ≤ 2 % |

Lectura: **la meta de 60 fps se cumple con holgura** y la escena aguanta 24 personajes a ritmo de 120 Hz. Cautelas:

- Es un teléfono de gama alta o media-alta (120 Hz); **falta un Android de gama media/baja** (60 Hz) para dar el criterio de E13-04 por cerrado.
- El primer medidor comparaba contra un umbral fijo de 16,7 ms. Desde esta versión el recuadro muestra **UI y dibujo por separado** y el presupuesto real de la pantalla (8,3 ms a 120 Hz; 16,7 ms a 60 Hz). Con 24 personajes el tiempo medio (8,8–12 ms) supera los 8,3 ms de un refresco a 120 Hz, aunque los fps medidos (116–121) indican que casi no se perdieron cuadros; el medidor viejo no separaba el hilo de UI del de dibujo, así que no se puede concluir más. **Hay que repetir la medición con el medidor nuevo.**
- No se midió temperatura ni batería (paso 4).

Se integra al plan en [`07-backlog.md`](07-backlog.md) y [`10-arte-y-estilo-visual.md`](10-arte-y-estilo-visual.md).
