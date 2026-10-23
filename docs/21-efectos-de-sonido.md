# 21 · Efectos de sonido (v0.7.0)

La voz del teléfono no sabe imitar un balido, un crujido o un chapoteo: lee «¡beee!» como una palabra rara. Por eso
([18 §2, regla 0](18-voz-edades-y-wizard.md)) **la voz calla los efectos de sonido** y la app los **reproduce como sonido**, en su sitio
dentro de la frase.

## Cómo funciona

1. Un efecto es una palabra entre `¡ !` de una lista cerrada (`VoiceRules.soundEffects` en `caldero_engine/lib/src/voice.dart`):
   `¡Cric!`, `«¡Beee!»`, `¡Fuuush!`, `¡Plaf!`… Cada palabra (ya sin letras alargadas) apunta a un **id de sonido** (`creak`, `bleat`, `wind`…).
2. `speechParts(frase)` parte la frase, **en orden**, en trozos de voz y efectos:
   «El viento la levantó, ¡fiuuu!, y subió.» → voz «El viento la levantó,» · sonido `wind` · voz «y subió.».
3. `StoryPlayback._sayStory` dice cada trozo con la voz y reproduce cada sonido entre medias (`audio/sfx.dart`, `AssetSfx`).
   Pausar, saltar o cerrar cortan el sonido; el fundido del temporizador de sueño baja también los efectos.
4. Los archivos están en `app/assets/audio/sfx/<id>.ogg` (18 efectos, 180 KB en total, mono, 32 kHz, ≤ 1,5 s, todos a la misma
   sonoridad: −20 dB de media). Se reproducen **sin pedir el foco de audio** (`mixWithOthers`) para no pausar la voz ni la música.
5. Ajustes → «Efectos de sonido» los apaga (se guarda en el teléfono). Suenan en el cine, el holograma y el solo audio; en
   «Leemos juntos» y en la pantalla de texto no hay sonido (lo lee un adulto).

**Regla de autoría:** el texto debe tener sentido sin el sonido («se oyó un balido: ¡beee!», «el puente crujía ¡cric!»). Un efecto
nuevo se añade a `soundEffects` y su archivo a `app/assets/audio/sfx/` (una prueba exige que cada sonido de la lista tenga archivo).

| Sonido (`id`) | Palabras que lo piden | Origen |
|---|---|---|
| `bleat` | ¡Beee! | grabación CC0 (OpenGameArt, AntumDeluge, «Sheep Baa») |
| `creak` | ¡Cric! | grabación CC0 (Kenney, «RPG Audio») |
| `crack` | ¡Crac! ¡Cras! ¡Ras! ¡Fraaas! | grabación CC0 (Kenney, «Impact Sounds») |
| `coins` | ¡Tilín! | grabación CC0 (Kenney, «RPG Audio») |
| `clang` · `clink` | ¡Clang! ¡Clong! · ¡Cling! ¡Clinc! | grabaciones CC0 (Kenney, «Impact Sounds») |
| `bell` | ¡Din! ¡Don! | grabación CC0 (Kenney, «Impact Sounds») |
| `click` | ¡Clic! | grabación CC0 (Kenney, «RPG Audio») |
| `drop` | ¡Plin! ¡Plic! | grabación CC0 (Kenney, «Interface Sounds») |
| `wind` | ¡Fuuu! ¡Fiuuu! ¡Fuuush! ¡Suish! ¡Fffum! ¡Fuuum! | sintetizado |
| `hiss` | ¡Shhh! ¡Chis! ¡Pst! ¡Fsss! | sintetizado |
| `splash` | ¡Plaf! | sintetizado |
| `plop` | ¡Plof! ¡Flup! ¡Pof! | sintetizado |
| `thump` | ¡Pum! | sintetizado |
| `hop` | ¡Hop! | sintetizado |
| `growl` | ¡Grrr! ¡Rummm! | sintetizado |
| `hoot` | ¡Uuuh! | sintetizado |
| `flutter` | ¡Frrr! | sintetizado |

## Licencias (todo sin derechos de autor)

* **Grabaciones de terceros: todas CC0 1.0 (dominio público)**, que permite uso personal y comercial sin atribución. Se
  guardan tal cual en `tools/audio/sfx_src/` con su licencia:
  * **Kenney** (kenney.nl): [Impact Sounds](https://kenney.nl/assets/impact-sounds), [Interface Sounds](https://kenney.nl/assets/interface-sounds),
    [RPG Audio](https://kenney.nl/assets/rpg-audio): CC0 (`LICENSE-kenney-CC0.txt`).
  * **AntumDeluge**, «[Sheep Baa](https://opengameart.org/content/sheep-baa)» en OpenGameArt: CC0.
* **Sintetizados** (viento, siseo, chapoteo, burbuja, golpe sordo, salto, rugido, búho, aleteo): los genera `tools/audio/build_sfx.py`
  desde cero (ruido filtrado y tonos), así que son originales del proyecto y se dedican al dominio público (CC0), igual que el
  sonido de fondo (`tools/audio/make_ambient.py`).
* No se usó ningún sonido con atribución obligatoria (CC-BY), de «uso libre» sin licencia clara ni de Freesound (su acceso está
  bloqueado en este entorno y sus licencias son mixtas).

`python3 tools/audio/build_sfx.py` (necesita ffmpeg y numpy) regenera los 18 archivos a partir de `sfx_src/` y de la síntesis.

## Sonido de fondo por paquete

Cada paquete puede tener su fondo (`packAmbience` en `app/lib/src/audio/ambience.dart`); el cine, el holograma y el solo audio
eligen el del paquete del cuento (`ambienceFor(context, packId:)`), no el del paquete abierto. El **Mar de las Estrellas** suena
a olas que rompen despacio, madera de barco que cruje y alguna gaviota lejana, sobre el colchón de nana del de siempre, más bajo
(`tools/audio/make_ambient_mar.py`, sintetizado, CC0; 48 s en bucle, ≈ −25 dB de media y pico ≤ −9 dB, como el del Reino). Va en **AAC (`.m4a`)**, porque
iOS no reproduce Ogg. La **Aldea de las Nubes** suena a un zumbido grave de nave tranquila, un aire quieto de nubes y estrellas
que titilan con campanitas pentatónicas, sobre el mismo colchón (`tools/audio/make_ambient_cosmos.py`, sintetizado, CC0, 48 s,
≈ −24 dB de media, también en AAC; sin ruido que suba y baje, que suena a olas). Sus onomatopeyas reutilizan sonidos: ¡Brrrum! (`thump`), ¡Boing! (`hop`), ¡Clac! (`click`),
¡Glup! (`plop`) y ¡Zas! (`wind`).

## Pendiente

* **iOS y Ogg:** `ambient.ogg` y los 18 efectos `.ogg` probablemente no suenan en iPhone (AVPlayer no lee Ogg Vorbis). Habría que
  pasarlos a AAC como el fondo del mar y comprobarlo en un teléfono.

* **Los sonidos no se han oído en un teléfono**: se comprobaron por volumen y duración, no a oído. Habrá que revisar que el balido,
  el crujido y los sintetizados («viento», «gruñido», «búho») suenan bien y que no tapan la voz.
* Sonidos más específicos (un balido de cabra de verdad, una campana más suave) cuando aparezca una grabación CC0 mejor.
* Un efecto en la pantalla de texto y en «Leemos juntos» al tocar la frase.
