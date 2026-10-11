# 18 · Voz, edades y wizard de primer uso

Implementa lo que se pudo de la especificación «Narración, edades y wizard del app de cuentos» (documento compartido,
2026‑10‑10). Lo que necesita servidor, cuentas o datos con licencia queda anotado al final con su motivo.

## 1. El bug: «al adelantar la voz se pierde y no vuelve»

La especificación lo daba como hipótesis sin ver el código. Al revisarlo, **la causa estaba en nuestro propio narrador**,
no en una cola de `flutter_tts`:

| Qué pasaba | Dónde |
|---|---|
| En Android, `stop()` (pausar, adelantar, cerrar) hace que el `speak()` pendiente **devuelva `0`**, igual que un error (`FlutterTtsPlugin.kt`: `speakResult.success(0)`) | `flutter_tts` 4.2.5 |
| `TtsNarrator.speak` tomaba ese `0` por un fallo y marcaba la voz como rota **para siempre** (`_broken = true`): el resto del cuento seguía «por tiempo», sin sonido | `narrator.dart` (antes) |
| `goTo` calculaba la escena de destino *antes* de esperar a que la voz parara: cinco «adelantar» seguidos partían los cinco de la misma escena y acababan en la segunda, no en la sexta | `playback.dart` (antes) |

Arreglo:

* **Cancelar no es fallar.** Cada `stop()` sube una *generación*; un `0` de una generación anterior es una cancelación (se
  ignora). Un `0` de la generación actual es un fallo real: se reintenta hasta 3 veces y esa frase sigue por tiempo, pero la
  voz **vuelve con la siguiente**. Tres frases seguidas sin voz la dejan descansar hasta la próxima pausa o salto.
* `goTo` cambia el estado **antes** de esperar al motor; los saltos seguidos se suman y solo el último reanuda la voz.
* Un motor que no contesta ya no deja el cuento colgado (5 s de espera al prepararlo).
* La prueba de regresión de la especificación — *reproducir, adelantar 5 veces rápido, retroceder 2, pausar y reanudar* — está en
  `app/test/narrator_test.dart` con un motor de voz de mentira (`test/fake_tts.dart`) que imita a Android: `stop()` devuelve `0`
  y un `speak()` mientras suena otra frase devuelve `0` en el acto.

Pendiente de comprobar **en un teléfono real** (Android e iOS): la prueba imita el motor, no lo es.

## 2. `texto_voz`: lo que se lee ≠ lo que se dice

`caldero_engine/lib/src/voice.dart` → `normalizeForVoice(texto)` (español). El reproductor le manda a la voz la frase
normalizada; la pantalla conserva el texto original. Reglas, en este orden:

1. quita emojis y símbolos (`&` → «y», `%` → «por ciento»);
2. reduce letras repetidas 3 o más veces a una (`fiuuu` → `fiu`);
3. quita comillas «» y “” y arregla el signo pegado (`!».` → `!`);
4. números (hasta 999 999, con coma decimal) y abreviaturas (`Sr.`, `Dra.`, `etc.`…) a palabras;
5. baja las mayúsculas de énfasis (`¡NO!` → `¡No!`);
6. diccionario de pronunciación de las onomatopeyas del pack (`Shhh` → «chis», `Grrr` → «gruñ», `Beee` → «bee»…);
7. suspensivos → un punto (o una coma si sigue minúscula);
8. frases de más de 20 palabras → se parten con un punto por la coma más cercana a la mitad.

`voiceIssues(texto)` es la prueba de aceptación: devuelve vacío si no queda nada de lo anterior. Se ejecuta sobre **todos los
textos de los cuentos posibles** (4 000 semillas; 2 059 textos distintos, 16 282 frases):

| Medida | Valor |
|---|---|
| Frases que el normalizador cambia | 5 531 (34 %), sobre todo comillas «» (casi todos los diálogos), `Shhh/Grrr/Fuuush…` y los puntos suspensivos |
| Frases de más de 20 palabras | 499 antes → 68 después (las que no tienen una coma donde partir) |
| Cifras, emojis, símbolos, mayúsculas de énfasis, letras repetidas | 0 |

Las 68 frases largas restantes no tienen coma que las parta bien; se dejan como están (la voz las dice con su propia pausa)
y quedan para una pasada editorial.

## 3. Perfiles de edad

`caldero_engine/lib/src/age.dart`. Cuatro perfiles con las cifras de la especificación (una propuesta a validar con 5–10
familias por grupo):

