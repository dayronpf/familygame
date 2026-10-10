# 13 · Auditoría de las historias generadas (pack «Reino de la Luna»)

> **Estado:** auditoría de la v0.1.0 (§1–§4) y **resultado tras el cambio a premisas, v0.2.0 (§7)**.

> **Veredicto:** tienes razón. Las historias no tienen hilo conductor. No es un problema de redacción de un par de frases:
> es de **diseño del generador y del contenido**. El validador daba «0 problemas» porque solo comprueba gramática,
> no que el cuento tenga sentido. Y yo cometí un error: tras leer cuatro cuentos dije que «se leen bien para un MVP».
> No era cierto; debí avisar de que eran un relleno para probar la tubería.

Herramienta reproducible (usa el motor real):

```bash
cd packages/caldero_engine
dart run caldero_engine:audit_stories ../../content/packs/medieval/pack.json 3000
```

## 1. Lo que se midió (3 000 cuentos)

| Qué | Resultado | Por qué importa |
|---|---|---|
| Longitud | **193 palabras de media** (167–220), 15 frases ≈ **1,8 min** leído en voz alta | Un cuento para dormir se queda en un resumen: no hay escenas, solo anotaciones |
| Piezas de texto | **7** (una por etapa), de 16 a 40 palabras cada una | Cada etapa es un párrafo suelto sin transición |
| Conectores causales (porque, por eso, así que…) | **1 en todo el pack** (`op_3`, y es sobre un rasgo del héroe) | La trama no tiene causas ni consecuencias, solo «pasó esto, luego esto» |
| Variedad | **17 fragmentos en uso por enseñanza**, **108 esqueletos** distintos por enseñanza | Con 5–10 cuentos ya se repiten frases enteras |
| Hilo del reparto | El **ayudante** se nombra por primera vez a mitad del cuento (100 %), sin presentación; el **villano** desaparece en la etapa de prueba (100 %); el **héroe** no aparece en la resolución en el **83 %** y el cierre no nombra a nadie | El protagonista se desvanece justo cuando debería cobrar sentido su acción |
| Lugares | El texto **viaja al «lugar 2» y vuelve al 1** (2 cambios por cuento) sin contar el regreso; en los 3 fragmentos de «prueba» el lugar es sorteado y **no tiene relación con el problema** | El cuento «teletransporta» a los personajes |
| Presuposiciones | «Para resolverlo» (¿resolver qué?) en el 35 % de los cuentos; «Entonces… recordó los consejos» en el 33 %; «insistió **una vez más**» (no había insistido antes) en el 17 % | Frases que dan por contado algo que el cuento nunca dijo |
| El reparto importa | **No influye en qué texto sale** (324 esqueletos; 323 salen con distintos héroes y villanos) | Cambia el nombre, no la historia; Codicio y Sombra hacen exactamente lo mismo |

## 2. Lo que se ve al leer (ejemplos reales)

**Semilla 8 — Honestidad.** Mara encuentra una bolsita de monedas y «el bandido Sombra» le susurra que se la quede.
Corre a buscar a Aldo, que dice «cuenta conmigo». Y después: *«Para resolverlo, Mara tuvo que atravesar el bosque de los robles»*.
¿Resolver qué? ¿Por qué cruzar un bosque para devolver una bolsa? Aldo no vuelve a aparecer. *«Sombra insistió una vez más»*
(solo había susurrado una). La bolsa «volvió a manos de una anciana lavandera» que nadie había mencionado. No hay dilema:
devolver la bolsa no cuesta nada, así que la honestidad no se *vive*, se *anuncia*.

**Semilla 11 — Generosidad.** Una familia de viajeros llega sin comida a casa de Sombra, que les cierra la puerta. Mara
«corre a buscar al mago Zafiro» (¿para qué?), y juntos *«cruzaron la cueva de los cristales»* (¿por qué?). Después Mara
ofrece su manta a la familia. ¿Dónde estaba la familia mientras cruzaban una cueva? La etapa de «prueba» rompe el espacio
y el tiempo del cuento.

**Semilla 3 — Valentía.** *«Allí vivía Aldo»* ... *«En el río de plata»*: vive dentro de un río. Codicio bloquea el camino a un
bosque donde «nace la primera luz», pero la luz no vuelve a mencionarse; al final «el río de plata volvió a ser un lugar
seguro para dormir», y el río no tenía nada que ver.

## 3. Causas raíz

1. **Los fragmentos son párrafos independientes.** Cada uno se escribió sin saber cuál irá antes o después; lo único que los une
   son etiquetas de estado de una palabra (`tempted_a`). No comparten **hechos** (qué se encontró, de quién es, dónde está, qué
   está en juego), así que no pueden referirse unos a otros.
