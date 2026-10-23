# 26 · Pack «Mar de las Estrellas» (piratas y sirenas)

Segundo pack de cuentos, con el mismo tamaño que el medieval: **30 cuentos** en las cuatro edades (6 de 2–3, 9 de 4–5, 9 de 6–8 y
6 de 9–12), las **seis enseñanzas** (honestidad, generosidad, valentía, humildad, perseverancia y amistad) y arte propio generado por
código. Ya aparece en el catálogo como «próximamente» (`id: mar`). Este documento es el plan y la biblia del pack; se actualiza
fase a fase.

## 1. El tono: piratas buenos

Los piratas de este mar son **exploradores**, no ladrones. Navegan siguiendo las estrellas, dibujan mapas, ayudan a quien
naufraga y cuidan el mar. Lo que los mueve es la aventura, la lealtad a la tripulación, la palabra dada y la curiosidad.

Reglas del pack (se suman a la rúbrica de [14](14-rubrica-editorial.md)):

* **Nada de robar, saquear, secuestrar ni «pasar por la plancha».** Si alguien quiere algo que no es suyo, se equivoca y se arregla.
* **Las espadas no se usan contra nadie.** Puede haber un sable colgado de decoración; las «batallas» son de agua, de cosquillas o
  de adivinanzas.
* **El tesoro** casi nunca es solo oro: se comparte, se devuelve a su dueño o resulta ser otra cosa (semillas, un diario, una
  canción, el mapa de la vuelta a casa). Cuando hay monedas, el cuento se ocupa de repartirlas con justicia.
* **La bandera** lleva una estrella y una luna, no una calavera.
* **El mar no castiga.** Las tormentas y la niebla son sustos suaves (solo de 6–8 en adelante) que se superan juntos.
* **Las sirenas** son amigas del mar: cantan nanas, guardan el arrecife y enseñan a escuchar.
* Los «malos» (solo de 6–8 en adelante) son gruñones o tramposos, no crueles, y siempre terminan arreglando lo que hicieron.

## 2. Personajes (propuesta)

| Ranura | Personaje | Quién es |
|---|---|---|
| `hero` (m) | **Bruno** | Grumete curioso; quiere aprender a leer las estrellas. |
| `hero` (f) | **Vega** | Grumeta valiente; sube la primera a la cofa. |
| `helper` | **Capitana Estela** | Capitana de *La Gaviota*: justa, risueña y firme con la palabra dada. |
| `helper` | **Abuelo Faro** | El farero sabio de la Isla Quieta; conoce todos los mapas y todas las estrellas. |
| `helper` | **Nácar** | Sirena del arrecife; canta nanas y conoce las corrientes. |
| `villain` (6–8, 9–12) | **Capitán Mostacho** | Quiere todos los tesoros para él solo; aprende a compartir. |
| `villain` (6–8, 9–12) | **Remolino** | Pulpo travieso que esconde cosas y lía cuerdas; aprende a pedir perdón. |
| secundarios | loro **Pimienta**, tortuga **Calma**, el cocinero **Tío Cazo**, la pescadora **Ola**, niños del puerto | Animales y gente del puerto que aparecen y se nombran en el texto. |

Como en el medieval, el héroe lleva el **nombre del niño** si la familia lo escribe, y el género que eligió (Bruno o Vega).

## 3. Lugares (12)

| id | Qué es | Horas |
|---|---|---|
| `cubierta` | cubierta de *La Gaviota*, con mástil, velas y timón | día, atardecer, noche |
| `camarote` | camarote con hamaca, farol y ojo de buey | día, noche |
| `bodega` | bodega con barriles y cajas | (base) |
| `cofa` | lo alto del mástil: cielo y mar hasta el horizonte | día, atardecer, noche |
| `puerto` | puerto con muelle, casitas y gaviotas | día, amanecer, atardecer, noche |
| `playa` | playa de la isla con palmeras y cangrejos | día, atardecer, noche |
| `selva` | selva de la isla con lianas y flores | día, atardecer |
| `cueva_tesoro` | cueva de la isla con charcos que brillan | (base) |
| `arrecife` | bajo el agua: corales, peces y luz verde | día, noche |
| `faro` | el faro del Abuelo Faro sobre las rocas | día, atardecer, noche |
| `laguna` | laguna de las sirenas, quieta y con nenúfares | día, noche |
| `mar_abierto` | el barco en alta mar (también con niebla o tormenta suave) | día, atardecer, noche |