| Perfil | Palabras | Minutos | Oración típica | Velocidad de voz |
|---|---|---|---|---|
| 2–3 | 150–300 | 2–3 | 4–8 | 0,80× |
| 4–5 | 300–600 | 4–6 | 6–10 | 0,85× |
| 6–8 | 600–1 200 | 6–10 | 8–14 | 0,90× |
| 9–12 | 1 200–2 000 | 10–15 | 10–20 | 1,00× |

* `measureStory` mide palabras, oraciones y minutos; `StoryMetrics.fits(perfil)` compara.
* Cada premisa declara `ages` (en `pack.json`; el esquema y el validador lo comprueban). `StoryOptions(age: …)` elige solo las
  premisas de ese perfil; **si no hay cuentos de esa edad se usan los del perfil más cercano** (`Pack.resolveAge`) y la app lo dice.
* **Medida real** (`test/age_test.dart`, para todas las versiones posibles de cada cuento):

  | Edad | Cuentos | Palabras | Oración media | Oración más larga |
  |---|---|---|---|---|
  | 2–3 | `cabrita`, `piedras`, `taza` | 175–190 | 6,5–7,4 | ≤ 17 |
  | 4–5 | `linterna_teo`, `manta_lia`, `campana_mediodia`, `panecillo`, `sombras`, `sopa` | 296–353 | 7,5–9,4 | ≤ 20 |
  | 6–8 | `campana`, `olla`, `linterna`, `pozo`, `girasol`, `puente` | 580–930 | 8,3–11,9 | ≤ 32 |

  Cada edad tiene al menos un cuento por enseñanza (honestidad, generosidad, valentía) y una prueba lo exige.
* **Reglas del validador por edad** (`_checkAge`, además de las de siempre): palabras del perfil con un margen del 15 %, oración media y
  oración máxima (el doble de la típica), **sin villano** en 2–5, vocabulario (2–3 sin «miedo», «oscuro», «llorar», «perdido»…; 4–5 sin
  monstruos ni peligro de verdad) y el último párrafo **nunca termina en pregunta** (para dormir se cierra en calma).
* **La enseñanza se dice según la edad:** cada enseñanza trae `simple` con una frase para 2–3 y otra para 4–5
  («Decir la verdad hace el corazón ligero» / «Cuando decimos la verdad, el corazón se siente ligero»). `Story.moralLine` es la que se
  lee, se narra y se comparte; en 6–8 sigue la de siempre.
* **Cómo escribir un cuento pequeño:** ritmo corto y repetición («Un pasito… otro pasito»), onomatopeyas, un solo problema, una
  emoción que se nombra y se resuelve en la misma escena, y el héroe con *una* ayuda (un amigo o un objeto, nunca un villano). Las
  premisas usan solo personajes y objetos que ya tienen arte; los 2–3 caben en 5–6 escenas y los 4–5 en 6–8.
* Cuando una edad no tiene cuentos de una enseñanza se usa la más cercana (`resolveAge`); hoy **9–12 sigue sin cuentos propios** y
  recibe los de 6–8 con su voz y velocidad.

## 3 bis. El nombre del niño como protagonista

* `StoryOptions(heroName:, heroGender:)`: el héroe lleva el nombre del niño (`Character.withGiven`) en el texto, el título, la voz y
  el dibujo sigue siendo el de Aldo o Mara según el género elegido (`m`/`f`; sin género decide la semilla). La gramática (`{hero.o}`,
  «contenta»/«contento») sigue al héroe elegido.
* `normalizeChildName`: quita cifras, emojis y signos, junta espacios, pone mayúscula inicial en cada palabra (también tras un guion)
  y corta a 16 letras. Lo vacío o sin letras no es un nombre.
* Si el niño se llama como otro personaje del pack (Lía, Zafiro, Mara…), ese personaje no se elige para las demás ranuras: nunca
  salen dos iguales. Ningún héroe del pack se cuela en el texto (prueba sobre 300 semillas × 3 edades).
* **Privacidad:** el nombre y el género viven en `ChildProfile` (solo en el teléfono) y en el estante local (para volver a contar el
  cuento igual). **Nunca entran en `StoryRecipe`**: la receta con y sin nombre es idéntica y la valoración no lo lleva
  (`test/names_test.dart`).
