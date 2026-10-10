# 06 · Modelo de contenido

Es el **contrato** entre autores de contenido y motor. Se describe formalmente en
[`content/schema/pack.schema.json`](../content/schema/pack.schema.json) (esquema 1), se implementa en
`packages/caldero_engine` (Dart) y se valida con el pack `content/packs/demo/pack.json`.
El bloque `pack` lleva `schema: 1`; el motor rechaza esquemas que no entiende.

## Entidades

| Entidad | Campos clave | Notas |
|---|---|---|
| **Personaje** | `id`, `given` (nombre propio), `noun` (especie/oficio), `gender` (m/f), `roles` (`hero`, `helper`, `villain`…), `alignment` (positive/negative/ambiguous), `trait` (adjetivo con género) | Un personaje puede tener varios roles. Positivo/negativo y principal/secundario salen de `alignment` + `roles`. |
| **Lugar** | `id`, `noun`, `gender`, `mood` | Se usa como escenario principal y secundario. |
| **Enseñanza** | `id`, `name` (para mostrar), `text` (frase de cierre) | Un valor humano por cuento. |
| **Fragmento** | `id`, `stage`, `values`, `requires`, `adds`, `text`, `scene`, `weight` (opcional, 1 = normal, 0 = desactivado) | La unidad narrativa. Etapas: `opening`, `trouble`, `helper`, `test`, `climax`, `resolution`, `closing`. |

Campos a añadir en S1–S3: `age_band`, `scare` (0–3), `duration_s`, `tags`, `article_override`, `plural`, `lang`, `author`, `review_status`.

## Tokens de plantilla

| Token | Resultado (ej. *Nilo, el erizo* / *Luna, la tortuga*) |
|---|---|
| `{hero}` | Nilo / Luna |
| `{hero.el}` / `{hero.El}` | el erizo / la tortuga (mayúscula al inicio de frase) |
| `{hero.un}` | un erizo / una tortuga |
| `{hero.del}` / `{hero.al}` | del erizo / de la tortuga · al erizo / a la tortuga |
| `{hero.en}` / `{hero.En}` | en el erizo… (útil en lugares: *en el bosque*) |
| `{hero.o}` | o / a (llamad**o**/llamad**a**) |
| `{hero.trait}` | curioso / valiente |

Roles disponibles: `hero`, `helper`, `villain`, `place`, `place2`.

## Esquema 2: premisas (el que usa el pack medieval)

El esquema 1 (un fragmento suelto por etapa) no daba hilo: ver [13](13-auditoria-de-historias.md). El **esquema 2** cuenta una
**premisa** = una historia completa escrita por un autor.

```jsonc
{ "pack": { "schema": 2, … },
  "characters": [{ …, "tags": ["wise"], "attrs": { "gesto": "se acarició la larga barba blanca", "miedo": "…", "voz": "…" } }],
  "places":     [{ …, "tags": ["village", "settlement"] }],
  "props":      [{ "id": "campana", "noun": "campana", "gender": "f" }],      // objetos de la trama
  "premises": [{
    "id": "campana", "value": "honestidad", "title": "La campana rota",
    "cast": {                                  // ranuras con requisitos; el orden es el de elección
      "hero":   { "kind": "character", "roles": ["hero"] },
      "helper": { "kind": "character", "roles": ["helper"], "tags": ["wise"] },
      "torre":  { "kind": "place", "ids": ["castillo"] },
      "item":   { "kind": "prop",  "ids": ["campana"] } },
    "beats": [{                                 // escenas, en orden
      "id": "error", "introduces": ["villain"], "moves": false,
      "variants": [{ "id": "a", "requires": ["villain:greedy"], "adds": ["escondido"],
                     "scene": { "bg": "torre", "actors": ["hero"], "mood": "tension" },
                     "text": "{hero} tiró de la cuerda y {item.el} se partió. {hero.miedo}." }] }] }] }
```

- **Tokens nuevos:** `{rol.atributo}` (frases propias del personaje), `{item}` y `{item.el}` (objetos y lugares de cualquier ranura).
- **Etiquetas del reparto** que una variante puede exigir en `requires`: `ranura:id` (`villain:codicio`) y `ranura:etiqueta`
  (`villain:greedy`); las `adds` de una escena anterior siguen funcionando.
- **`introduces`**: la escena que presenta a un personaje u objeto (debe nombrarlo; nadie puede nombrarlo antes).
- **`moves: true`**: el texto cuenta un desplazamiento (obligatorio si cambia el fondo `bg`).
- **Las variantes de una escena cuentan los mismos hechos.** Si una debe contar otra cosa, es otra premisa.
- **Atributos con varias formas:** `"gesto": ["se frotó las manos", "se atusó la perilla"]`. Cada uso en un cuento toma la
  siguiente (empezando por una al azar), así un gesto no se repite. El validador revisa **todas** las formas.
