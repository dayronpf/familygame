# 20 · Caminos elegibles: que el niño decida dentro del cuento

> **Idea del dueño del producto:** en ciertos momentos la historia se detiene, se le hace una pregunta al niño y elige uno de 3 caminos.
> **Veredicto corto:** sí, pero **poco y con forma de diamante**: una sola pregunta por cuento (solo perfiles 6–8 y 9–12 al principio),
> tres ramas de una escena que **vuelven al mismo desenlace**, y «elige por mí» siempre disponible. Es barato en este motor
> (≈ +20 % de texto en la premisa elegida) y el riesgo real no es técnico sino de **sueño**: se mide antes de generalizar (§6).

**Cómo se hizo este documento.** Lectura del código y los docs citados; búsqueda web con apertura de cada fuente que se cita (§1.1;
lo que no pude abrir lo digo); y scripts de Python para contar (Anexo A). **No había SDK de Dart en el entorno**, así que no se ejecutó
ni `dart test` ni el validador: las cifras de longitud son aproximaciones (cada `{token}` cuenta 1 palabra salvo los atributos de
personaje, que cuentan su frase) y **hay que remedirlas con `audit_stories`** al implementarlo. El árbol de trabajo tiene cambios sin
confirmar hechos en paralelo (pack 0.14.0 con 9 premisas más para 2–3 y 4–5, `storyWordLimits` por perfil, `heroName`/`heroGender` en
`StoryOptions`); este documento se escribió sobre `HEAD` (pack 0.13.1, 6 premisas, todas 6–8) y las 6 premisas no han cambiado.
No se tocó ningún archivo salvo este.

---

## 1. Valoración honesta

### 1.1 Qué dice la evidencia (solo lo que abrí y leí)