## 4. Objetos de la trama (propuesta)

`mapa`, `cofre`, `catalejo`, `brujula`, `botella_mensaje`, `timon`, `ancla`, `caracola`, `perla`, `farol_barco`, `llave`, `monedas`,
`red`, `bandera`, `estrella_mar`, `galleta_barco`, `diario_bitacora`. Con sus variantes de estado cuando la historia las necesite
(mapa roto, cofre abierto, farol apagado…).

## 5. Fases

Cada fase termina con las pruebas y el validador en verde, una comprobación en el simulador y un commit.

1. **Revisión gramatical previa.** Generar los 30 cuentos medievales con un nombre de niño y otro de niña y buscar adjetivos que no
   concuerden con el protagonista. Lo que se encuentre amplía la lista del validador, que luego vigilará también el pack pirata.
2. **Varios packs en la app.** Cargar el pack y su arte por `id` (hoy está fijo en `medieval`); abrir un pack desde «Paquetes»;
   portada, guía y ejemplos de Ajustes por pack (hoy fijos en Aldo, Mara, Zafiro y el castillo); el estante recuerda de qué pack es
   cada cuento; `sync_assets.sh` y CI para los dos packs. El pirata empieza con un cuento de prueba.
3. **Arte, primera tanda: personajes.** Bruno, Vega, la capitana, el abuelo, Mostacho y los secundarios con el esqueleto humano que ya
   existe, con sus variantes de miedo y pijama. **Nácar** necesita un esqueleto nuevo (cola en vez de piernas) y **Remolino** otro
   (tentáculos); el loro y la tortuga son objetos animados, como la cabrita y el búho.
4. **Arte, segunda tanda: lugares y objetos.** Los 12 fondos con sus horas (el barco se mece; el arrecife con luz bajo el agua),
   los objetos y los gestos nuevos (remar, mirar por el catalejo, llevar el timón, nadar).
5. **Cuentos, por tandas de edad.** 6 de 2–3 → 9 de 4–5 → 9 de 6–8 → 6 de 9–12, cada uno con el validador en «0 problemas» y
   leído en voz alta (muestras con `sample_stories`). Las preguntas al niño en 9–12, como en el medieval.
6. **Sonido y cierre.** Olas, gaviotas y crujido de madera; el pack pasa a «disponible» en el catálogo; textos de la tienda;
   nueva versión.

## 5 bis. Estado

| Fase | Estado |
|---|---|
| 1. Revisión gramatical | ✅ Seis frases corregidas en el medieval (pack 0.19.1); el validador rechaza plurales de pareja en masculino («{hero} y Lía … juntos») y títulos pegados al héroe («{hero}, el rey»). Ver [14](14-rubrica-editorial.md). |
| 2. Varios packs en la app | ✅ El pack abierto se guarda en Ajustes (`paquete`); pack y arte se cargan por `id`; «Paquetes» marca el abierto; la portada sale de `PackCover`; un cuento guardado se cuenta con su pack; solo se ofrecen las enseñanzas con cuentos (también «Sorpréndeme»). `content/packs/mar` tiene los personajes, lugares y objetos de este plan y un cuento de prueba (*La caracola de Nácar*, 2–3, amistad), aún sin arte. **Solo se abre en compilaciones de desarrollo** (`kDebugMode`). |
| 3–6 | ☐ |

## 6. Riesgos

* **Arte nuevo de esqueleto** (sirena y pulpo): los gestos actuales suponen piernas. Puede bastar con una cola que se ondula y un
  conjunto pequeño de gestos propios.
* **Tamaño de la app:** el medieval ocupa ~0,9 MB de texto y unos pocos MB de arte; el pirata, parecido. Si crece mucho, el pack se
  podrá descargar aparte (docs [05](05-modelo-freemium.md)).
* **Parecido con personajes conocidos:** nada de garfios, patas de palo con nombre famoso ni loros que se llamen como los de las
  películas. Prueba de parecido de [10 §2](10-arte-y-estilo-visual.md) antes de dar por bueno cada diseño.
