# 16 · Coherencia entre el texto y la ilustración

> **Regla de oro:** lo que se lee es lo que se ve. Si el texto dice «por la mañana», el cielo es de mañana; si dice
> «la nevada», hay nieve; si dice «el pozo», el pozo está dibujado; y el objeto del que trata el cuento se ve de cerca.

## Qué fallaba (primera prueba en un teléfono real, «Las semillas de sol»)

| Lo que se leía | Lo que se veía |
|---|---|
| «La abuela le dejó una bolsita de semillas» | Mara de pie; las semillas, escondidas tras sus pies |
| «Aquella noche puso las semillas sobre la mesa» | Un cuarto sin mesa; la bolsa en el suelo |
| «Por la mañana, Mara fue a ver al mago» | Un atardecer con estrellas (todas las escenas de la aldea eran un atardecer) |
| «La nevada había cubierto las huertas… aldea gris y sin flores» | Hierba verde y flores |
| «Se sentó en el borde del pozo… Lía apenas llegaba al mostrador» | Una aldea sin pozo ni mostrador |
| «Plantó dos semillas en macetas junto a la ventana» (y la primavera) | Dos girasoles ya crecidos al aire libre |

La causa era de sistema, no de un cuento: el arte tenía **una sola luz por lugar** y **ninguna forma de acercarse a un objeto**,
y el validador no comparaba lo que cuenta el texto con lo que declara la escena.

## Cómo se arregla

### 1. Cada lugar se dibuja a la hora y en la estación del texto

Directivas de escena (en `scene` de cada variante del pack):

| Directiva | Valores | Qué hace |
|---|---|---|
| `time` | `dia`, `amanecer`, `atardecer`, `noche` | Elige el fondo a esa hora (cielo, sol o luna, estrellas, nubes, color del suelo) |
| `season` | `invierno`, `primavera`, `otono` (sin estación = verano/normal) | Nieve en suelo, tejados y vallas con copos; flores y charcos; hojas doradas |
| `focus` | `{prop, x, lift, scale, fill, clip}` | **Primer plano**: el objeto grande, solo, con el fondo desenfocado (se intuyen el lugar, la hora y la estación) y viñeta |
| `stage[].lift`, `stage[].scale` | números | Subir a un personaje (pisar un puente) y alejarlo |
| `unseen` | lista de rasgos | El texto nombra a propósito algo que no se ve (algo que se atisba por una rendija) |

Las variantes se **generan por código** (`tools/art/looks.py`): se sustituye el cielo y se retoca el color del resto de capas
(todo se oscurece de noche, se calienta al atardecer, la hierba se vuelve nieve en invierno y oro en otoño; las luces
encendidas se respetan). Una escena `aldea__dia__invierno` ocupa unos 20 KB. La app elige `<lugar>__<hora>[__<estación>]`
(`PlaceArt.looks`, `StageArt.sceneFor`); si la combinación no existe cae en la hora sola y, después, en el fondo base.

Lugares y luces disponibles (declarados en el pack, en `places[].times / seasons / features`):

| Lugar | Horas | Estaciones | Rasgos dibujados |
|---|---|---|---|
| aldea | las 4 | invierno, primavera, otoño | pozo |
| castillo | día, atardecer, noche | — | — |
| bosque · río | día, atardecer, noche | — | (río: puente) |
| cuarto | día, noche | invierno, primavera | ventana, cama, mesita |
| casa (cocina) | noche | invierno | ventana, horno |

### 2. Los objetos importantes se ven de cerca

El objeto que **se presenta** en un cuento (`introduces`) se muestra en `focus`. Objetos nuevos: semillas (bolsita abierta con las
cinco pepitas delante), `semillas_dos`, macetas y macetas con brotes, mesa larga de la fiesta. El primer plano también funciona
en el modo holograma (el objeto flota en el centro).

### 3. El validador lo exige (`packages/caldero_engine`, `_checkSetting`)

Cualquier cuento posible del pack se valida (≈ 4000 versiones). Reglas:

* **Hora:** un lugar con horas exige `time`; si la narración dice «por la mañana», «aquella noche», «al alba», «al caer la tarde»,
  «la luna»… el `time` debe ser compatible (si hay varias pistas basta con una).
* **Estación:** «invierno», «nevada», «nieve» → `season: invierno`; «primavera», «charcos» → `primavera`; «verano» → ninguna o primavera;
  «otoño», «hojas doradas» → `otono`.
* **Solo cuenta la narración:** lo que se dice entre «» puede referirse a otro momento. «la Luna» con mayúscula (el castillo) no es la luna.
* **Rasgos del lugar:** pozo, ventana, cama, mesa, mostrador, horno, puente: si el texto los nombra deben estar en el lugar o en un objeto
  de la escena (o marcarse `unseen`).
* **Objeto nuevo:** la escena en que se presenta debe llevar `focus` de ese objeto.
* En un primer plano nadie sale dibujado, así que no hace falta `offstage`.

Las reglas se probaron con casos buenos y malos (`premise_test.dart`) y la app comprueba que toda hora y estación que pide un cuento
existe dibujada (`story_stage_test.dart`).

## Cómo se revisa (a ojo, con el mismo pintor que la app)

```
cd app
RENDER_OUT=/tmp/escenas RENDER_PREMISES=girasol,campana RENDER_PER=2 \
  flutter test test/render_stories_manual_test.dart
```

Escribe una imagen por escena (`<premisa>_<n>_<escena>.png`) y el texto con sus directivas (`<premisa>_<n>.json`). Se juntan en hojas de
contacto con la imagen, los datos de la escena y el texto, y **lectores independientes que miran las imágenes** los comparan
(rúbrica C7 de `docs/14`). Es la prueba que habría atrapado los fallos de la primera tabla.

## Límites conocidos

* El validador entiende pistas **explícitas** (palabras de hora, estación y unos cuantos rasgos). Un texto que sugiere la noche sin
  decirlo no se detecta: de eso se encargan los lectores que miran las imágenes.
* Las luces de cada lugar están generadas por código a partir de un fondo base: son coherentes, no obras de ilustrador.
* El copo de nieve «titila» (las animaciones ambientales solo admiten opacidad y giro); no cae.
