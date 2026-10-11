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

### 4. La acción se ve (ronda 9, tras revisar las imágenes)

La primera revisión con imágenes (18 cuentos, tres lectores) dio 2–3 sobre 5: la hora y la estación ya cuadraban, pero **la acción no**:
todos de pie y sonrientes, el que duerme sin cama, la cuerda, la vela, el pedernal o el saco que nunca se veían, el «interior de la
torre» y la «puerta de la cabaña» dibujados como un prado. Lo que se añadió:

| Capacidad | Para qué |
|---|---|
| Gestos nuevos: `shiver` (tiembla, brazos cruzados), `hug`, `sit`, `sit_sad`, `climb`, `hide` | Miedo, frío y culpa ya no se ven como alegría; abrazos; sentarse; trepar al roble; esconderse |
| `stage[].rotate` (−90 = tumbado) y `props: manta` | Dormir **en la cama** (o en el suelo de la cocina) bajo una manta, con la cabeza en la almohada |
| `props[].near` + `dx` + `lift` | El objeto en la mano o a los pies del personaje (la semilla, la bolsa, la vela, el pedernal, el pan, la taza, el saco) |
| `rope: {from, to}` | La cuerda que une al héroe con su ayudante (puente, linterna); `to: left/right` sale de cuadro. Se dibuja **atada a la cintura** (aro y nudo en cada extremo con persona); los dos que se unen van juntos, sin nadie en medio, o parece una línea que cruza la escena |
| Lugar nuevo `campanario` | Interior de la torre: arco al cielo (día/atardecer/noche), antorcha, gancho con su cuerda, escalera |
| Objetos nuevos | `puerta_cabana` (el villano se ve por la rendija), `roble` con hueco y rama para la linterna, `girasol_seco` (cuello doblado), `manta`, `taza`, `cuenco`, `regadera`, `cinta` |

### 5. Dos fallos que vio el dueño en el teléfono (ronda 11)

* **Personaje flotando:** el héroe trepaba al roble sin ningún apoyo, delante del tronco. El roble tiene ahora una **rama baja y gruesa**
  (cara de arriba a y ≈ −55) y el héroe pisa en ella con la mano en la linterna.
* **«La soga no sé qué es»:** la cuerda era una línea de color al nivel de la cintura que cruzaba a otros personajes y colgaba suelta.
  Ahora lleva vuelta y nudo en la cintura, y en la escena del regreso el héroe y su ayudante van juntos.

### 6. Cuentos para 2–3 y 4–5 años y expresiones (ronda 12)

La revisión con imágenes de los nueve cuentos nuevos (hojas de contacto, escena a escena) encontró y corrigió:

| Qué se veía | Arreglo |
|---|---|
| La manta parecía un filete (roja, con rayas) | Manta a cuadros azul con franjas crema y mostaza y flecos |
| La taza tenía un líquido verde (era té) | `taza_leche`, blanca; la taza sigue sobre la mesa mientras se cuenta que se derrama |
| Las piedras del río estaban en la hierba y el héroe flotaba | Piedras **en el agua** (`lift`), el héroe las pisa y Lía espera en la otra orilla, más pequeña y alzada |
| «Un gigante» que nunca se veía | `sombra_gigante` (silueta alta de brazos largos) y, al descubrir qué es, `capa` con su sombrero |
| El héroe «trepaba» en el aire delante del castillo | La subida se cuenta dentro del campanario, con los pies en el suelo |
| La cabrita ampliada despegaba las patas del cuerpo | El primer plano usa `goat_idle` |

**Poses y expresiones por acción** (`tools/art/medieval_kit.py`, `make_clips.py`): hasta ahora cada acción era un cuerpo con brazos
rectos y una cara fija. Ahora:

* **Cara animable.** Cejas (`browL`/`browR`, giran: «preocupado»/«decidido»), boca (`mouth`, con `sy < 0` es un gesto triste), boca
  abierta (`jaw`, una «D» que se agranda para hablar, reír o asombrarse) y mirada (`eyes.dx/dy`). Cada acción tiene su cara: asombro
  con cejas arriba y boca en «o», risa con boca abierta y ojos entornados, tristeza con cejas caídas y boca invertida, pensar con la
  mirada arriba y una ceja alzada, sigilo con cejas fruncidas y ojos que vigilan, hablar con la boca siguiendo las sílabas.
* **Brazos con codo** (`foreArmL/R`). Los clips indican *dónde va la mano* y `hand()` calcula hombro y codo (cinemática inversa de
  dos huesos, al generar): saludar con el antebrazo, aplaudir con las manos juntas, la mano en la barbilla para pensar, a la boca
  para comer o bostezar, en las caderas para el orgullo, en las mejillas para el susto. El arma sigue erguida compensando también el codo.
* **Clips nuevos:** `eat`, `blow` (soplar la sopa), `yawn`, `proud`, `wonder`. Los cuentos nuevos los usan donde el texto lo cuenta
  (comer, soplar, asombrarse al ver la aldea desde la torre).

Se revisan con `app/test/render_poses_manual_test.dart` (`POSES_OUT=… POSES_RIGS=aldo,mara,rosa,zafiro`): una imagen de cuerpo y una de
cara por animación y personaje.

### 7. «Si el texto lo nombra, se ve» (ronda 13)

Un padre de familia lo vio en el teléfono: el cuento de *La taza de leche* decía «vio pasar una mariposa» y «tiró la taza, y la
leche se derramó», y en pantalla no había mariposa ni leche. Ahora es una **regla del validador**: si la narración (sin lo que se
dice entre «») nombra uno de los objetos del cuento —mariposa, taza, pan o panecillo, linterna, manta, cuenco, cabrita, piedras,
campana, bolsa, cometa, semillas, girasol, hierba de luna, olla—, la escena lo dibuja (`props`), lo acerca (`focus`: primer plano
con el fondo desenfocado) o declara **por qué no se ve** con `unseen` (un recuerdo, un olor, algo que pasa fuera de cuadro).

* **Lo que es acción se dibuja o se acerca.** En *La taza de leche* ahora hay un primer plano de la **mariposa** (nueva, con alas que
  aletean: clip `flutter`) y otro de la **taza volcada con la leche derramada**.
* **Lo que no lo es se declara.** Las 68 menciones que la regla encontró en los cuentos anteriores (por variante y objeto) se revisaron una a una: 46 eran
  recuerdos, olores o cosas dichas de pasada («olía a pan», «se lo contó todo: la cometa, la bolsa…») y llevan `unseen`; las otras 22 se dibujaron (la bolsa en el
  bolsillo, la cometa en el puesto de Beto, el cuenco que toma el villano, el pan que se come, las piedras junto a la hierba, la
  campana chiquita en lo alto de la torre).
* Quedan fuera de la regla la arquitectura y la ropa («escalones», «capa»), que forman parte del lugar o del personaje.
* Los secundarios dibujados como personaje (`rig`, por ejemplo la cabrita) cuentan como dibujados.

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