2. **Las etapas «ayuda» y «prueba» son genéricas.** Valen «para cualquier problema», y por eso no encajan con ninguno
   («Para resolverlo…»). Son la mayor fuente de sinsentidos. Además arrastran un lugar sorteado que no pertenece a la trama.
3. **Los lugares y los personajes son decorado.** Solo cambian un nombre. Un río y un castillo producen la misma frase;
   un duque avaro y un bandido se comportan igual; el rasgo del héroe no causa nada. El texto no distingue quién es quién.
4. **No hay conflicto real.** El villano solo susurra o bloquea; el héroe lo resuelve con una frase. No hay intento fallido,
   escalada ni coste. La enseñanza se enuncia al final en lugar de descubrirse por una elección con consecuencias.
5. **Es demasiado corto y plano.** 190 palabras no dan para presentar, motivar, sentir ni cerrar. Falta escena, deseo del
   héroe, reacción emocional, descripción mínima del mundo y una despedida que nombre a quien vivió la historia.
6. **El validador mide gramática, no sentido.** Y el pack lo escribí rápido, para probar la tubería de arte y valoración,
   no para ser leído.

## 4. Cómo debería ser (nivel a alcanzar)

Una muestra de **el nivel de calidad objetivo** (~330 palabras; borrador para tu aprobación, el texto final lo firma un autor humano, ADR-008):

> **La campana rota** (honestidad · héroe Aldo · ayudante Zafiro · villano Codicio)
>
> En la aldea de los molinos, cuando el sol se escondía tras las colinas, el aprendiz Aldo subía corriendo a la torre del
> castillo. Le encantaba la gran campana de bronce, la que avisaba a todo el reino cuándo era hora de comer, de trabajar y de
> dormir. Aldo era muy decidido, y aquella tarde decidió que la haría sonar él solito.
>
> Tiró de la cuerda con todas sus fuerzas. ¡CLANG! La campana se soltó, rodó por la escalera y se partió en dos. Aldo se quedó
> helado. Le temblaban las manos y el corazón le latía como un tambor.
>
> —¡Chisss! —susurró una voz. Era el duque Codicio, que siempre andaba contando monedas y buscando a quién echarle la culpa—.
> Nadie te ha visto, muchacho. Di que fue el viento y yo guardaré tu secreto… a cambio de un favor.
>
> Aldo escondió los pedazos bajo su capa y bajó corriendo. Esa noche nadie supo cuándo era hora de cenar ni de dormir: los
> panaderos sacaron el pan demasiado pronto, los niños siguieron jugando hasta tarde y el reino amaneció cansado y gruñón. Aldo
> no pudo pegar ojo; la capa le pesaba como si el bronce pesara el doble.
>
> Al día siguiente se lo contó todo al mago Zafiro, que lo escuchó sin enfadarse. «Un secreto es como una piedra en el zapato»,
> dijo. «Mientras más caminas, más duele. Pero no puedo contarlo por ti: solo puede hacerlo quien rompió la campana».
>
> En la plaza, el duque Codicio ya gritaba: «¡Alguien robó la campana! ¡Que todos paguen un impuesto para comprar otra!».
> Aldo sintió miedo del castigo. Pero pensó en los panaderos y en los niños cansados, dio un paso al frente y dijo: «Fui yo.
> Se me rompió sin querer y me dio miedo decirlo. Lo siento».
>
> Se hizo un silencio enorme. Entonces el herrero soldó el bronce, los niños lo pulieron y hasta el duque Codicio tuvo que
> ayudar, resoplando. Aquella noche la campana sonó más bonita que nunca, y Aldo se durmió tranquilo, ligero como una pluma.

Qué tiene que la hace funcionar: **un deseo** (hacer sonar la campana) → **un error con consecuencias que se ven** (el reino
desordenado) → **una tentación con un motivo del villano** → **un intento fallido** (esconderse y no poder dormir) → **ayuda que
no resuelve, orienta** → **una elección con coste** (miedo al castigo) → **consecuencia** que muestra por qué la verdad importa.
Todo lo que se menciona se usa después; nadie aparece sin presentarse.

## 5. Plan (N1–N3 hechos; ver §7)

