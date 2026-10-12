# 23 · Guía para escribir premisas nuevas (pack medieval)

Para quien escriba cuentos nuevos del pack `medieval` (personas o agentes). Resume lo que hay que saber **sin leer el motor**; el
detalle del formato está en [06](06-modelo-de-contenido.md), las edades en [18](18-voz-edades-y-wizard.md), la rúbrica editorial en
[14](14-rubrica-editorial.md) y la coherencia texto↔dibujo en [16](16-coherencia-texto-imagen.md). El árbitro final es el validador:
**si `validate_pack` dice 0 problemas y el texto se lee bien en voz alta, la premisa vale.**

## 1. Flujo de trabajo

1. Escribe la premisa en un archivo propio, `{"premise": {…}, "props": […]}` (`props` solo si añades un objeto de la trama nuevo, ver §3).
2. Mézclala en una **copia** del pack y valídala (el pack real no se toca):

   ```bash
   export PATH=/opt/flutter-sdk/flutter/bin:$PATH
   cd <repo>
   python3 tools/content/merge_premise.py mi_premisa.json --out /tmp/borrador.json
   (cd packages/caldero_engine && dart run bin/validate_pack.dart /tmp/borrador.json)
   ```

   Repite hasta «0 problemas». Vuelve a mezclar el mismo archivo cuantas veces haga falta (sustituye la premisa del mismo `id`).
3. Cada mensaje del validador dice **qué premisa, qué reparto y qué escena**; arréglalo en la plantilla, no en el reparto.
4. Para leer los cuentos que salen (Markdown, con las directivas de escena):
   `cd packages/caldero_engine && dart run bin/sample_stories.dart /tmp/borrador.json /tmp/cuentos 12`.

No hay arte nuevo: **solo se puede dibujar lo que ya existe** (§3). Si la historia necesita algo que no existe, cámbiala.

## 2. Qué debe tener una premisa

* `id`, `value` (enseñanza), `title`, `ages` (una sola edad), `npcs` (secundarios dibujados y cómo los nombra el texto), `cast`
  (ranuras: `hero`, `helper`, `villain`, lugares, `item`…) y `beats` (escenas en orden).
* El héroe es **Aldo o Mara** (o el nombre del niño): el texto usa `{hero}` y, para el género, `{hero.o}` (lleno**a**/lleno**o**),
  `{hero.el}`, `{hero.un}`, `{hero.del}`, `{hero.al}`… Nunca escribas «cansado», «dormido»… con el género fijo; di «con sueño», o
  `cansad{hero.o}`. El validador lo detecta.
* **Cada escena** (`beat`): una o más `variants` que cuentan **los mismos hechos** con otras palabras o con otro reparto (`requires`
  por `ranura:id` o por etiqueta); `scene` con `bg` (ranura de lugar), `mood`, `time` (`dia`/`amanecer`/`atardecer`/`noche`, solo
  los que el lugar admite), `stage` (quién sale y con qué gesto), `props`, `focus` (primer plano de un objeto) y, si el texto
  nombra algo que no se ve a propósito, `unseen`.
* **`introduces`**: la escena que presenta a un personaje u objeto lo nombra por primera vez; antes nadie lo nombra.
  Un objeto de la trama que se presenta se ve de cerca (`focus`).
* **`moves: true`** si el fondo cambia respecto a la escena anterior y el texto cuenta el viaje.
* **Anclas de causa:** la escena de la enseñanza (lo que el héroe hace bien) añade una etiqueta (`adds: ["dio_el_paso"]`) y el cierre la
  exige (`requires`). Así nunca sale un final sin su causa. Mira cómo lo hacen `puente`, `linterna` o `sombras`.
* **Preguntas al niño** (`choice`) son opcionales; en 9–12 puede haber hasta 2 ([20](20-caminos-elegibles.md)). Si no las necesitas, no las pongas.
* El último párrafo **nunca termina en pregunta** y cierra en calma (es un cuento para dormir). Cada escena se lee en voz alta: frases
  que suenen bien, sin efectos de sonido «literales» (`¡Cric!` solo si la frase tiene sentido sin él: «El puente crujió, ¡cric!»).
* **No escribas la moraleja dentro del cuento.** La app la dice al final con las palabras de la enseñanza. El cuento la *muestra*.

## 3. Lo que se puede dibujar

**Personajes** (`stage`: `"hero"`, `"helper"`, `"villain"`, `"hero:scared"`, `"@teo:sad"`, `{"who":"hero","clip":"…","x":0.3}`):

| Ranura | Quiénes | Notas |
|---|---|---|
| `hero` | `aldo` (m), `mara` (f) | atributos de frase: `{hero.gesto}`, `{hero.miedo}`, `{hero.paso}`, `{hero.jura}`, `{hero.voz}`… |
| `helper` | `zafiro` (mago sabio), `bonifacio` (rey bondadoso) y, si la premisa lo permite, el otro héroe (`aldo`/`mara`) | atributos `{helper.consuelo}`, `{helper.idea}`, `{helper.aporte}`… |
| `villain` | `codicio` (codicioso), `sombra` (astuto) | **No en 2–3 ni 4–5**. En 6–8 y 9–12, suave y con arreglo. |
| secundarios (`npcs`) | `rosa`, `lia`, `teo`, `beto`, `tomas`, `hugo`, `aldeano`, `aldeana`, `farolero`; animales `cabrita`, `buho` | se dibujan con `{"rig":"teo"}` o `"@teo"`; se nombran en el texto con las palabras de `npcs` (`"teo": ["Teo"]`) |

Clips de personajes: `idle walk run wave cheer jump surprised scared talk bow point sad think sneak laugh sleep offer no clap shiver
hug sit sit_sad climb hide eat blow proud yawn wonder`. Con miedo se usan las variantes `<id>_miedo`; para dormir, `<id>_pijama`.