- **Ilustración de cada escena** (`scene`): `bg` (ranura de lugar) · `stage` (lista de personajes de izquierda a derecha:
  `"hero:scared"`, `"@tomas:sad"`, `{"who":"hero","clip":"scared","x":0.3}` o `{"rig":"tomas"}` para un secundario) · `mood` ·
  `props` (`{"prop":"olla","x":0.5,"clip":"boil","scale":1,"lift":0,"front":true,"emit":false}`) · `light`
  (`dusk`/`night`/`dark`/`cold`) · `offstage` (nombrados en el texto pero ausentes, p. ej. `["tomas"]`).
- **`npcs`** de la premisa: los secundarios dibujados y con qué palabras los nombra el texto (`"tomas": ["Tomás"]`).
- **Regla texto ↔ ilustración:** quien sale dibujado (menos el héroe) debe estar nombrado en el texto de esa escena, y quien el
  texto nombra debe salir dibujado o figurar en `offstage`. Máximo 6 personajes por ilustración.
- La receta de valoración lleva ids `premisa.escena.variante` (`campana.error.a`).
- Reglas de coherencia que bloquean un pack: [13 §5](13-auditoria-de-historias.md) y `validatePack`.

## Receta del cuento y pesos

Cada cuento generado expone su **receta** (`story.recipe`): pack y versión, versión del motor, semilla, enseñanza, ids del reparto y ids de
los fragmentos. No lleva texto ni nombres; es lo que viaja con una valoración ([12](12-valoraciones-y-mejora-continua.md)).
El **peso** (`weight`) de un fragmento cambia su probabilidad de salir; con pesos iguales el motor genera exactamente los mismos cuentos
que sin pesos. Los pesos se ajustan con las valoraciones y se publican dentro de una versión nueva del pack.

## Coherencia por estado

```
tr_hon  (trouble)   adds: tempted
he_hon  (helper)    requires: tempted
cl_hon  (climax)    requires: tempted     adds: honest_choice
re_hon  (resolution)requires: honest_choice
```

Un desenlace solo puede aparecer si antes ocurrió lo que lo justifica. Es la base para que los cuentos tengan sentido.

## Ejemplo real generado con el prototipo Python (`--seed 3 --value honestidad`)

> Había una vez, en la colina de la aurora, un erizo llamado Nilo. El erizo era muy curioso y le encantaba explorar cuando caía la tarde.
>
> Una tarde, Nilo encontró un farolito dorado que no era suyo. Nadie lo había visto. La urraca Brisca, que miraba desde lejos, susurró: «Quédatelo, nadie se enterará».
>
> Nilo sintió un cosquilleo en la barriga. Se sentó a pensar y se lo contó todo a la tortuga Luna. «Un secreto pesa mucho más que la verdad», le dijo la tortuga.
>
> Al caer la noche, Nilo y Luna cruzaron el río Murmullo. Cada ruido parecía enorme, pero caminaron juntos, uno al lado del otro.
>
> La urraca Brisca insistió una vez más. Pero Nilo apretó el farolito contra su pecho y respondió con voz firme: «No es mío, y lo voy a devolver».
>
> El farolito volvió con su dueña, la pequeña luciérnaga Lumi, que lloró de alegría. Y la urraca Brisca, avergonzada, descubrió que la verdad brilla más que cualquier tesoro.
>
> Y colorín colorado, este cuento se ha acabado. Ahora, a descansar, que mañana habrá nuevas aventuras.
>
> **Enseñanza:** Ser honesto nos hace sentir ligeros, aunque nadie nos esté mirando.

(Con `--debug` se ven además las directivas de escena de cada fragmento: fondo, actores y ánimo, que alimentarán las animaciones.)

## Qué aprendimos del spike S-01

- El modelo **funciona** y la coherencia por estado evita los desenlaces incongruentes.
- La gramática de plantillas necesita un **validador**: durante el spike aparecieron errores como «Y La urraca…» (artículo en mayúscula a mitad de frase) que solo se detectan renderizando todos los repartos. Por eso `--lint` ya forma parte del flujo y pasará a CI.
- Con 5 personajes y 3 enseñanzas el cuento todavía se siente repetitivo: **la variedad sale de tener muchos fragmentos por etapa**, no solo de más personajes. Las cifras del pack semilla (≈120 fragmentos) apuntan a eso.
- Pendiente de diseñar: plurales, sustantivos femeninos con *el*, varios villanos/ayudantes en un mismo cuento y variaciones por edad.

## Escala objetivo del contenido (a largo plazo)

| Elemento | Pack gratis | 1.0 completo | Meta continua |
|---|---|---|---|
| Personajes | ~25 | ~100 | cientos |
| Lugares | ~15 | ~60 | cientos |
| Villanos / obstáculos | ~6 | ~30 | cientos |
| Fragmentos | ~120 | ~600 | miles |
| Enseñanzas | 6 | 12 | 30+ |

Producir esto exige un **flujo editorial**: plantilla de autor → validador → revisión → pack. Es el segundo carril del equipo.