| Paso | Qué | Resultado medible |
|---|---|---|
| **N1** ✅ | **Cambiar el modelo**: del «un fragmento suelto por etapa» a **premisas**: cada cuento nace de una premisa escrita por un autor, con **hechos compartidos** (`{objeto}`, `{dueño}`, `{lugar}`) que viven en todas las escenas y escenas (*beats*) escritas para esa premisa. Los lugares y personajes se eligen entre los **compatibles** (etiquetas: aldea/naturaleza/subterráneo, avaro/embustero…) y el texto tiene variantes según su tipo | Una escena puede referirse a lo anterior; Codicio y Sombra dejan de ser intercambiables |
| **N2** ✅ | **Reglas nuevas en el validador y en CI**: el héroe sale en ≥ 90 % de las escenas y en el cierre; el ayudante se presenta antes de actuar y sigue presente; el villano tiene motivo; un hecho no puede usarse sin haberse introducido; el lugar no cambia sin contar el viaje; ≥ 3 conectores causales; ≥ 330 palabras. `audit_stories` fija los umbrales y CI falla si no se cumplen | El sinsentido deja de poder entrar al pack |
| **N3** ✅ | **3 premisas completas** (una por enseñanza, p. ej. *La campana rota*, *El invierno del granero*, *La linterna apagada*) con 3 variantes en las escenas clave, escritas al nivel de §4, que tú revisas | Primeros cuentos que de verdad se pueden leer a un niño |
| **N4** ☐ | **Prueba con familias** (lectura en voz alta) y lectura de la valoración con «no tuvo sentido» / «se repitió». Recién con eso, escalar a ~12 premisas | Dato real, no mi impresión |

Lo que **no** hago sin que lo decidas: borrar el pack actual o cambiar el formato de packs (rompe cuentos guardados y
valoraciones; se haría como versión 2 del esquema).

## 6. Decisiones (resueltas)

Se aprobó el modelo de premisas, las 3 premisas de arranque (*La campana rota*, *La olla de los poquitos* —antes «El invierno del
granero»; la historia cambió al escribirla— y *La linterna apagada*) y la autoría literaria queda en manos del equipo (borradores
míos, revisión humana, ADR-008). Las 3 escenas «de prueba» del pack antiguo desaparecieron con él.

## 7. Resultado tras el cambio (v0.2.0, 3 000 cuentos, misma herramienta)

| Medida | Antes (v0.1.0) | Ahora (v0.2.0) |
|---|---|---|
| Palabras por cuento | 193 (≈ 1,8 min) | **565** (≈ 5 min) |
| Escenas | 7 sueltas | **9–10** enlazadas |
| Conectores causales | 1 en todo el pack | **5,8 por cuento** (mínimo 3, lo exige el validador) |
| Citas de diálogo | 2,0 (12 % sin ninguna) | **12,6** (ninguno sin diálogo) |
| Onomatopeyas / sonidos | casi ninguna | 90 % de los cuentos |
| Ayudante | aparece a mitad, sin presentación | **presentado en una escena que lo introduce** y sigue presente |
| Villano | desaparece en la «prueba» | motivo propio (favor, despensa, botín) y consecuencia |
| Héroe en el cierre | 0 % | **100 %** |
| Cambios de lugar sin contar | 2 por cuento | **0** (el validador exige `moves: true`) |
| «Para resolverlo…» | 35 % | 0 % |
| El reparto cambia el texto | no (solo el nombre) | **sí** (gesto, voz, miedo, objeto, favor, guarida) |
| Cuentos únicos (de 1 000 por enseñanza) | — | 92–97 % |

**Cómo se consiguió** (ADR-018): cada cuento nace de una **premisa** escrita por un autor, con **hechos compartidos** (el objeto, el
lugar, quién es quién), escenas con **variantes intercambiables** (cuentan lo mismo con otras palabras) y **atributos propios de cada
personaje** (`{helper.gesto}`, `{hero.miedo}`, `{villain.favor}`…). El validador **rechaza** el pack si alguien actúa antes de
presentarse, un personaje desaparece, el lugar cambia sin contar el viaje, hay menos de 300 palabras, menos de 3 causas o menos de
2 diálogos (17 pruebas, 9 de ellas negativas).

**Límites que siguen en pie (honestos):**

- **Una sola premisa por enseñanza.** Con 92–97 % de textos distintos, la *trama* se repite: quien lea «Honestidad» tres veces verá
  tres veces la campana (con otro héroe, ayudante, villano y otras palabras). Hacen falta **≥ 3 premisas por enseñanza** antes de
  salir a familias (plan N4).
- Sigue siendo un borrador: **lo firma un autor humano** y falta la prueba de lectura en voz alta con niños.
- Los 5 lugares con arte se reutilizan; faltan objetos de la trama dibujados (campana, linterna, olla) y personajes de reparto
  (Tomás, Lía, Teo).
- El validador mide estructura (presentaciones, causas, longitud…), **no talento**: no sabe si un cuento es bonito.
