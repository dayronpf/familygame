# 27 · Pack «Aldea de las Nubes» (cohetes y planetas)

Tercer pack, con el mismo tamaño y el mismo camino que el Mar de las Estrellas ([26](26-pack-mar-de-las-estrellas.md)): **30 cuentos**
(6 de 2–3, 9 de 4–5, 9 de 6–8 y 6 de 9–12), las seis enseñanzas y arte propio generado por código. Ya está en el catálogo como
«próximamente» (`id: cosmos`). La app maneja varios paquetes desde el pack del mar, así que aquí no hace falta trabajo de app salvo
el catálogo, la portada y el sonido.

## 1. El tono: el espacio que no da miedo

La Aldea de las Nubes es un pueblito de casas redondas que flota sobre las nubes, con un observatorio y una plataforma de cohetes.
Desde allí, los niños viajan a la luna, a planetas de cristal y de jardines, y vuelven a casa a dormir.

* **La oscuridad es bonita.** El espacio está lleno de luces: estrellas, nebulosas de colores, lunas que brillan. Los cuentos ayudan a
  perder el miedo a la noche (lo promete la ficha del catálogo).
* **La ciencia, de verdad pero sencilla:** la luna tiene cráteres y poca gravedad (se salta muy alto), las estrellas están lejísimos,
  los planetas giran. Nada que luego haya que «desaprender».
* **Nada de guerras ni de rayos láser.** Los aliens son vecinos curiosos; los robots, amigos. El «malo» se equivoca y se arregla.
* **Sustos suaves** (perderse en la nave, una tormenta de polvo lunar) solo de 6–8 en adelante.

## 2. Personajes

| Ranura | Personaje | Quién es |
|---|---|---|
| `hero` (m) | **Orión** | Cadete de la aldea; quiere ponerle nombre a una estrella. |
| `hero` (f) | **Lira** | Cadete; sabe todos los botones del cohete de memoria. |
| `helper` | **Comandante Aurora** | Astronauta veterana que lleva la escuela de cadetes: paciente y risueña. |
| `helper` | **Tornillo** | Robot amable y algo torpe, con antena y pantalla en el pecho; hace las preguntas más raras. |
| `helper` | **Abuela Osa** | La astrónoma del observatorio; sabe historias de cada constelación. |
| `villain` (6–8, 9–12) | **Barón Brillo** | Coleccionista que quiere todas las estrellas fugaces en su vitrina; aprende a dejarlas libres. |
| `villain` (6–8, 9–12) | **Zumbo** | Pequeño alien travieso de tres ojos que cambia las cosas de sitio; solo quería que le hicieran caso. |
| secundarios | perrito astronauta **Chispa**; **Pip**, un niño de la aldea; **Nube**, una niña de la aldea; el panadero y la cartera de la aldea | |

## 3. Lugares (12)

`aldea` (aldea de las nubes), `observatorio`, `plataforma` (de lanzamiento), `cabina` (del cohete), `luna` (superficie lunar),
`planeta_cristal`, `planeta_jardin`, `anillos` (anillos de asteroides), `estacion` (estación espacial), `taller` (de Tornillo),
`dormitorio` (con ventana a las estrellas) y `espacio` (el cohete entre las estrellas).

## 4. Objetos

`telescopio`, `estrella_caida` (una estrellita que cayó y brilla), `cohete_juguete`, `casco`, `mapa_estelar`, `piedra_lunar`,
`flor_cristal`, `llave_inglesa`, `globo` y `semilla_luz`.

## 5. Fases

1. **Personajes** (Orión, Lira, Aurora, Tornillo, Abuela Osa, Barón Brillo, Zumbo, Chispa y secundarios), con miedo y pijama.
2. **Fondos, objetos y gestos** (flotar en gravedad cero, saltar en la luna).
3. **Cuentos**, por edades, con el validador y la lectura con niño y con niña.
4. **Sonido** (fondo espacial), catálogo, ficha y versión.

## 6. Estado

| Fase | Estado |
|---|---|
| 1. Personajes | ✅ `tools/art/cosmos_kit.py` → `art/cosmos/` (25 dibujos, 193 KB): Orión y Lira con casco de burbuja y traje espacial, la comandante Aurora, el robot Tornillo y el alien Zumbo (con el **esqueleto humano**: les sirven todos los gestos), la Abuela Osa, el Barón Brillo con chistera, Pip, Nube, el panadero y la cartera; variantes de miedo y pijama; el perrito Chispa con los huesos de la cabrita. |
| 2. Fondos, objetos y gestos | ✅ `tools/art/cosmos_scenes.py` (12 lugares, 19 escenas, 198 KB: los de la Tierra con sus horas; los del espacio, siempre de noche de estrellas) y `tools/art/cosmos_props.py` (10 objetos). Gestos nuevos para todos los packs: `float` (sin gravedad) y `moonhop` (salto lunar). |
| 3. Cuentos | 🟡 **2–3 años (6):** *La estrellita perdida* (amistad), *El globo de Nube* (honestidad), *Las piedras de la luna* (generosidad), *La luz de la noche* (valentía: perder el miedo a la oscuridad), *El cohete que no volaba* (humildad), *La semilla de luz* (perseverancia). Faltan 9 de 4–5, 9 de 6–8 y 6 de 9–12. El pack solo se abre en desarrollo (`kDebugMode`). |
| 4. Sonido, catálogo y versión | ☐ |
