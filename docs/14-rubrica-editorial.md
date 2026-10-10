# 14 · Rúbrica editorial y ciclo de mejora de los cuentos

> Para qué sirve: poner **la misma vara** a todos los cuentos y poder medir si cada iteración mejora. La rúbrica la aplican
> revisores independientes (personas o agentes) leyendo un **corpus** de cuentos generados. La señal definitiva sigue siendo la de
> los niños y los adultos que leen (valoraciones, [12](12-valoraciones-y-mejora-continua.md)); esto es el filtro previo.

## El ciclo (cada vuelta)

1. **Generar el corpus:** `dart run caldero_engine:sample_stories content/packs/medieval/pack.json <carpeta> 24` (24 cuentos por
   enseñanza, repartos y variantes distintos; cada escena indica fondo, personajes en pantalla y ánimo).
2. **Revisar** con la rúbrica (≥ 3 lectores independientes con lentes distintas, cada uno con cuentos distintos).
3. **Sintetizar:** defectos repetidos primero (si 3 lectores ven lo mismo, es real), y lo que funciona (para no romperlo).
4. **Corregir** en el pack (`content/packs/medieval/pack.json`), el arte o el motor. Un cambio por causa, no parches.
5. **Medir:** `validate_pack` (estructura) + `audit_stories` (cifras) + nueva revisión del corpus. Se anota la vuelta en
   `docs/14-…` §«Registro de vueltas».
6. Cuando haya valoraciones reales: contrastar la nota de los lectores con la de las familias (¿coinciden?).

## Criterios (1 = flojo, 3 = aceptable, 5 = para guardar)

| # | Criterio | Qué se mira |
|---|---|---|
| C1 | **Hilo y causalidad** | Cada escena nace de la anterior; nada aparece de la nada; el problema se plantea, se intenta y se resuelve por una razón |
| C2 | **Personajes y voz** | Cada personaje quiere algo y se distingue por cómo habla y actúa; el villano tiene motivo y no es de cartón |
| C3 | **Emoción y ritmo** | Hay tensión que sube y alivio; se siente miedo, ternura o risa; no todo es igual de plano |
| C4 | **Lenguaje para 4–7 años** | Frases cortas y claras, palabras concretas, sonoridad (onomatopeyas, repeticiones con gracia), se lee bien en voz alta; sin muletillas repetidas |
| C5 | **La enseñanza se vive** | Se descubre por una elección con coste, no por un sermón; no sobra la explicación |
| C6 | **Imagen y detalle** | Detalles concretos y sensoriales (olor, sonido, luz, tacto), humor tierno; no genérico |
| C7 | **Texto ↔ ilustración** | Quien sale dibujado está en el texto de esa escena y quien importa sale dibujado; los personajes no «desaparecen»; lo que se dibuja es lo que se cuenta |
| C8 | **Cierre para dormir** | Termina en calma, con sensación de seguridad; nombra al héroe |

## Cómo informa cada lector

- Nota de 1 a 5 por criterio **por premisa** (con 1–2 líneas de evidencia citando archivo y escena).
- **Defectos priorizados** (crítico / importante / menor) con cita literal y **propuesta de reescritura concreta**.
- **Lo que funciona** (frases, escenas, recursos) para conservarlo.
- **Tics repetidos** entre cuentos (frases, estructuras).

## Registro de vueltas

### Vuelta 1 — pack v0.2.0 (3 premisas, 565 palabras de media)

Tres lectores independientes (lentes: hilo/personajes/texto↔imagen · lenguaje/ritmo · emoción/enseñanza), 24 cuentos cada uno.
**Notas medias** (campana / olla / linterna): C1 hilo 3·3,7·3 · C2 personajes 2,7·2,3·2,7 · C3 ritmo 3,3·3·3,3 ·
C4 lenguaje 3,7·3,7·4 · C5 enseñanza 3,3·3,3·3,3 · **C7 texto↔imagen 2·2·2,7** · C8 cierre 4·4·4.

**Defectos que coincidieron en los tres (y qué se hizo en la v0.3.0):**

| Defecto | Corrección |
|---|---|
| Tomás, Lía, Teo y la cabrita están en el texto y nunca se dibujan; el ayudante se dibuja en cierres donde el texto no lo nombra | Secundarios dibujados (8 rigs nuevos); regla de validador **texto ↔ ilustración** (quien sale dibujado está en el texto y viceversa, salvo `offstage`) |
| Campana: el villano promete «diré que fue el viento» y luego acusa a Tomás; el héroe no elige ni paga nada | El villano calla a cambio de un pago y *alguien tendrá que cargar con la culpa*; el héroe **entrega** su paga/merienda (la mentira cuesta); al confesar, el villano la devuelve |
| Linterna: el héroe nunca decide ir; una luciérnaga «enciende una mecha» | Frase de elección («Iré, pero iré con miedo»), pedernal del farolero, regalos de los 4 ayudantes unificados como «fuente de luz» |
| Voces idénticas (los 4 ayudantes dicen lo mismo; los villanos solo cambian el gesto) | `consejo` y `el_paso` con una variante **por ayudante**; villanos con variantes propias (Codicio cuenta monedas, Sombra sisea); atributos con **varias formas** que rotan sin repetirse |
| Muletillas («se subió la capucha», «voz de campanilla rota» 3–5 veces por cuento; «ya que») | 3–4 formas por gesto/voz; menos «ya que» |
| La enseñanza se explica de más (consejo anuncia el desenlace; «pero nadie se enfadó») | Consejo como pregunta/anécdota; Tomás frunce el ceño («un mes limpiando la torre»); se quita el sermón del cierre de la linterna |
| Faltan ternura y momentos de peso | Escenas nuevas: `promesa` (Tomás), `ultima_miga` (Teo se ríe), `se_apaga` (la luz se apaga y sigue) |
| El villano apenas tiene presencia | Presente en `escondite` (vigilando), `el_miedo` (mira al roble), `la_chispa` (se le dibuja huyendo) |