**Lugares** (`cast`: `{"kind":"place","ids":[…]}`; en `scene.bg` va el nombre de la ranura). Horas y estaciones que admiten:

| id | Qué es | Horas | Estaciones |
|---|---|---|---|
| `castillo` | castillo de la Luna | dia atardecer noche | — |
| `bosque` | bosque de los robles | dia atardecer noche | — |
| `cueva` | cueva de los cristales | (solo base) | — |
| `rio` | río de plata **con puente** | dia atardecer noche | — |
| `vado` | el mismo río sin puente (piedras para cruzar) | dia atardecer noche | — |
| `aldea` | aldea de los molinos, con pozo | dia amanecer atardecer noche | invierno primavera otono |
| `casa` | cocina de Rosa | noche | invierno |
| `cuarto` | cuarto con ventana, cama y mesa | dia noche | invierno primavera |
| `campanario` | interior del campanario (cuerda, escalera) | dia atardecer noche | — |
| `colina` | **nuevo** · colina con un roble grande, un camino y casitas lejanas | dia atardecer noche | — |
| `huerto` | **nuevo** · huerto con coles, zanahorias, valla, espantapájaros y cobertizo | dia atardecer noche | — |
| `lago` | **nuevo** · lago quieto con embarcadero, barquita lejana y juncos | dia atardecer noche | — |

Si el texto dice «nevaba», «en primavera»… el validador exige la estación del dibujo; si dice «de noche», la hora. Una escena sin `time`
usa la hora base del lugar.

**Objetos de la trama** (`cast.item`: `{"kind":"prop","ids":["campana"]}`) ya declarados en `pack.props`: `campana pan linterna bolsa cometa
semillas girasol hierba cabrita manta taza_leche cuenco`. Para otro objeto con dibujo, añade una entrada a `props` en tu archivo
(`{"id":"regadera","noun":"regadera","gender":"f","tags":["tool"]}`) usando uno de estos **dibujos que ya existen**:
`campana campana_colgada campana_rota cinta cofre cometa cuenco cuenco_vacio cuerda_rollo escalones girasol girasol_seco hierba linterna
linterna_apagada maceta maceta_brote manta mariposa mesa olla pan pedernal piedras puerta_cabana rafaga regadera roble saco semillas
semillas_dos taza taza_leche taza_volcada trozos_de_pan vela bolsa buho cabrita capa sombra_gigante`.

En `scene.props` puede ir **cualquiera** de esos dibujos (`{"prop":"vela","x":0.6,"clip":"glow","scale":1,"lift":0,"front":false}` o
`"near":"hero","dx":0.06`). Clips de objetos: `still swing ring glow boil jingle sway sun grow shimmer flutter gust goat_idle goat_baa
goat_walk goat_hop hoot`. **Todo objeto que el texto nombra debe estar dibujado en esa escena** (props, `focus` o el reparto) o marcarse
`unseen`; el validador lo comprueba con una lista de palabras (`_objectWords` en `validator.dart`): si dices «vela», dibuja `vela`.

`mood`: `calm tension hope mystery triumph sad joy sleep`. `light`: `dusk night dark cold`. Un fondo con `focus` (`{"prop":"manta","x":0.5,"fill":0.55}`)
muestra el objeto de cerca y sin personajes.

## 4. Edades (lo que el validador mide)

| Edad | Palabras por cuento | Oración media | Notas |
|---|---|---|---|
| 2–3 | 150–300 | 4–8 | **Sin villano.** Sin «miedo», «oscuro», «llorar», «perdido»… Repetición, onomatopeyas, un solo problema, final feliz enseguida. |
| 4–5 | 300–600 | 6–10 | **Sin villano**, sin monstruos ni peligro de verdad; las emociones se nombran y se resuelven. Oración máxima 20. |
| 6–8 | 600–1200 | 8–14 | Varios personajes y un susto suave. Villano posible, que acaba arreglándose. |
| 9–12 | 1200–2000 | 10–20 | Tramas con giros, personajes que cambian, diálogos. Dos «subtramas» o un giro a mitad. |

Los márgenes exactos (±15 %) y los mínimos de conectores causales («porque», «así que», «por eso»…), de citas con «…» (mínimo 2) y de
presencia del héroe (en casi todas las escenas) salen en los mensajes. **Cuenta las palabras de los cuentos que genera cada combinación de
variantes**, no la suma de todas las variantes. Para 9–12, escribe escenas largas (80–180 palabras) y alguna escena con 2–3 variantes
distintas para que no se cuente siempre igual.

## 5. Estilo (rúbrica resumida)

* Un solo problema claro, causas visibles («porque…», «así que…»), un héroe que **hace** algo (no solo observa) y un cierre que baja el
  ritmo.
* Imágenes concretas y sensoriales (olor del pan, crujir de la madera, frío en los dedos), humor suave, diálogos cortos con «…».
* Nombres propios y objetos repetidos con cariño (un cuento para dormir agradece el ritmo y la repetición).
* Nada de moralina, ni burla de nadie, ni castigo cruel. El «malo» se equivoca y se arregla.
* Cada escena aporta algo nuevo; si la quitas y no se nota, sobra.
* Vocabulario de la edad: en 2–3 y 4–5 frases cortas y palabras de casa; en 9–12 se admiten palabras más ricas, si se entienden por el contexto.

## 6. Qué entregar

El archivo `{"premise": {…}, "props": […]}` que **valida con 0 problemas**, y un párrafo con: de qué va, qué lugares, personajes y objetos usa,
cuántas variantes por escena, rango de palabras de los cuentos generados y cualquier cosa del validador que te haya parecido discutible.