* App: el wizard tiene un paso «¿Cómo se llama el niño?» (opcional) con «Un niño / Una niña / Que decida el cuento»; Ajustes tiene
  los mismos campos. Los estantes antiguos (sin edad ni nombre) se siguen leyendo.

## 4. Wizard de primer uso y Ajustes

* **Wizard** (`ui/wizard_page.dart`), solo la primera vez (`wizard_completado`): 1) idioma (preseleccionado el del sistema; si no
  hay cuentos en él se avisa y se usa español), 2) voz del narrador (2–4 tarjetas con nombre amigable; al tocar suena
  «¡Hola! Soy Luna y esta noche te voy a contar un cuento.», y se corta si se toca otra o se avanza), 3) edad (cuatro botones con una línea de
  qué cambia), 4) resumen con «Empezar» y «Cambiar». «Saltar» deja los valores por defecto: idioma del sistema, primera voz, perfil 4–5.
* **Ajustes de adultos** (tras la pregunta de multiplicar): idioma, voz (con muestra), edad, velocidad de lectura (lenta 0,85× /
  normal / rápida 1,15× **sobre** la del perfil), música de fondo (con volumen) y «Descargas» (hoy: todo va dentro de la app y funciona
  sin internet). Se aplican al siguiente cuento sin reiniciar: las pantallas leen los ajustes al abrirse.
* **Modelo de datos** preparado para varios niños: los ajustes guardan una **lista** de `ChildProfile` (edad, idioma, voz, velocidad) y
  uno activo; la interfaz muestra uno solo.
* Los nombres de las voces (Luna, Brisa, Nube, Trueno) son **neutros a propósito**: el teléfono no dice si una voz es de mujer o de
  hombre, y un nombre equivocado confundiría. Los códigos técnicos nunca se enseñan.

## 5. Criterios de aceptación de la especificación

| Criterio | Estado |
|---|---|
| Ningún cuento con letras repetidas 3+, «», emojis o cifras en `texto_voz` | **Hecho**, probado sobre todos los cuentos posibles |
| Todo cuento pasa el validador de **vocabulario** y longitud de su perfil | **Longitud: hecho.** Vocabulario: pendiente (falta el léxico, ver abajo) |
| Adelantar 5 veces y retroceder 2 nunca deja la voz en silencio | **Hecho en la prueba con motor simulado**; falta probar en Android e iOS |
| El texto resaltado coincide con la frase que suena | Ya ocurría (el resaltado sale de la frase actual); con la normalización la frase sigue siendo la misma |
| El wizard aparece solo la primera vez y preselecciona el idioma del sistema | **Hecho** |
| Los saludos de muestra suenan sin internet | **Parcial**: se dicen con la voz del teléfono (sin conexión si la voz está instalada), no con audio empaquetado |
| Cambiar idioma, voz o edad en Ajustes se aplica al siguiente cuento | **Hecho** |
| Un cuento descargado se reproduce completo en modo avión | Los cuentos ya van dentro de la app; el audio pregenerado no existe aún |

## 6. Lo que no se hizo, y por qué

| Pendiente | Motivo |
|---|---|
| Audio pregenerado en el servidor (Google Cloud TTS) y reproductor `just_audio` con marcas de tiempo | Necesita cuenta con facturación y servidor; hoy los cuentos nacen de premisas (no son fijos), así que habría que generar el audio al crear cada cuento. Es la **pregunta abierta** de la especificación y decide la estrategia |
| Validador de vocabulario por nivel de edad (Manzano y Piñeiro, normas de edad de adquisición, EsPal) | Hay que verificar la licencia de cada base antes de empaquetarla; sin esos datos un validador inventado daría falsa seguridad |
| Inglés y portugués de Brasil | Cada idioma es una versión propia de los cuentos (texto, normalizador, onomatopeyas, léxico, voces, interfaz traducida); hoy solo existe la versión en español |
| Cuentos para 2–3 y 4–5 años | Trabajo editorial: tramas más cortas y sin peligro |
| Prompt para una IA generadora | Los cuentos no los genera una IA; no hay donde usarlo |
| Saludos de muestra como audio empaquetado | Habría que grabarlos o generarlos con una voz concreta |
| Resaltado por marcas de tiempo del audio | Depende del audio pregenerado |

## Cómo se prueba

```
cd packages/caldero_engine && dart test test/voice_test.dart test/age_test.dart
cd app && flutter test test/narrator_test.dart test/wizard_settings_test.dart
```
