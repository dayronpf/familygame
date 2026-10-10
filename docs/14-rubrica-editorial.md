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
