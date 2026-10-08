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
   en el panel web, el mismo JSON en un `<svg>` para vista previa. *(Ver §5: esto último aún no está probado.)*

Herramientas, **todas gratuitas**: Python 3, Node + Chromium/Playwright (solo para generar las vistas previas), Pillow (GIF),
Flutter/Dart (la app). Nada de licencias de pago.

Cómo regenerarlo:

```bash
python3 tools/art/medieval_kit.py        # rigs + hoja de personajes
python3 tools/art/scene_castle.py        # escena del castillo
# vistas previas (requieren Node con playwright y Pillow):
node tools/art/render_png.js art/medieval/preview/sheet.svg art/medieval/preview/sheet.png
node tools/art/render_gif.js art/medieval/preview/scene_castle.svg /tmp/frames 10 3
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
5. **El renderizador de Flutter no está hecho ni medido.** Lo probado fue el generador y el navegador (SVG). Falta: dibujarlo con
   `CustomPainter`, medir FPS y memoria en un Android de gama media (tú me darás el feedback) y comprobar el límite de 2 personajes + 3 capas.
6. **Las especificaciones de personajes viven hoy dentro del código Python.** Para que el panel de administración pueda editarlas
   deben pasar a **archivos de datos** (JSON). Es un cambio previsto antes de la versión 0.2.
7. **Cada personaje nuevo pide una ronda de revisión visual** (hacer, mirar, corregir). Es barato, pero no es automático del todo.

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

**Contenido que falta escribir:** ~120 fragmentos del pack (hoy el pack `demo` tiene 17). Es el siguiente gran bloque del carril de
contenido y se hace con el validador del motor.

## 8. Próximos pasos de arte (propuesta, en orden)

| # | Paso | Para qué |
|---|---|---|
| A1 | Mover las especificaciones a JSON (`art/medieval/specs/`) y que el generador las lea | Que el panel pueda editarlas |
| A2 | **Renderizador Flutter** (`CustomPainter`) + pantalla de prueba con poses y la escena | Probar de verdad en tu Android y medir FPS/memoria |
| A3 | Rig de criatura (dragón/cuadrúpedo con alas y cola articulada) | Cubrir el segundo gran tipo de personaje |
| A4 | Biblioteca de clips (caminar, correr, sorpresa, miedo, alegría, hablar con boca) y parpadeo | Animaciones expresivas con cero bytes extra |
| A5 | Kit de fondos (aldea, bosque, cueva, río, interior del castillo) con capas | Los ~15 lugares del pack |
| A6 | Variante de iluminación para el holograma (negro puro, siluetas luminosas) | Modo pirámide |

Se integran al plan en [`07-backlog.md`](07-backlog.md) y [`10-arte-y-estilo-visual.md`](10-arte-y-estilo-visual.md).