| Fuente | Qué dice | Qué implica aquí | Límite |
|---|---|---|---|
| Takacs, Swart y Bus (2015), *Review of Educational Research* — meta-análisis, 43 estudios, 2 147 niños de 3 a 10 años. [PDF](https://scholarlypublications.universiteitleiden.nl/access/item:2872126/view) | Los cuentos con tecnología superan poco a la lectura tradicional (comprensión g+ = 0,17; vocabulario 0,20). **Multimedia** (dibujos animados, música, sonidos) ayuda; los elementos **interactivos** (puntos táctiles, juegos, diccionarios) **distraen**, sobre todo a niños de hogares menos estimulantes. Solo ≈ 20 % de los puntos táctiles y ≈ 25 % de los juegos de las apps populares (análisis de 2012 que el artículo cita) tenían que ver con la historia. Formula como **hipótesis** que una interacción *pegada al relato* podría ayudar | Respalda animación + voz (ya los tenemos). Obliga a que la elección sea **parte del relato**, no un juego, y **rara** (una por cuento) | Midió comprensión y vocabulario, no sueño; **no estudió elecciones ramificadas** |
| Pillinger y Vardy (2022), *Journal of Research in Reading* — revisión de 46 estudios sobre lectura dialógica. [ficha](https://irep.ntu.ac.uk/id/eprint/47127) | Efectos positivos en lenguaje y alfabetización en menores de 5 años; algún indicio de más disfrute, vínculo adulto-niño y confianza de los padres; piden estudios más rigurosos | La pausa de la pregunta es una **ocasión de conversación con el adulto** (lo que activa el beneficio es hablar del cuento, no tocar). Un texto breve para el adulto («¿cuál harías tú, y por qué?») lo favorece | La lectura dialógica es adulto-niño con libro; no prueba que una app lo reproduzca |
| What Works Clearinghouse (2010), informe «Dialogic Reading». [PDF](https://ies.ed.gov/ncee/WWC/Docs/InterventionReports/wwc_dialogic_reading_042710.pdf) | Describe la técnica (el adulto pregunta, evalúa, amplía y repite: PEER; tipos de pregunta CROWD). «Potencialmente positivo» en comunicación y lenguaje, con 2 estudios y 52 niños de 3–6 años **con retraso del lenguaje** | La pregunta abierta del adulto («¿por qué?») es práctica conocida | Evidencia pequeña y población específica |
| *Choose Your Own Adventure* ([Wikipedia](https://en.wikipedia.org/wiki/Choose_Your_Own_Adventure)) | La idea de Edward Packard nació de **cuentos para dormir a sus hijas**; cada punto ofrece «dos o tres opciones»; 184 libros y más de 250 millones de copias (1979–1998) | El formato nació en nuestro mismo ritual; **2–3 opciones** es el estándar probado | Son ventas, no resultados en niños |
| Breede (2021), «Designing an interactive audio narrative for children», The Writing Platform. [artículo](https://thewritingplatform.com/?p=4303) | Prototipo de audio-cuento interactivo (Alexa) para niños de 4–7 años: **2 opciones** por punto de la trama, *foldback* (ramas que reconectan) para que el árbol no crezca, y **fallos del reconocimiento de voz con niños** como principal frustración | Elegir **tocando**, no hablando; 2 opciones en 4–5; reconvergir | Un prototipo de una autora (31 escenas), sin evaluación formal |
| Emily Short (2016), [«Beyond Branching»](https://emshort.blog/2016/04/12/beyond-branching-quality-based-and-salience-based-narrative-structures/) | Cada elección nueva obliga a «más contenido más adelante»; propone estructuras por **cualidades** (contenido que se desbloquea por estado) | Es exactamente `requires`/`adds` de nuestro motor | Es ensayo de autora, no estudio |
| Fichas de tienda de [TellieTales](https://apps.apple.com/us/app/-/id6747285384) y [Taleverse](https://apps.apple.com/app/id6739170747) | Existen apps de cuentos con elecciones (una pausa cada 1–2 min en la primera; ramas con voz profesional en la segunda) | Hay mercado y no es exclusivo; pausar cada 1–2 min es **lo opuesto** a lo que proponemos para dormir | Textos de los propios desarrolladores, sin verificar |

**Lo que no encontré (y no invento):** ningún estudio sobre elecciones ramificadas y **sueño o relajación** de niños, ni sobre la edad
mínima a la que un niño sigue una trama con ramas (los criterios de edad de §1.4 son decisión de producto, no resultado de
investigación); ninguna página oficial verificable de Toca Boca, Lingokids ni Storytel Kids con cuentos de elección (la búsqueda
solo devolvió reseñas antiguas); el artículo de Parish-Morris y otros (2013) sobre diálogo con libros electrónicos aparece citado en
reseñas pero **no lo abrí**, así que no lo uso.

### 1.2 Pros y contras para este producto

| | A favor | En contra |
|---|---|---|
| **Misión** (el adulto sigue siendo protagonista, [00](00-vision.md)) | La pregunta crea una pausa natural para que el adulto hable con el niño; refuerza «primero la familia» | Si el niño toca solo y el adulto mira el teléfono, se pierde (la app debe invitar a hablar, no a jugar) |
| **Rejugabilidad** | Con 3 ramas, la misma semilla se vive de 3 maneras; baja la repetición de trama (hoy hay 2 premisas por enseñanza para 6–8; [13 §7](13-auditoria-de-historias.md) pedía ≥ 3) a un coste de ≈ ¼ de una premisa nueva (§2.3) | La trama (villano, moraleja, desenlace) es la misma: el niño que repite lo nota. No sustituye a escribir más premisas |
| **Motor** | `requires`/`adds` ya existen; el cuento sigue siendo determinista y la receta lo describe | Cambia el contrato de generación (hoy un cuento nace entero de una semilla): hace falta un cuento «a medias» (§3.2) |
| **Dormir** | El formato nació en la cama; el niño que decide se implica | **Elegir activa, dormir calma** (§1.3). Sin datos propios; es el riesgo principal |
| **Voz y pantallas** | Con voz, la pregunta no obliga a leer | Cine: hay que pausar y esperar; holograma: tocar en la oscuridad, **sin prisma real probado** ([15](15-modo-cine-y-holograma.md)) |
| **Calidad editorial** | Una rama equilibrada se revisa con la misma rúbrica ([14](14-rubrica-editorial.md)) | Cada camino debe leerse bien: se revisan *rutas*, no solo variantes (§3.4) |
| **Mejora continua** ([12](12-valoraciones-y-mejora-continua.md)) | Nuevas señales (qué opción, si la eligió el niño) | **Sesgo de selección**: ya no es el motor quien reparte al azar entre alternativas, es el niño (§5) |
| **Privacidad** | Un código de opción más en la receta; nada de texto | Hay que ampliar el contrato (§5) |
| **Accesibilidad** | Tarjetas grandes con etiqueta para lector de pantalla | Esperar y «elegir por mí» deben ser claros para quien no puede tocar |

### 1.3 «Elegir activa, dormir calma»: cómo mitigarlo

La tensión es real y no hay estudio que la zanje; se diseña para **minimizar la activación** y se **mide** (§6):

1. **Una sola pregunta por cuento**, entre el 30 % y el 60 % de las palabras. Nunca en el primer beat ni en los tres últimos: el descenso al cierre queda libre.
2. **Sin respuestas incorrectas ni puntos.** Las 3 ramas son seguras, igual de largas (±20 %) y llevan al mismo desenlace.
3. **Calma visual y sonora:** sin cuenta atrás, sin sonidos de acierto, sin animación en las tarjetas (con «reducir movimiento», ninguna). Solo un resplandor suave en la tarjeta que se nombra.
4. **«Elijo yo» siempre:** si nadie toca en ≈ 1 min, el motor elige (semilla aparte) y lo dice con voz tranquila. Un niño dormido no se encuentra una pantalla esperando.
5. **Temporizador de sueño armado ⇒ no se pregunta**: se elige solo, sin pausa. Quien arma la lunita quiere que el niño se duerma.
6. **Ajuste de adultos** (tras la pregunta de multiplicar): *Preguntas en el cuento* = «Preguntar» (por defecto en 6–8 y 9–12) / «Que elija la app» / «Nunca». Se guarda por niño (`ChildProfile` ya es una lista).
7. **Las ramas son lentas y sensoriales** (respirar, tocar, escuchar), no de acción; la rama «lunar» del ejemplo (§4) es literalmente una respiración.
8. **Voz de la pregunta a la velocidad del perfil** (0,90× en 6–8) y sin signos de exclamación en pregunta ni etiquetas.

### 1.4 Edades

| Perfil ([age.dart](../packages/caldero_engine/lib/src/age.dart)) | Palabras · minutos | ¿Elección? | Por qué |
|---|---|---|---|
| **2–3** | 150–300 · 2–3 | **No** | Una pausa de ≈ 1 min es un tercio del cuento; a esta edad el valor es la repetición y el ritual (el perfil se describe como «con repetición y final feliz enseguida»). Decisión de producto, sin fuente |
| **4–5** | 300–600 · 4–6 | **Sí, 2 opciones**, 1 pregunta, rama ≤ 60 palabras, solo concreta (dos dibujos, dos palabras) | Breede usó 2 opciones con 4–7 años; el cuento aún cabe en 6 min con la pausa. Hoy **no hay premisa 4–5 en `HEAD`**; en el árbol sin confirmar hay 6 (≈ 190–240 palabras, 1 variante por escena), p. ej. `sombras` («Las sombras del cuarto») tiene un sitio natural entre `respirar` y `mirar` |
| **6–8** | 600–1 200 · 6–10 | **Sí, 3 opciones**, 1 pregunta (2 si el cuento pasa de 900 palabras), rama ≤ 2 escenas | Es el estándar de los libros de elegir (2–3) y todo el pack actual es 6–8 |
| **9–12** | 1 200–2 000 · 10–15 | **Sí, 3 opciones**, hasta 2 preguntas | Aguantan más trama; aun así, un solo desenlace |

---

## 2. Estructura narrativa: patrones y cuál conviene

### 2.1 Los patrones

| Patrón | Qué es | Contenido a escribir | Riesgo |
|---|---|---|---|
| **Árbol puro** | Cada opción abre un tramo propio hasta su final | Crece ×3 por pregunta (3, 9, 27 finales) | Explosión; hay que escribir y revisar 3 moralejas distintas |
| **Diamante** (cuello de botella) | Las ramas duran 1–2 escenas y **vuelven al tronco común** | Solo las escenas de la rama | Las ramas cambian el *cómo*, no el *qué*; hay que repartir la sensación de elección |
| **Foldback** (Breede) | Ramas más largas que se reconectan en puntos distintos | Entre árbol y diamante | Reconexiones a mano; difícil de validar |
| **Estado / cualidades** (Short) | Etiquetas que se acumulan y desbloquean contenido más adelante | Una variante o una *frase* por consecuencia | Si se abusa, el número de combinaciones vuelve a explotar |

### 2.2 Coste con números (modelo: 10 escenas, 2 variantes por escena —la mediana del pack—, 3 opciones)

Reproducible con el script del Anexo B. «Variantes» es lo que hay que escribir (1 variante ≈ 70–100 palabras).

| Patrón | Escenas escritas | Variantes | × lineal | Finales distintos |
|---|---:|---:|---:|---:|
| Lineal (hoy) | 10 | 20 | 1,0 | 1 |
| Árbol, 1 pregunta tras la escena 5 | 20 | 40 | 2,0 | 3 |
| Árbol, 2 preguntas (tras 4 y 7) | 40 | 80 | 4,0 | 9 |
| Árbol, 3 preguntas (tras 3, 5, 7) | 108 | 216 | 10,8 | 27 |
| Diamante, 1 pregunta, rama de 2 escenas | 14 | 28 | 1,4 | 1 |
| Diamante, 2 preguntas, ramas de 2 escenas | 18 | 36 | 1,8 | 1 |
| **Diamante de 1 escena** (variantes cerradas por etiqueta) | **12** | **24** | **1,2** | 1 |

Con ramas de 1–2 escenas, el número de *textos distintos* es el mismo que el del árbol de 1 pregunta (3 072 combinaciones de
texto en el modelo), pero con **30–40 % menos de contenido** y una sola moraleja que garantizar. El árbol solo compra **finales
distintos**, justo lo que aquí no queremos (la enseñanza debe quedar intacta).

### 2.3 Con las premisas reales (`HEAD`, Anexo A)

Un «cuento de texto distinto» es una combinación de variantes elegibles para un reparto; hoy:

| Premisa | Escenas | Variantes | Palabras escritas* | Repartos | Textos distintos por reparto | Textos totales | Con 1 elección (rama de 2 variantes × 3) |
|---|---:|---:|---:|---:|---:|---:|---:|
| campana | 12 | 28 | 1 709 | 12 | 1 024 | 12 288 | 73 728 |
| olla | 11 | 26 | 1 910 | 12 | 4 608 | 55 296 | 331 776 |
| linterna | 11 | 28 | 2 001 | 12 | 1 152 | 13 824 | **82 944** |
| pozo | 11 | 31 | 1 759 | 6 | 17 496 | 104 976 | 629 856 |
| girasol | 10 | 21 | 1 185 | 6 | 256 | 1 536 | 9 216 |
| puente | 10 | 26 | 1 534 | 6 | 128 | 768 | 4 608 |

\* aproximación (Anexo A). El pack entero: 160 variantes y ≈ 10 100 palabras escritas; una premisa nueva cuesta de media ≈ 27 variantes
y ≈ 1 680 palabras, y **una elección completa del ejemplo de §4 cuesta +6 variantes y +405 palabras (+21 % de la premisa
`linterna`)**: ≈ ¼ de una premisa nueva a cambio de ×6 en textos distintos y 3 maneras de vivir la misma noche.

### 2.4 Recomendación

**Diamante de una escena con estado ligero**, con un tope de **una pregunta por cuento** (dos solo en 9–12):

* La pregunta cierra una escena; la **rama** es *una* escena nueva con 2 variantes por opción (o las variantes de una escena
  existente cerradas con `requires: ["camino:oido"]`).
* **Reconvergencia obligatoria** en la escena siguiente, con una frase de enlace que cada opción aporta (`says.llegada`), y **un eco
  barato** más adelante (`says.recuerdo`: una frase de ≈ 10 palabras por opción en vez de una variante de ≈ 80). Es «estado» sin
  explosión: cada eco cuesta 3 frases.
* **Ancla de moraleja:** todas las ramas añaden la misma etiqueta (`dio_el_paso`) y el clímax la **exige** (`requires`). Si una
  rama olvida el acto que sostiene la enseñanza, el motor no encuentra variante y el validador rechaza el pack.
* Árbol solo si algún día se quiere un cuento con finales distintos (otro producto: «aventura»), nunca con la enseñanza como final.

---

## 3. Diseño técnico sobre este motor

### 3.1 Esquema del pack (schema 2, extensión compatible)

Un beat puede llevar `choice`: **primero se cuenta el beat y luego se hace la pregunta**. Lo que el niño elige:

* añade la etiqueta `idElección:idOpción` (p. ej. `camino:oido`) al estado, más las `adds` de la opción;
* las variantes de beats posteriores la piden con `requires` (**mecanismo existente**);
* sus frases `says` quedan disponibles como `{camino.llegada}` en las escenas posteriores.

```jsonc
"choice": {
  "id": "camino",                        // id; no puede coincidir con una ranura del reparto
  "ask": "¿Cómo sigue {hero} en la oscuridad?",   // pregunta, con tokens; se lee en voz alta (≤ 120 car.)
  "talk": "Pregúntale: ¿cuál harías tú, y por qué?",  // opcional, para el adulto; solo se ve en la pantalla de texto
  "ages": ["6-8", "9-12"],               // opcional; sin él, las edades de la premisa. Fuera de ellas se elige sola
  "options": [                           // 2 o 3
    { "id": "oido",                      // → etiqueta camino:oido
      "label": "Seguir el beee",         // ≤ 28 car., sin puntuación, se lee tal cual
      "icon": { "art": "cabrita" },      // un dibujo del arte (id de rig) O un glifo de una lista cerrada; nunca emoji
      "adds": [],                        // etiquetas extra (opcional)
      "says": { "llegada": "…", "recuerdo": "…" } }   // frases para {camino.llegada}, {camino.recuerdo}
  ] }
```

* **Icono.** `art` reutiliza un rig del arte (`art/medieval/rigs/*.json`: ya existen `cabrita`, `roble`, `vela`, `buho`…); `glyph` es
  un nombre de **Material Icons** de una lista cerrada (la app ya los usa; licencia Apache 2.0), como `hourglass_bottom`. **No se
  usan emojis**: su aspecto cambia por teléfono y el normalizador de voz los borra (`normalizeForVoice` regla 1), así que no pueden ser
  la única pista.
* **Cómo lo valida `content/schema/pack-2.schema.json`.** Hoy el beat tiene `additionalProperties: false`, de modo que un pack con
  `choice` **se rechaza** (comprobado: «Additional properties are not allowed ('choice' was unexpected)»). Cambios, probados con
  `jsonschema` 4.26 contra el pack del §4 (0 errores) y contra el pack actual (0 errores):

```jsonc
// $defs.choice / $defs.option (nuevos) y beats.items.properties.choice: { "$ref": "#/$defs/choice" }
"choice": { "type": "object", "required": ["id","ask","options"], "additionalProperties": false,
  "properties": { "id": {"$ref": "#/$defs/id"}, "ask": {"type":"string","minLength":1,"maxLength":120},
                  "talk": {"type":"string","maxLength":100}, "ages": {"$ref": "#/…/ages"},
                  "options": {"type":"array","minItems":2,"maxItems":3,"items":{"$ref":"#/$defs/option"}} } },
"option": { "type": "object", "required": ["id","label","icon"], "additionalProperties": false,
  "properties": { "id": {"$ref": "#/$defs/id"},
    "label": {"type":"string","minLength":1,"maxLength":28,"pattern":"^[^.!?¿¡«»]+$"},
    "icon": {"oneOf": [ {"required":["art"],  "properties":{"art":  {"$ref":"#/$defs/id"}}, "additionalProperties":false},
                        {"required":["glyph"],"properties":{"glyph":{"enum":["hearing","touch_app","hourglass_bottom", "…"]}}, "additionalProperties":false} ]},
    "says": {"type":"object","propertyNames":{"$ref":"#/$defs/id"},"additionalProperties":{"type":"string","minLength":1}},
    "adds": {"type":"array","items":{"type":"string","pattern":"^[a-z][a-z0-9_]*(:[a-z][a-z0-9_]*)?$"}} } }
// pack.features (nuevo, opcional): {"type":"array","items":{"enum":["choice@1"]},"uniqueItems":true}
```

* **Lo que el esquema no puede decir** (lo comprueba `validatePack`, §3.4): que un `requires: ["camino:oido"]` apunte a una elección y
  opción que existen y vengan *antes*; que todas las opciones definan las mismas claves de `says`; que cada `{camino.x}` usado exista;
  que haya ≤ 1 elección en perfiles ≤ 8 y ≤ 2 en 9–12; el número de opciones según el perfil; la posición; el equilibrio de longitud.
* El patrón de `requires` del esquema (`^[a-z][a-z0-9_]*(:[a-z][a-z0-9_]*)?$`) **ya admite** `camino:oido`; no hay que tocarlo.
* **Compatibilidad.** Un motor viejo ignoraría `choice` y fallaría con «sin variante para …» (nadie añade `camino:*`). Por eso un pack
  que usa elecciones declara `"features": ["choice@1"]` en su bloque `pack` y `Pack.fromJson` rechaza *features* que no conoce, igual
  que hoy rechaza un `schema` que no entiende. Los packs sin `features` se leen igual que ahora.

### 3.2 Motor: determinismo, receta, «Contar otro cuento»

**El problema.** `StoryEngine.generate(StoryOptions)` devuelve un `Story` completo desde una semilla (mulberry32 de `rng.dart`). Con
una elección, la parte final **depende de una entrada del usuario**.

**Decisión.** La elección *no consume* el generador principal y las elecciones **forman parte de las opciones**:

```dart
class StoryOptions {                       // campos nuevos (los de siempre no cambian)
  /// Opciones ya elegidas, en orden de aparición: ['oido']. Las que falten las elige el motor con una semilla
  /// aparte (auto = true). Así `generate` sigue devolviendo siempre un cuento completo y determinista.
  final List<String> choices;              // por defecto const []
  /// false = nunca preguntar (perfil 2–3, ajuste «nunca», temporizador de sueño): todo se elige solo.
  final bool interactive;                  // por defecto true
}

/// Un cuento a medias: lo contado y, si toca, la pregunta pendiente. Inmutable.
class StoryRun {
  List<StoryScene> get scenes;             // prefijo ya resuelto; la última lleva `choice` si hay pregunta
  StoryChoice? get pending;                // null = completo
  bool get isComplete => pending == null;
  StoryRun choose(String optionId, {bool auto = false});
  Story toStory();                         // exige isComplete (o completa eligiendo solo)
}
// StoryEngine.begin(StoryOptions) → StoryRun;  generate(o) == begin(o).toStory()
```

* **Implementación sin guardar estado:** `choose` vuelve a generar desde la semilla con la lista de elegidas + la nueva y se detiene en
  la siguiente pregunta. Las escenas anteriores a la pregunta son idénticas porque **no dependen de la elección**; las posteriores
  usan el mismo generador, de modo que `(semilla, enseñanza, edad, elecciones)` ⇒ mismo cuento. Cuesta ≤ 12 escenas de render.
* **«Elijo yo»:** la opción automática sale de `Mulberry32((seed + 0x9E3779B9 · (i + 1)) & 0xFFFFFFFF)` con `i` = nº de elección:
  una secuencia aparte, así elegir (o no) no cambia las variantes de las escenas anteriores.
* **Regresión:** una premisa sin `choice` consume el generador exactamente igual que ahora. Prueba dorada: para 3 000 semillas × 6
  premisas, `recipe.fragmentIds` idéntico al del motor 0.2.0. `engineVersion` sube a `0.3.0` ([recipe.dart](../packages/caldero_engine/lib/src/recipe.dart)).
* **Modelos Dart** (nombres propuestos; `Story`, `StoryScene`, `StoryRecipe`, `Beat` y `Premise` ya existen en `models.dart`/`recipe.dart`):

```dart
class ChoiceIcon   { /* art(String rig) | glyph(String nombre de Material Icons) */ }
class ChoiceOption { final String id, label; final ChoiceIcon icon;
                     final List<String> adds; final Map<String, String> says; }
class Choice       { final String id, ask; final String? talk; final List<String> ages; final List<ChoiceOption> options; }
class Beat         { /* + */ final Choice? choice; }          // se pregunta DESPUÉS de contar el beat
class StoryChoice  { final String id, ask; final String? talk; final List<ChoiceOption> options; }  // `ask` ya con tokens resueltos
class StoryScene   { /* + */ final String? beatId; final StoryChoice? choice; }
class ChosenOption { final String choiceId, optionId; final bool auto; }   // id en la receta: '<premisa>.<elección>.<opción>'
class Story        { /* + */ final List<ChosenOption> choices; }
class StoryRecipe  { /* + */ final List<ChosenOption> choices; } // toJson: 'choices': [{'id': 'linterna.camino.oido', 'auto': false}]
                                                                   // solo si no está vacía → los eventos viejos no cambian
```

  `renderTemplate` gana un parámetro `says` (elecciones ya hechas → opción → frases): `{camino.llegada}` se resuelve ahí cuando
  `camino` no es una ranura del reparto; la frase se renderiza antes con el mismo reparto (un nivel, sin anidar elecciones).
* **Repetir el cuento igual.** La receta guarda `choices` en orden; con `seed`, `value`, `cast` y `fragments` se reconstruye el cuento
  exacto. Antes de la pregunta no hay nada que guardar.
* **«Contar otro cuento»** (`StoryPage._another`): semilla nueva, `StoryRun` nuevo, elecciones vacías (pertenecían al cuento anterior). `onAnother` pasa de `Story Function()` a `StoryRun Function()`.
* **«Mis cuentos» y «Oír otra vez»** (`ShelfEntry`, hoy `packId:seed:option`): se añade `choices` (solo en el teléfono) y la clave los incluye. Abrir un cuento guardado lo cuenta **igual, sin preguntar** (`interactive: false` con las elecciones guardadas). «Probar otro camino» (Fase 2): vuelve a la pregunta con la misma semilla y guarda otra entrada; es un extra de día, no de noche.
* **Un beat = una escena, siempre** (restricción de la v1): las ramas son variantes del mismo beat o beats añadidos que existen en todos los caminos. Así `recipe.fragmentIds` sigue teniendo la longitud de `premise.beats` y `_checkStory` puede seguir usando `premise.beats[i]` para la escena `i`. Si algún día una rama necesita escenas propias, se añade `when` al beat y se usa `StoryScene.beatId` en lugar del índice.

### 3.3 Reproductor y pantallas

**`StoryPlayback`** ([playback.dart](../app/lib/src/narration/playback.dart)) recibe la escena con pregunta y un `resolve` que le devuelve el resto del cuento:

```dart
class PlayOption { final String id, label; final ChoiceIcon icon; }
class PlayChoice { final String id, ask; final List<PlayOption> options; }
class PlayScene  { /* + */ final PlayChoice? choice; }

StoryPlayback({ …,
  this.resolve,                                     // Future<List<PlayScene>> Function(String optionId, {required bool auto})
  this.firstWait  = const Duration(seconds: 20),
  this.secondWait = const Duration(seconds: 15) });
PlayChoice? get asking;       int? get speakingOption;   void choose(String optionId);
```

En `_loop`, al acabar las frases de una escena con `choice` (y antes de `_breathe`), `await _ask(run, choice)`; si `!_alive(run)` se
sale sin elegir (pausa, salto, cierre o temporizador **cancelan sin elegir** y al reanudar se vuelve a preguntar). Al volver con la
opción, `scenes.removeRange(_scene + 1, scenes.length)` y `scenes.addAll(await resolve(...))` (la lista pasa a ser mutable; la
enseñanza final sigue siendo la última). `previous`/`next` funcionan igual; `next` sobre la pregunta la lanza, no la salta.

**Tiempos (modo cine, perfil 6–8, 99 palabras/min = 110 × 0,90):**

| Momento | Qué pasa |
|---|---|
| Fin de la última frase | respiro de 0,7 s (`gap` actual) y aparecen las 3 tarjetas |
| 0–12 s | la voz dice la pregunta y las etiquetas («¿Cómo sigue Aldo en la oscuridad? Seguir el beee. Ir de tronco en tronco. Esperar y respirar»: 17 palabras ≈ 10 s, más las pausas ≈ 12 s); cada tarjeta se ilumina al nombrarla. Todo pasa por `normalizeForVoice` |
| +20 s sin toque | repite solo las etiquetas (≈ 8 s) |
| +15 s sin toque | «Esta vez elijo yo.» → `resolve(id, auto: true)`; la tarjeta elegida se ilumina 2 s |
| Máximo | ≈ 57 s. Con temporizador de sueño armado, 0 s (se elige sola, sin pausa) |

**Cine** ([cinema_page.dart](../app/lib/src/cinema_page.dart)): las tarjetas sustituyen a los subtítulos mientras se pregunta (≥ 96 dp de lado, icono de 48 dp, texto grande; `Semantics(button, label: 'Opción 1 de 3: Seguir el beee')`). La barra de progreso usa `premise.beats.length + 1` como total (hoy `scenes.length`, que crecería). Sin cuenta atrás.

**Holograma** ([hologram_page.dart](../app/lib/src/hologram_page.dart)): no hay texto y los controles se ocultan solos. Durante la pregunta `_controls` se fuerza a visible y las tarjetas (icono + etiqueta) van en la barra inferior; la voz es la misma. La geometría del prisma (cuñas de 90°, [15](15-modo-cine-y-holograma.md)) **no se ha probado con un prisma real**, así que en la Fase 0 el holograma **elige solo** (`interactive: false`) y la pregunta no llega a mostrarse; en la Fase 1 se habilita tras probar con familias.

**Temporizador de sueño** ([sleep_timer.dart](../app/lib/src/ui/sleep_timer.dart)): hoy el botón guarda su propio estado y la página solo recibe `onExpire`/`onPicked`. Se añade un `ValueNotifier<bool> armed` (o `onPicked(int? minutes)`) para que la página cree el `StoryRun` con `interactive: !armed`. Si vence mientras se pregunta, `pause()` cancela la espera y no elige nada.

**Pantalla de texto** ([story_page.dart](../app/lib/src/story_page.dart)): hoy pinta `_story.scenes` en un `ListView`. Con un `ValueNotifier<StoryRun>` compartido con cine y holograma (para que lo elegido en uno se vea en los otros), la lista pinta las escenas del `run` y, al final, un bloque «pregunta + 3 tarjetas + `talk` en letra pequeña + botón “Elige por nosotros”». **Sin espera automática** (el adulto manda). Al tocar, el bloque se pliega en una línea («Elegisteis: Seguir el beee»), las escenas nuevas aparecen debajo y se desplaza hasta ellas. La enseñanza y la ficha de valoración solo salen cuando `run.isComplete` (la valoración necesita la receta con `choices`).

### 3.4 Validador: todas las rutas sin explosión

Cambios en `validator.dart` (nombres de funciones reales):

* `_checkPremise`: las `requires` con `prefijo:valor` hoy se toman como ranura del reparto; ahora el prefijo también puede ser una **elección declarada antes**. Las etiquetas de cada opción (`camino:oido` + sus `adds`) entran en `addedBefore` **después** del beat que pregunta. Además, el filtro `castReqs` que decide qué variantes se renderizan por reparto (`r.contains(':')`) debe limitarse a prefijos que sean ranuras; si no, las variantes de rama **se saltarían** sin revisarse.
* Reglas nuevas (errores): id de elección distinto de toda ranura; 2–3 opciones y ≤ el máximo del perfil; etiqueta ≤ 28 caracteres y sin `voiceIssues`; icono: glifo en la lista cerrada (el `art` se comprueba en la app, igual que `story_stage_test.dart` comprueba hoy hora y estación); no en el primer beat ni en los 3 últimos; posición entre el 30 % y el 60 % de las palabras; todas las opciones definen las mismas claves `says`; todo `{camino.x}` usado existe y está **después** de la pregunta; **ancla**: existe una etiqueta que añaden todas las variantes de todas las ramas y que un beat posterior exige.
* `_checkStory` se ejecuta hoy sobre cuentos generados con `generate(StoryOptions(seed, valueId))` y filtra por premisa. Con elecciones, solo vería la ruta que la semilla eligiera, así que se añade `_checkPaths`, **polinómico**, para cada reparto × cada combinación de opciones:

| Regla | Cómo se comprueba sin enumerar los cuentos | ¿Exacto? |
|---|---|---|
| Cada escena tiene alguna variante elegible | Por escena, con el estado de la ruta (36 combinaciones en `linterna`: 12 repartos × 3 opciones) | Sí |
| Gramática, `scene`, hora/estación, rasgos, texto↔dibujo ([16](16-coherencia-texto-imagen.md)) | Por variante × reparto × opción (`says`), como hoy `_checkRender` + `_checkSetting` | Sí |
| Nadie nombrado antes de presentarse; el presentado se nombra | Por escena: unión de los nombres que **alguna** variante elegible menciona (no antes) e intersección de los que **todas** mencionan (en la escena que presenta) | Sí |
| Longitud (mínimo/máximo del perfil; `storyWordLimits`, aún sin confirmar en el árbol) | Suma de los mínimos y de los máximos de palabras por escena | Sí |
| ≥ 3 causales, ≥ 2 citas, héroe en ≥ 70 % de las escenas, cierre nombra al héroe | Cota inferior = suma de lo que **todas** las variantes de cada escena garantizan; si no basta, se busca un cuento **testigo** y se imprime su semilla | Suficiente; el testigo evita falsas alarmas |
| Cambio de lugar sin `moves` | Programación dinámica sobre «fondo anterior posible» entre escenas consecutivas | Sí |
| Equilibrio de ramas | Media de palabras de cada opción dentro de ±20 % de las demás | Sí |
| Cobertura de azar | 200 cuentos aleatorios por ruta, como hoy (`seeds * 8`) | Muestreo |

**Por qué hace falta.** Enumerar todos los cuentos de texto distintos (§2.3) sería de 13 824 en `linterna` hoy, 82 944 con la elección,
y **629 856** en `pozo` si lo tuviera; crece por cada pregunta ×(opciones × variantes de rama). Las comprobaciones de arriba son
lineales en escenas × variantes × rutas (≈ 11 × 4 × 36 en `linterna`). `validate_pack` imprimirá «rutas: N» y admite `--exhaustive`
(tope de 200 000 cuentos por premisa) para una pasada nocturna. No medí tiempos (sin Dart).

### 3.5 Límites por perfil (nuevos campos de `AgeProfile`)

| Perfil | `maxChoices` | `maxOptions` | Rama máxima | Dónde |
|---|---:|---:|---|---|
| 2–3 | 0 | — | — | Nunca |
| 4–5 | 1 | 2 | 1 escena, ≤ 60 palabras por variante | 30–60 % del texto |
| 6–8 | 1 (2 si > 900 palabras) | 3 | 2 escenas | 30–60 % |
| 9–12 | 2 | 3 | 2 escenas | 25–65 %, separadas ≥ 3 escenas |

Las cifras de palabras y minutos son las de [age.dart](../packages/caldero_engine/lib/src/age.dart). Una pregunta añade de 0,2 a 1 min de reloj
(≈ 12 s de voz + espera), y la rama no debe alargar el cuento: **al añadir la elección de §4, la premisa `linterna` pasa de ≈ 829–933
a ≈ 906–1 019 palabras** (≈ 9,2–10,3 min a 99 palabras/min, en el límite de 6–10 del perfil). Con el tope fijo de `HEAD`
(`maxStoryWords = 950`) el validador la rechazaría; en el árbol sin confirmar el tope ya es por perfil (6–8: 510–1 380). Aun así,
conviene **recortar ≈ 70 palabras** (p. ej. `las_sombras`) para que la elección no alargue la noche.

---

## 4. Contenido de ejemplo: «La linterna apagada», valentía, 6–8

**Dónde.** Premisa `linterna`, beat `se_apaga` (el viento apaga la lucecita en mitad del bosque). Hoy el beat termina decidiendo por el
niño («Dio un paso… Siguió hacia el beee»). Pasa a terminar en una pregunta con **tres pistas ya plantadas** en el texto (un *beee*, un
tronco de musgo, una rendija de cielo), y una escena nueva `en_la_oscuridad` cuenta lo que ocurre según el camino. Se reconverge en
`el_roble` y se hace un eco en `cierre`. *Valentía* intacta: en las tres ramas hay miedo y **un paso**, y el clímax (`la_chispa`) exige
la etiqueta `dio_el_paso` que solo añaden las ramas. Es **significativa** porque cambia qué ocurre (guiarse por el oído, por el
tacto o esperar a que salga la luna), cómo se ve (oscuridad total en dos ramas; en la tercera sale la luna y el sendero se ilumina; otro
gesto del héroe en cada una) y cómo se recuerda (el cierre cita lo que cada niño vivió). **No** cambia quién gana ni el desenlace: es
a propósito (§2.4).

```jsonc
// ── 1. Beat que pregunta (premisa "linterna"). Se cambian las 3 variantes: terminan en «… Tenía que seguir. Pero ¿cómo?»
{ "id": "se_apaga",
  "choice": {
    "id": "camino",
    "ask": "¿Cómo sigue {hero} en la oscuridad?",
    "talk": "Pregúntale: ¿cuál de las tres cosas harías tú, y por qué?",
    "options": [
      { "id": "oido", "label": "Seguir el beee", "icon": {"art": "cabrita"},
        "says": { "llegada": "El «beee» sonó ya muy cerca, y las manos de {hero} toparon con una corteza enorme: el roble viejo.",
                  "recuerdo": "una cabrita que dice beee" } },
      { "id": "tacto", "label": "Ir de tronco en tronco", "icon": {"art": "roble"},
        "says": { "llegada": "El último tronco era tan ancho que {hero} no podía abrazarlo entero: era el roble viejo.",
                  "recuerdo": "troncos de musgo blandito para agarrarse" } },
      { "id": "luna", "label": "Esperar y respirar", "icon": {"glyph": "hourglass_bottom"},
        "says": { "llegada": "Siguiendo el camino de plata, {hero} llegó al pie del roble viejo.",
                  "recuerdo": "una luna que siempre sale, aunque tarde" } }
    ] },
  "variants": [
    { "id": "a", "scene": {"time": "noche", "light": "dark", "bg": "bosque", "mood": "mystery", "stage": [{"who": "hero", "clip": "sneak", "x": 0.45}], "props": [{"prop": "pedernal", "near": "hero", "dx": 0.06, "lift": 40, "scale": 0.35}], "rope": {"from": "hero", "to": "left", "sag": 12}, "offstage": ["lia"]},
      "text": "De pronto llegó una ráfaga: ¡fuuu! La lucecita se apagó. Oscuridad entera, como cuando uno cierra los ojos dentro de un armario. {hero} golpeó el pedernal, una vez, otra: con tanto viento no prendía ni una chispa. Se agarró a un tronco, rugoso y blando de musgo, y tiró una vez de la cuerda. Muy lejos, un tirón pequeño contestó. Entonces sonó un «¡beee!» chiquitito, más allá del roble viejo. Arriba, entre dos nubes, quedaba una rendija de cielo. {hero} pensó en Lía, sola, y {helper.truco}. Tenía que seguir. Pero ¿cómo?" }
    // b y c: mismo final (se quitan «Dio un paso. Luego otro. Siguió hacia el beee.» y equivalentes)
  ] }

// ── 2. Escena nueva: la rama (2 variantes por opción). Todas añaden la misma «ancla» de la moraleja
{ "id": "en_la_oscuridad", "variants": [
  { "id": "oido_a", "requires": ["camino:oido"], "adds": ["dio_el_paso"],
    "scene": {"bg": "bosque", "time": "noche", "light": "dark", "mood": "mystery", "stage": [{"who": "hero", "clip": "think", "x": 0.4}], "props": [{"prop": "roble", "x": 0.85, "scale": 1.5}], "rope": {"from": "hero", "to": "left", "sag": 12}},
    "text": "{hero} cerró los ojos, que total no servían de nada, y abrió las orejas. El viento hacía ¡fuuu!, las hojas hacían ¡suish!, y debajo de todo, chiquitito y terco, estaba el «¡beee!». Cada vez que el viento se llevaba el sonido, {hero} se paraba a esperar que volviera. «Voy», susurraba. Y así, de beee en beee, con las manos por delante, fue avanzando entre los árboles." },
  { "id": "oido_b", "requires": ["camino:oido"], "adds": ["dio_el_paso"],   // misma "scene" que oido_a, con x: 0.45
    "text": "Primero {hero} no oyó nada, solo su propio corazón: ¡pum, pum, pum! Entonces contuvo la respiración. Allí estaba, hacia el roble viejo: «¡Beee!». {hero} dio tres pasos hacia el sonido. Silencio. Se quedó quiet{hero.o} y esperó, y el «beee» volvió a llamar, un poquito más cerca. «Ya voy», susurró. Era como seguir un hilo de sonido en la oscuridad, y el hilo no se rompió." },
  { "id": "tacto_a", "requires": ["camino:tacto"], "adds": ["dio_el_paso"],
    "scene": {"bg": "bosque", "time": "noche", "light": "dark", "mood": "mystery", "stage": [{"who": "hero", "clip": "sneak", "x": 0.5}], "props": [{"prop": "roble", "x": 0.85, "scale": 1.5}], "rope": {"from": "hero", "to": "left", "sag": 12}},
    "text": "{hero} estiró la mano y encontró un tronco, fresco y blando de musgo. Entonces fue de tronco en tronco, como quien sube una escalera a oscuras: este, rugoso como un gato viejo; aquel, liso como una cuchara; otro, con la corteza en gajos como un abrigo grande. La cuerda se arrastraba detrás con un susurro. Con la palma sobre la corteza, {hero} se sintió acompañad{hero.o} por los árboles." },
  { "id": "tacto_b", "requires": ["camino:tacto"], "adds": ["dio_el_paso"],   // misma "scene" que tacto_a
    "text": "A {hero} le costaba creer que un bosque tan oscuro tuviera tantas cosas que tocar. Palpó una piedra fría y redonda, una hoja grande como un plato y un hongo blandito como un cojín. Siempre dejaba una mano en el último tronco antes de soltarla para buscar el siguiente. «Tronco, tronco, tronco», iba diciendo, muy bajito. Los dedos sabían el camino mejor que los ojos." },
  { "id": "luna_a", "requires": ["camino:luna"], "adds": ["dio_el_paso"],
    "scene": {"bg": "bosque", "time": "noche", "mood": "hope", "stage": [{"who": "hero", "clip": "idle", "x": 0.4}], "props": [{"prop": "roble", "x": 0.85, "scale": 1.5}], "rope": {"from": "hero", "to": "left", "sag": 12}},
    "text": "{hero} respiró hondo y no hizo nada. Solo esperó. Contó hasta diez, despacito: uno, dos, tres… Poco a poco, la oscuridad dejó de ser una pared y se volvió un montón de cosas grises: troncos, ramas, un caminito pálido. Entonces el viento empujó las nubes, y por la rendija asomó la luna. El sendero se encendió de plata hasta el roble viejo. «Estaba aquí todo el tiempo», pensó {hero}. Dio un paso. Luego otro." },
  { "id": "luna_b", "requires": ["camino:luna"], "adds": ["dio_el_paso"],   // misma "scene" que luna_a
    "text": "{hero} apoyó la espalda en un tronco y respiró: dentro, uno, dos; fuera, uno, dos. El corazón, ¡pum, pum!, fue bajando el ruido, como un tambor que se va a dormir. Los ojos se acostumbraron. Vio el contorno de las ramas y, más lejos, la sombra gorda del roble viejo. Entonces la luna se asomó entre dos nubes y le puso a cada hoja un borde de plata. «Un paso», dijo {hero}. «Y otro.»" }
] }

// ── 3. Reconvergencia: el beat "el_roble" (4 variantes: cod, som, cod_b, som_b) empieza con la frase de enlace de la opción
{ "id": "cod", "requires": ["villain:codicio"],
  "text": "{camino.llegada} Algo se movió en el hueco del tronco. «¡Atrás!», gruñó una voz. Era {villain.el} {villain}, que había aprovechado el viento para esconder allí {villain.botin}. No quería que ninguna luz lo descubriera. «¡Vuelve a casa!», amenazó entre dientes. {hero} no veía nada, pero tenía clarísimo lo que quería. «Lía necesita la luz, porque está perdida», dijo. «No me voy.»" }
// som, cod_b, som_b: se sustituye su primera cláusula («En el roble viejo, algo…», «Al pie del roble viejo, alguien…», …) por {camino.llegada}

// ── 4. Guardia de moraleja: el clímax exige la etiqueta que añaden todas las ramas (las 2 variantes de "la_chispa")
{ "id": "la_chispa", "variants": [ { "id": "a", "requires": ["dio_el_paso"], … }, { "id": "b", "requires": ["dio_el_paso"], … } ] }

// ── 5. Eco barato: "cierre", variante a (en la b, la misma idea)
"…La oscuridad seguía allí, pero ya la conocía: tenía un búho de ojos amarillos, ramas que bailan y {camino.recuerdo}. A {hero} le pareció casi simpática…"
```

**Comprobado con scripts** (Anexo B; Python, no el validador de Dart):

| Comprobación | Resultado |
|---|---|
| Esquema propuesto (§3.1) contra el pack con la elección | 0 errores. El esquema actual lo rechaza por `choice` |
| Variantes y palabras de la premisa | 28 → 34 variantes (+6); 2 001 → 2 406 palabras escritas (+405, +20 %) |
| Palabras por rama (cada `{token}` = 1) | oído 66 y 65 · tacto 68 y 65 · luna 74 y 74 (medias 66 / 66 / 74: ramas dentro de ±12 %) |
| Cobertura: 12 repartos × 3 opciones | 0 escenas sin variante elegible; la etiqueta `dio_el_paso` llega al clímax por las 3 ramas |
| Textos distintos | 13 824 → **82 944** (×6) |
| Longitud aprox. de cualquier ruta | 906–1 019 palabras (antes 829–933): ver §3.5 |

**Posición:** la pregunta cae al 59 % del texto (media por escena) y quedan 5 escenas después, dentro de las reglas de §3.4.

**Lo que la validación de Dart tendrá que confirmar:** que «la luna» en la rama lunar (sin `light: dark`) cuadra con `_checkSetting` (el texto
dice «luna» y la hora es `noche`, que es lo que exige); que `Lía` solo se nombra donde `offstage: ["lia"]` (solo en `se_apaga`); que
«beee» pasa el normalizador de voz como etiqueta; y que `{hero.o}` evita el género fijo (`_fixedGender`).

**Para 4–5 (esbozo, sin escribir):** `sombras` (cuento sin confirmar, 6 escenas, ≈ 193 palabras) podría preguntar tras `respirar`:
«¿Qué hace {hero}?» con 2 opciones («Asomar un ojo» / «Encender la vela») y una rama de 1 escena de ≈ 35 palabras: +2 variantes
(+70 palabras escritas, ≈ +36 %) y el cuento pasa de ≈ 193 a ≈ 228 palabras (el perfil 4–5 pide 300–600; esa carencia es del pack sin confirmar, no de la elección).
Proporcionalmente es caro en un cuento tan corto: no empezar por aquí.

---

## 5. Privacidad y valoraciones

**Qué puede viajar** (misma clase de dato que `seed`, `cast` y `fragments`, [12 §2](12-valoraciones-y-mejora-continua.md)):

```jsonc
"recipe": { …, "fragments": ["linterna.la_luz.a", …],
            "choices": [ { "id": "linterna.camino.oido", "auto": false } ] }    // opcional; omitido si no hubo elección
```

| Sí | No (nunca) |
|---|---|
| Id de la opción `premisa.elección.opción` (código fijo del pack) | Etiqueta, pregunta o frases `says` (texto) |
| `auto`: `true` si eligió la app (por espera, temporizador o ajuste), `false` si tocó el niño | Cuánto tardó, qué tarjeta tocó antes, cuántas veces repitió, si había temporizador de sueño |
| | Nombre del niño (`heroName` ya “nunca viaja en la receta”), edad, voz, hora |

* **OpenAPI** ([feedback.openapi.yaml](api/feedback.openapi.yaml)): `Recipe.choices`, opcional (`maxItems: 2`, cada objeto con
  `additionalProperties: false`, `id` con el mismo patrón que `fragments`, `auto` booleano). `required` no cambia, así que **las
  versiones antiguas de la app siguen siendo válidas**. Se actualizan `rating-event*.json`, la prueba de contrato de Dart y
  `tools/feedback/test_contract.py` (que ya rechaza campos de más). El servidor comprueba que la opción exista **en esa versión del
  pack** (como ya hace con los fragmentos). La tabla de [12 §8](12-valoraciones-y-mejora-continua.md) gana `choice_ids text[]` y
  `choice_auto boolean[]`.
* **Decisión D5 (a confirmar):** `auto` describe cómo se generó el cuento, no la conducta de la familia, pero mezcla «se durmió»,
  «no quiso» y «lo desactivó el adulto». Si preocupa, se envía solo el id y el análisis pierde la mitad de la señal.
* **Sesgo de selección** (lo más fino): [12 §6](12-valoraciones-y-mejora-continua.md) supone que el motor elige al azar entre
  alternativas y por eso la regresión separa el efecto de cada fragmento. **Entre ramas ya no es así**: elige el niño, y quizá el
  que elige «esperar» es el que ya estaba más tranquilo. Reglas: (1) `option` entra en la regresión como efecto propio; (2) las
  *variantes dentro de una rama* siguen eligiéndose al azar, así que sus efectos siguen siendo comparables; (3) la diferencia
  *entre ramas* solo se declara con las filas `auto: true` (aleatorias por semilla) y ≥ 1 000 notas; (4) nunca se baja el peso de
  una opción entera por datos observacionales.
* **Abandono (D3):** no se registra y esta función no lo necesita (sus indicadores se obtienen de la receta, §6).

---

## 6. Plan por fases, éxito y riesgos

Esfuerzo **relativo** (1 punto ≈ una persona-semana; estimación mía, sin medir en este equipo):

| Fase | Alcance | Puntos |
|---|---|---:|
| **0 · Prototipo mínimo** | 1 elección en `linterna` (el §4, con el recorte de ≈ 70 palabras). Motor: `Choice`, `StoryRun`, `StoryOptions.choices/interactive`, receta, prueba dorada. Esquema + reglas mínimas del validador (§3.4: tags, ancla, claves de `says`). `StoryPage` (texto, sin espera) y cine con voz y glifos de Material (sin dibujos). Holograma: elige solo. Ajuste «Preguntas en el cuento». Se prueba en 5–10 familias 6–8, **de noche y con la voz** | 2 |
| **1 · Cine/holograma y todas las rutas** | `_checkPaths` completo (§3.4); iconos con arte (`cabrita`, `roble`…); holograma con tarjetas en la barra; integración con el temporizador de sueño; `choices` en la receta/OpenAPI/Python; `ShelfEntry.choices`; análisis con `option` y filas `auto`; accesibilidad a 1,3× | 3 |
| **2 · Autoría y escala** | Panel (B2 de [09](09-backend-y-panel-admin.md)): editor de la elección con vista previa de las 3 rutas (el motor compilado a JS ya se planea para validar); 2–3 premisas más con elección (≈ +400 palabras cada una); versión de 2 opciones para 4–5; «Probar otro camino» | 3 + contenido |

**Criterios de éxito** (medibles con los datos de [12](12-valoraciones-y-mejora-continua.md) y sin reabrir D3):

| Indicador | Cómo se mide | Umbral para generalizar |
|---|---|---|
| Valoración media con vs. sin elección | `rating` agrupado por `recipe.choices` presente (premisas alternadas por peso) | No peor que −0,10 con ≥ 500 por grupo. Con σ = 0,9 (supuesto de la simulación de 12) el error típico de la diferencia es ≈ 0,06, o sea ±0,11 al 95 %. Objetivo: ≥ +0,10 |
| Motivos `scary` y `no_sense` en notas ≤ 3 | Proporción por grupo | No más de +3 puntos porcentuales sobre «sin elección» |
| Elecciones hechas por el niño | `auto == false` ÷ total | ≥ 70 % en cine; < 50 % significa que la pausa estorba o llega cuando ya duermen |
| Cuentos terminados (proxy, porque D3 impide medir el abandono) | Cuota de valoraciones de premisas con elección ÷ la cuota esperada según los pesos de las premisas | ≥ 0,8 (si baja, o se abandona más o se valora menos) |
| Pregunta a las familias de la prueba (cualitativa) | «¿Tardó más o menos en dormirse que sin preguntas?» | ≥ 70 % «igual o menos»; ≤ 20 % «más agitado» |

**Riesgos:** (1) **sueño**: sin estudio que lo respalde; mitigado por diseño (§1.3) y medido en la Fase 0. (2) **Coste editorial**: cada
elección es una rama más que revisar con la rúbrica de [14](14-rubrica-editorial.md), por tres. (3) **Longitud**: sin el recorte
de §3.5 la elección alarga la noche. (4) **Holograma sin probar**. (5) **Sesgo** en la mejora continua (§5). (6) **Deriva hacia el
juego**: si se piden más preguntas, puntos o finales, se pierde la misión; el tope de 1 pregunta es una decisión, no un límite técnico.

**Qué haría que NO valga la pena** (se decide tras la Fase 0):

* La valoración media con elección cae más de 0,15 o aumentan `scary`/`no_sense` (§6).
* Más del 30 % de las familias dicen que el niño se agita o tarda más en dormirse.
* Más de la mitad de las elecciones salen con `auto: true`: nadie la usa.
* Cada elección cuesta más de ≈ 1/3 de una premisa nueva en revisión editorial (el ejemplo cuesta ≈ ¼): sería mejor escribir premisas.
* El holograma, que es un diferenciador del producto, exige una interacción que no se puede hacer bien con el prisma (entonces
  elección solo en texto y cine).

---

## 7. Recomendación final

1. **Hacerlo, pero como experimento acotado:** una sola pregunta por cuento, tres ramas de una escena que reconvergen en el mismo desenlace.
2. **Cuándo:** ahora la Fase 0 (≈ 2 semanas de una persona, sin servidor); la Fase 1 solo si la prueba con familias de noche no empeora el sueño ni la nota.
3. **Alcance mínimo:** solo `linterna` (6–8), texto + voz en cine, holograma eligiendo solo, ajuste de adultos, temporizador de sueño ⇒ no se pregunta y «elijo yo» al minuto.
4. **Edades:** 2–3 nunca; 4–5 con 2 opciones cuando haya premisa y datos; 6–8 con 3; 9–12 hasta 2 preguntas.
5. **Condiciones de salida:** valoración no peor que −0,10, motivos de susto/sin sentido sin subir y ≥ 70 % de elecciones hechas por el niño; si no, se retira y se invierte en premisas nuevas.

---

## Anexo A · Contar variantes, palabras y cuentos distintos (reproducible)

```python
# python3 contar.py   (desde la raíz del repositorio; sirve con cualquier pack de esquema 2)
import json, re, itertools
p = json.load(open('content/packs/medieval/pack.json'))
chars = {c['id']: c for c in p['characters']}
def palabras(t):                       # aproximación: [[a|b]] → a ; cada {token} → 1 palabra
    t = re.sub(r'\[\[([^\]|]*)(\|[^\]]*)*\]\]', r'\1', t); t = re.sub(r'\{[^}]*\}', 'XX', t)
    return len(re.findall(r'[\wáéíóúüñÁÉÍÓÚÜÑ]+', t))
for pr in p['premises']:
    slots = [k for k, v in pr['cast'].items() if v['kind'] == 'character']
    cand = {k: [c for c in chars if any(r in chars[c]['roles'] for r in pr['cast'][k]['roles'])] for k in slots}
    repartos = [t for t in itertools.product(*[cand[k] for k in slots]) if len(set(t)) == len(t)]
    total = 0
    for t in repartos:
        estado = {f'{k}:{c}' for k, c in zip(slots, t)}
        n = 1
        for b in pr['beats']:
            n *= sum(all(r in estado for r in v.get('requires', [])) for v in b['variants'])
        total += n
    print(pr['id'], len(pr['beats']), sum(len(b['variants']) for b in pr['beats']),
          sum(palabras(v['text']) for b in pr['beats'] for v in b['variants']), len(repartos), total // len(repartos), total)
```

## Anexo B · Cómo se comprobó el ejemplo y el modelo de costes

* **Modelo de §2.2:** N = 10 escenas, V = 2 variantes, 3 opciones; árbol = escenas del tronco + 3 × tramos de cada rama; diamante =
  N − k·m + k·3·m escenas (k preguntas, m escenas por rama). Salidas: 20 / 40 / 80 / 216 / 28 / 36 / 24 variantes.
* **Ejemplo de §4:** se insertó la elección en una copia del pack (fuera del repositorio), se validó con `jsonschema` 4.26 contra el
  esquema actual **más** los cambios de §3.1, y se emularon en Python la elegibilidad de variantes por `requires`/`adds` para los
  12 repartos × 3 opciones, el rango de palabras por ruta (suma de mínimos y de máximos por escena) y el número de textos distintos.
  Esto **no sustituye** a `validatePack` ni a `audit_stories`, que habrá que ejecutar en cuanto exista el código.
* **Fuentes abiertas** (§1.1): Takacs y otros 2015 (PDF completo leído en abstract, introducción y tabla de estudios); Pillinger y Vardy
  2022 (ficha del repositorio); WWC 2010 (PDF); Wikipedia *Choose Your Own Adventure*; Breede 2021; Short 2016; fichas de tienda de
  TellieTales y Taleverse. El intento de abrir la ficha de PubMed del estudio de Dworak y otros (2007) sobre
  videojuegos y sueño no devolvió el resumen, así que no se cita.
