# 06 · Modelo de contenido

Es el **contrato** entre autores de contenido y motor. Está implementado y validado en
`tools/prototype/caldero.py` con el pack `content/packs/demo/pack.json`.

## Entidades

| Entidad | Campos clave | Notas |
|---|---|---|
| **Personaje** | `id`, `given` (nombre propio), `noun` (especie/oficio), `gender` (m/f), `roles` (`hero`, `helper`, `villain`…), `alignment` (positive/negative/ambiguous), `trait` (adjetivo con género) | Un personaje puede tener varios roles. Positivo/negativo y principal/secundario salen de `alignment` + `roles`. |
| **Lugar** | `id`, `noun`, `gender`, `mood` | Se usa como escenario principal y secundario. |
| **Enseñanza** | `id`, `text` | Un valor humano por cuento. |
| **Fragmento** | `id`, `stage`, `values`, `requires`, `adds`, `text`, `scene` | La unidad narrativa. Etapas: `opening`, `trouble`, `helper`, `test`, `climax`, `resolution`, `closing`. |

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

## Coherencia por estado

```
tr_hon  (trouble)   adds: tempted
he_hon  (helper)    requires: tempted
cl_hon  (climax)    requires: tempted     adds: honest_choice
re_hon  (resolution)requires: honest_choice
```

Un desenlace solo puede aparecer si antes ocurrió lo que lo justifica. Es la base para que los cuentos tengan sentido.

## Ejemplo real generado (`--seed 3 --value honestidad`)

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