**Pack v0.3.0:** 3 premisas, 70 variantes, 10–11 escenas, **668 palabras de media (≈ 6 min)**, hasta 6 personajes en pantalla,
objetos animados y luz por escena.

### Vuelta 2 — pack v0.3.0 → v0.4.0 (3 lectores, 24 cuentos el lector A)

Notas del lector A (C1…C8; campana / olla / linterna): campana 3·3·4·4·4·4·3·4, olla 4·3·3·4·3·4·3·4,
linterna 3·4·4·4·4·4·3·4. Lo más grave: el pedernal nunca llegaba a las manos del héroe; el villano no era expuesto
en la consecuencia; la acusación a Tomás no tenía causa; los tres ayudantes de la olla decían lo mismo; el sacrificio
del pan no costaba nada; el cierre dejaba a dos niños durmiendo en la plaza.
**Corregido en v0.4.0:** el farolero entrega el pedernal; el villano calla a cambio de un pago y luego devuelve y repara;
escena nueva `torre_vacia` (Tomás con la cuerda) y `mantas` (los niños duermen bajo techo); voz propia por ayudante
(`idea`); concordancias («lo miraba»); tics de gesto («se encogió de hombros», «chasqueó los dedos»); regalos de luz
coherentes. Tope de palabras 800 → 900.

### Vuelta 3 — pack v0.4.0 → v0.5.0 (3 lectores, 12 cuentos cada uno)

| Lector (lente) | Campana | Olla | Linterna |
|---|---|---|---|
| A · C1 hilo / C2 voz / C7 imagen | 3,5 · 3 · 3,5 | 3,5 · 3 · 3,5 | 4 · 3,5 · 3 |
| B · C3 ritmo / C4 lenguaje / C6 imagen | 4 · 3,5 · 4 | 3,5 · 3,5 · 4 | 4,5 · 4 · 4,5 |
| C · C3 emoción / C5 enseñanza / C8 cierre | 4 · 4 · 4,5 | 4 · 3,5 · 4 | 4,5 · 4 · 4 |

Veredicto de los tres: **sin defectos críticos de contenido**; la escena de la torre vacía es lo mejor del lote.
Defectos que coincidieron y su corrección en v0.5.0:

| Defecto | Corrección |
|---|---|
| Olla: el acertijo/idea del ayudante no lleva a «es una olla» (A, B, C) | `idea` por ayudante con pista clara (Zafiro: «¿qué se llena con un poquito de cada uno…? Pista: burbujea»; Mara: «treinta puñados»; Aldo: «se llena hasta mi casco»); el héroe responde «¡Una olla!» |
| Olla: la sopa no alcanza, la salva la despensa del villano (C) | Tras `ultima_miga`: «en el fondo de la olla todavía quedaba sopa»; el villano trae comida «para los días de nieve» |
| Olla: niños sin techo ni familia, Lía casi no actúa (A, C) | Porche de Rosa, mantas, «mañana buscaremos a vuestra tía»; Lía y Teo echan sus pedacitos; `Rosa` dibujada en el cierre |
| Campana: la confesión «se me rompió» es la excusa de siempre; enseñanza no demostrada (C) | «Tiré de la cuerda sin permiso y la rompí»; entrega de los dos pedazos en la plaza (objeto dibujado); también reconoce el pago al villano; **enseñanza nueva: «Un secreto pesa más que la verdad, aunque la verdad dé miedo.»** |
| Campana: el villano acusa sin ganar nada; pedazos incoherentes entre escenas; la luz de «amanecer» no cuadraba (A) | «Me han visto subir… alguien tendrá que ser el culpable»; pedazos bajo la cama (sin «bajo la capa»); acusación a la luz del día; «Cuando la plaza se llenó de vecinos…» |
| Campana: consecuencia sermoneada («Gracias por decir la verdad») y villano repara con el mismo castigo que el héroe (B, C) | Variante b sin sermón; el villano friega los escalones y devuelve lo suyo («una merienda entera, aunque ya se había comido la otra») |
| Linterna: seguridad (un niño solo de noche), villano suelto, cierre que salta al amanecer (C, A, B) | «Los mayores no se atrevían… no iba a ir solo»; el ayudante vigila en el borde; el botín aparece al pie del roble y vuelve a su dueño con una nota; el cuento acaba con el héroe dormido mirando la luz |
| Linterna: «gruñó otra vez» sin gruñido, «que total daba igual», «manta mojada», Lía incoherente en la variante b | Reescritos; el ayudante remata con su propia frase (`orgullo`) en lugar de «Y aun así fuiste» idéntico |
| Frases de más de 30 palabras (B) | Partidas en las seis escenas señaladas |

**Pack v0.5.0:** 805 palabras de media (≈ 7,3 min), 11,3 escenas, tope 950 palabras. Pendiente (no corregido todavía):
solo 3 premisas (una por enseñanza), voces de los héroes casi idénticas, cabrita sin dibujar, tics de superficie
(«bajito», «tragó saliva», «aquella noche»).
