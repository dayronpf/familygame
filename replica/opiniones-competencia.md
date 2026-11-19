# Lo que dicen las familias de la competencia (y qué hace Mininoches con eso)

- **Fecha:** 19 de noviembre de 2026
- **Método:** el de `replica-entrepreneur`: leer reseñas públicas, agruparlas por tema, contar cuántas veces aparece cada queja y sacar de ahí un plan de arreglos y un ángulo de venta. Las citas son textuales, cortas y llevan su enlace. Cuando algo es una paráfrasis, lo dice.
- **No se repite lo que ya está en** [recon.md](recon.md), [features.csv](features.csv) y [docs/28](../docs/28-referencia-readmio-y-plan.md) (pantallas y funciones de Readmio). Aquí está lo que **opinan los usuarios**, no lo que hace la app.

## Muestra y límites

| fuente | qué se leyó | reseñas |
| --- | --- | --- |
| App Store, feed público de reseñas (EE. UU., México y España) | Readmio, Storybook, Moshi, Peq Cuentos, Cuentos para Dormir HD | 414 |
| App Store, feed de Calm (EE. UU. y México) | 500 reseñas revisadas, y se usaron solo las que hablan de niños | 17 |
| Google Play (México, español), leído en el navegador como lo haría una persona | Readmio, Storybook, Moshi, Pequeños Cuentos | unas 125 a la vista |
| Trustpilot | Moshi (puntuación 2,0 con 202 reseñas; se leyeron las 20 de la primera página) | 20 |
| Mumsnet (foro de padres) | Un hilo sobre Moshi | 1 hilo, unos 6 mensajes |

**En total:** unas 580 reseñas leídas. Muchas son de 5 estrellas y casi sin texto («Excelente»), así que lo que sirve para este estudio sale sobre todo de las unas **150 reseñas de 1 a 4 estrellas** y de las de 5 estrellas que traen un «pero…».

**Límites:**
- **Reddit no se pudo leer.** El buscador no devolvió hilos y la búsqueda pública de Reddit bloquea las lecturas automáticas. No hay citas de Reddit.
- **Google Play no da un enlace para cada reseña**, así que se enlaza la ficha de la app. Además, solo se leyó lo que la página muestra sin entrar a ninguna cuenta.
- **App Store tampoco tiene enlace por reseña:** se enlaza el feed público, que la muestra con su número (`id`).
- **Calm** casi no tiene reseñas sobre niños, porque es una app para adultos. Storytel y Audible se dejaron fuera: no son apps de cuentos para dormir y en sus reseñas no se encontró nada sobre niños.
- **Los conteos se hicieron a mano** («la vi N veces» en lo leído) y son aproximados. No son porcentajes del mercado.

## 1. Fuentes

| # | app | fuente | URL |
| --- | --- | --- | --- |
| F1 | Readmio | App Store EE. UU. (feed) | https://itunes.apple.com/us/rss/customerreviews/id=1473021827/sortBy=mostRecent/json |
| F2 | Readmio | App Store México (feed) | https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json |
| F3 | Readmio | App Store España (feed) | https://itunes.apple.com/es/rss/customerreviews/id=1473021827/sortBy=mostRecent/json |
| F4 | Readmio | Google Play México (4,9 ★, 49,2 mil opiniones) | https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419&gl=MX |
| F5 | Storybook (Familify) | App Store México (feed) | https://itunes.apple.com/mx/rss/customerreviews/id=1355190474/sortBy=mostRecent/json |
| F6 | Storybook | App Store España (feed) | https://itunes.apple.com/es/rss/customerreviews/id=1355190474/sortBy=mostRecent/json |
| F7 | Storybook | App Store EE. UU. (feed) | https://itunes.apple.com/us/rss/customerreviews/id=1355190474/sortBy=mostRecent/json |
| F8 | Storybook | Google Play México | https://play.google.com/store/apps/details?id=app.storybook.story&hl=es_419&gl=MX |
| F9 | Moshi Kids | App Store EE. UU. (feed) | https://itunes.apple.com/us/rss/customerreviews/id=1306719339/sortBy=mostRecent/json |
| F10 | Moshi Kids | App Store México (feed) | https://itunes.apple.com/mx/rss/customerreviews/id=1306719339/sortBy=mostRecent/json |
| F11 | Moshi Kids | Google Play México | https://play.google.com/store/apps/details?id=com.mindcandy.sleepstories&hl=es_419&gl=MX |
| F12 | Moshi Kids | Trustpilot | https://www.trustpilot.com/review/moshikids.com |
| F13 | Moshi Kids | Mumsnet, hilo de padres | https://www.mumsnet.com/talk/sleep/4546245-6yo-wont-sleep-without-moshi-sleep-app |
| F14 | Peq Cuentos / Pequeños Cuentos (Diveo) | App Store México (feed) | https://itunes.apple.com/mx/rss/customerreviews/id=977016099/sortBy=mostRecent/json |
| F15 | Pequeños Cuentos | Google Play México | https://play.google.com/store/apps/details?id=com.diveomedia.little.stories.bedtime.books.kids&hl=es_419&gl=MX |
| F16 | Cuentos para Dormir: HD | App Store México (feed) | https://itunes.apple.com/mx/rss/customerreviews/id=428467179/sortBy=mostRecent/json |
| F17 | Cuentos para Dormir: HD | App Store España (feed) | https://itunes.apple.com/es/rss/customerreviews/id=428467179/sortBy=mostRecent/json |
| F18 | Calm | App Store EE. UU. (feed, páginas 1 a 5) | https://itunes.apple.com/us/rss/customerreviews/page=1/id=571800810/sortBy=mostRecent/json |
| F19 | Calm | App Store México (feed, páginas 1 a 5) | https://itunes.apple.com/mx/rss/customerreviews/page=1/id=571800810/sortBy=mostRecent/json |

**Por qué estas apps:** según la búsqueda pública de la App Store en México, son las de cuentos para dormir con más valoraciones. Readmio tiene unas 2.400, Storybook unas 2.300, Peq Cuentos unas 4.100 y Cuentos para Dormir HD unas 1.700. Storybook es mexicana y hecha en español. Moshi es la más conocida en inglés.

## 2. Lo que más odian (ordenado por cuántas veces aparece)

### 2.1 El cobro que llega por sorpresa al final de la prueba, y no poder cancelar · **unas 34 reseñas, 5 apps, 3 fuentes**

Es la queja más fuerte y la de más rabia: casi todas son de 1 estrella y usan palabras como «estafa» y «ladrones». Hay cuatro variantes:
- les cobran antes de que termine la prueba;
- cancelaron y les cobraron igual;
- no encuentran dónde dar de baja;
- después de una promoción llega el precio completo sin aviso.

- «They charge you before the free trial ends» · Readmio, App Store EE. UU., id 14692432509 ([F1](https://itunes.apple.com/us/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))
- «el día de hoy me realizan un cargo por $999.00 por una renovación que yo no autorice» · Storybook, App Store México, id 12443650183. **Es justo el caso de una promoción de 3 meses que se renueva al precio completo** ([F5](https://itunes.apple.com/mx/rss/customerreviews/id=1355190474/sortBy=mostRecent/json))
- «Estoy por terminar la prueba gratis de 7 días Pero no recibí ningún correo para dar la baja.» · Storybook, Google Play, 8 de octubre de 2026 ([F8](https://play.google.com/store/apps/details?id=app.storybook.story&hl=es_419&gl=MX))

### 2.2 Casi todo es de pago, lo gratis no alcanza para probar y no se puede elegir · **unas 45 reseñas, las 6 apps, 3 fuentes**

Es lo que más aparece, pero con menos enojo: muchas son de 3 a 5 estrellas (del tipo «me encanta, pero»). Lo que de verdad molesta es **sentirse engañado**, más que tener que pagar. Por ejemplo, un cuento que se corta a la mitad, o un cuento gratis al día que no se puede escoger.

- «ponen un cuento en su página web y lo dejan a medias para que uno descargue la app» · Readmio, Google Play, 9 de noviembre de 2026 ([F4](https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419&gl=MX))
- «I just wish I could choose the book instead of having to rely on the one free book a day rule.» · Readmio, App Store EE. UU., id 14680012575 ([F1](https://itunes.apple.com/us/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))

**Lo mismo en América Latina:** al menos 3 reseñas dicen que **no tienen tarjeta** o que la tienda no la acepta.
- «no todos contamos con tarjeta de crédito ni débito ni nada por el estilo» · Storybook, Google Play ([F8](https://play.google.com/store/apps/details?id=app.storybook.story&hl=es_419&gl=MX))
- «me dice que no es válido la tarjeta para los pagos» · Readmio, Google Play, Venezuela ([F4](https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419&gl=MX))

### 2.3 Fallas técnicas: el audio se corta, la app se cierra o congela el teléfono · **unas 36 reseñas, 5 apps**

Unas 22 son de Storybook en Android, casi todas de 2025 y 2026, y muchas de familias que **ya pagaron el año**. A la hora de dormir, una falla pesa el doble: el niño se altera.

- «Se traba mucho, hace que el celular se bloquee, la música se para sola y la voz sigue» · Storybook, Google Play, 23 de diciembre de 2025 ([F8](https://play.google.com/store/apps/details?id=app.storybook.story&hl=es_419&gl=MX))
- «los audios no se reproducen y estoy ha hecho que mi hija esté triste.» · Storybook, Google Play, 8 de septiembre de 2025 ([F8](https://play.google.com/store/apps/details?id=app.storybook.story&hl=es_419&gl=MX))

### 2.4 Pagaron y no tienen acceso: en otro teléfono, en la tableta del niño o sin compartir en familia · **unas 22 reseñas, 5 apps**

- «Pague la subscripción anual hace poco más de un mes y ahora no puedo acceder a todos los cuentos» · Readmio, App Store México, id 14176571006 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))
- «Why would a children’s app not allow family sharing?» · Moshi, App Store EE. UU., id 14495874618 ([F9](https://itunes.apple.com/us/rss/customerreviews/id=1306719339/sortBy=mostRecent/json))
- «al instalarlo en una tablet controlada mediante family link de Google, no permite acceder a recuperar compras» · Pequeños Cuentos, Google Play, 17 de septiembre de 2026 ([F15](https://play.google.com/store/apps/details?id=com.diveomedia.little.stories.bedtime.books.kids&hl=es_419&gl=MX))

También hay 2 casos de Storybook (Google Play, 2020 y 2021) de familias que pagaron un pago único y luego vieron los cuentos con candado cuando la app pasó a suscripción.

### 2.5 Contenido repetido, que se acaba o que no se renueva · **unas 15 reseñas, 4 apps**

- «ya los sabemos todos, les hace falta meter más cuentos» · Readmio, App Store México, id 14227022154 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))
- «it runs out of content pretty quickly. Not worth 65$» · Storybook, App Store EE. UU., id 12925086285 ([F7](https://itunes.apple.com/us/rss/customerreviews/id=1355190474/sortBy=mostRecent/json))

### 2.6 Idioma, acento y vocabulario · **unas 11 reseñas, 3 apps**

Moshi casi no tiene español: lo dicen 6 reseñas. Cuentos HD tiene quejas viejas por el acento (latino contra castellano), por la ortografía y por traducciones malas. En Pequeños Cuentos, una persona critica que usen palabras rebuscadas.

- «el unico detalle es que esta en ingles» · Moshi, Google Play, 2019 ([F11](https://play.google.com/store/apps/details?id=com.mindcandy.sleepstories&hl=es_419&gl=MX))
- «con frecuencia utilizan palabras que me parecen difíciles y que los pequeños no siempre entienden» · Pequeños Cuentos, Google Play, 20 de septiembre de 2026 ([F15](https://play.google.com/store/apps/details?id=com.diveomedia.little.stories.bedtime.books.kids&hl=es_419&gl=MX))

### 2.7 Cuentos sin dibujos (Readmio) · **6 reseñas, 2 apps**

Readmio quita las ilustraciones a propósito, para que el niño no mire la pantalla. A una parte de las familias con niños pequeños no les gusta.

- «My 3 yr old wants pictures not an audio book. He’s not 40.» · Readmio, App Store EE. UU., id 12790973871 ([F1](https://itunes.apple.com/us/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))
- «debería agregar ilustraciones a sus cuentos para que los niños puedan verlo» · Readmio, App Store México, id 14676215005 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))

### 2.8 Descuentos que no son lo que dicen y ventanas que insisten dentro de una app ya pagada · **6 reseñas, 2 apps**

- «te ofrecen supuestos descuentos que no son reales» · Storybook, App Store México, id 14644454142 ([F5](https://itunes.apple.com/mx/rss/customerreviews/id=1355190474/sortBy=mostRecent/json))
- «I had to get through three pop up’s just to get to my kid’s sleep story.» · Calm, App Store EE. UU., id 14760768288 ([F18](https://itunes.apple.com/us/rss/customerreviews/page=1/id=571800810/sortBy=mostRecent/json))

### 2.9 Religión metida sin avisar · **4 reseñas en contra y 1 a favor, 2 apps** (tema delgado, pero se repite)

Las familias están divididas. Unas piden cuentos laicos o la opción de quitar los religiosos; otras piden más cuentos cristianos. Lo que molesta es que **los pongan sin preguntar**, sobre todo dentro de los cuentos gratis.

- «Para mi los cuentos deben ser Laicos , o tener la opción de poder escuchar o no ese tipo de contenido» · Storybook, App Store México, id 11230004294 ([F5](https://itunes.apple.com/mx/rss/customerreviews/id=1355190474/sortBy=mostRecent/json))
- «uno de esos 7 gratuitos, si o si, es una historia bíblica, lo cual me parece imposición de religión» · Readmio, Google Play, 31 de octubre de 2026 ([F4](https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419&gl=MX))

### 2.10 El final del cuento despierta al niño, o la narración va muy rápido · **4 reseñas, 2 apps** (delgado)

- «By the time the story ends she is about to fall asleep, but then wakes up.» · Storybook, App Store EE. UU., id 12917020048 ([F7](https://itunes.apple.com/us/rss/customerreviews/id=1355190474/sortBy=mostRecent/json))
- «al escuchar que se acabó se despierte, y empecemos de nuevo» · Storybook, Google Play, 2019 ([F8](https://play.google.com/store/apps/details?id=app.storybook.story&hl=es_419&gl=MX))
- En Mumsnet, una madre cuenta que Moshi no se puede dejar sonando seguido y que la niña se levanta a pedir otro cuento. *Paráfrasis* ([F13](https://www.mumsnet.com/talk/sleep/4546245-6yo-wont-sleep-without-moshi-sleep-app)).

### 2.11 Inteligencia artificial · **3 reseñas, 2 apps** (delgado, pero importa)

- «this app used AI to animate each of these book covers. What an insulting, and useless feature.» · Readmio, App Store EE. UU., id 14590135419 ([F1](https://itunes.apple.com/us/rss/customerreviews/id=1473021827/sortBy=mostRecent/json))
- «los cuentos tienen varias imágenes y no son con inteligencia artificial» · Pequeños Cuentos, Google Play, 9 de septiembre de 2026, **como elogio** ([F15](https://play.google.com/store/apps/details?id=com.diveomedia.little.stories.bedtime.books.kids&hl=es_419&gl=MX))

Readmio responde en Google Play que sus historias «son creadas por personas reales, no por inteligencia artificial»: lo usan como argumento de venta.

### 2.12 Temas sueltos (1 o 2 reseñas: se anotan, pero no son tendencia)

- **Un niño instaló la app y cobraron el año** (Storybook, App Store España, id 12216618732), y una niña que llora pidiendo la suscripción (Moshi, App Store EE. UU., id 14644389909).
- **Una mala palabra en un cuento narrado:** Readmio, Google Play, 14 de septiembre de 2026, con 24 votos de «útil».
- **«No la sé usar»:** Readmio, App Store México, id 13839008014.
- **El niño se engancha a la app para dormir y no se duerme sin ella:** Mumsnet ([F13](https://www.mumsnet.com/talk/sleep/4546245-6yo-wont-sleep-without-moshi-sleep-app)).

## 3. Lo que les falta o piden

| petición | veces | ejemplo textual |
| --- | --- | --- |
| **Que suene seguido**: lista de reproducción, otro cuento o música al terminar | 4 | «que se puedan hacer listas de reproducción para darle play y que corran todos los cuentos» · Readmio, App Store México, id 14117719610 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json)) |
| **Usar la app sin internet** después de descargar | 3 | «que se pudieran descargar para escucharlos sin internet» · Readmio, id 14117719610 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json)). Pequeños Cuentos tiene 2 parecidas ([F15](https://play.google.com/store/apps/details?id=com.diveomedia.little.stories.bedtime.books.kids&hl=es_419&gl=MX)) |
| **Imágenes en el cuento** | 6 | Ver 2.7 |
| **Escuchar y leer a la vez** | 1 | «cuando activo la opción de escuchar me gustaría ir leyendo al mismo tiempo» · Readmio, id 13901929277 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json)) |
| **Música suave mientras el adulto lee** | 1 | «la opción de música para dormir al tiempo que estas leyendo» · Readmio, id 13706917234 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json)) |
| **Cuentos de temporada** (Navidad, fiestas) | 2 | «sleep story’s for kids dedicated to certain parts of the year and holidays» · Calm, id 14695883021 ([F18](https://itunes.apple.com/us/rss/customerreviews/page=1/id=571800810/sortBy=mostRecent/json)). Hay otra de Storybook EE. UU. |
| **Temas nuevos**: ciencia y cómo se hacen las cosas, el destete, más cuentos cristianos | 3 | «relatos sobre cómo se creó la luz, cómo se hace una silla» · Readmio, id 13839008014 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json)) |
| **Ojear otros cuentos mientras suena uno** | 1 | «I’d like to explore other stories while one is playing» · Storybook, id 13452843014 ([F7](https://itunes.apple.com/us/rss/customerreviews/id=1355190474/sortBy=mostRecent/json)) |
| **Controlar los efectos de sonido** (menos, o más bajos) | 2 | «los efectos de sonido son demasiado altos y fuertes» · Readmio, Google Play ([F4](https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419&gl=MX)) |
| **Pagar por semana o por mes** en vez del año | 2 | «Yo quería pagar semanalmente» · Readmio, id 13928706226 ([F2](https://itunes.apple.com/mx/rss/customerreviews/id=1473021827/sortBy=mostRecent/json)) |
| **Narración más lenta y cuentos más largos para dormir** | 2 | Ver 2.10 |
| **Elegir el cuento gratis** | 1 | Ver 2.2 |
| **Compartir en familia** y tabletas con Family Link | 3 | Ver 2.4 |

**Lo que elogian y conviene no perder** (sale en las de 5 estrellas):
- **leer a oscuras desde el teléfono:** «podemos leerlos con la luz apagada antes de dormir», Readmio, Google Play ([F4](https://play.google.com/store/apps/details?id=com.readmio.app&hl=es_419&gl=MX));
- **que no tenga anuncios y siga sonando con la pantalla apagada:** «there is no ads and you can turn of the device and it will still play», Moshi, id 14421122496 ([F9](https://itunes.apple.com/us/rss/customerreviews/id=1306719339/sortBy=mostRecent/json));
- **la enseñanza de cada cuento;**
- **los efectos de sonido;**
- **la voz calmada.**

## 4. Lo que nadie resuelve bien

1. **Una prueba gratis en la que se pueda confiar.** Las cinco apps de pago tienen quejas de cobros sorpresa, y ninguna se diferencia por avisar de forma visible antes de cobrar ni por hacer fácil la cancelación. Storybook responde las quejas pidiendo que escriban a su soporte.
2. **Cuentos para dormir hechos en español de América Latina, con dibujos y con voz.** Readmio no tiene dibujos. Moshi casi no tiene español. Storybook tiene voz y es en español, pero falla en Android y se volvió muy religiosa. Peq Cuentos y Cuentos HD cobran cuento por cuento o lo gratis es mínimo. Nadie junta las tres cosas sin un pero.
3. **Que la noche termine bien.** Nadie dice resolver el final del cuento: el silencio de golpe o el «¿repetir?» que despierta al niño, la reproducción seguida o el apagado gradual.
4. **Que la compra no se pierda.** Cambiar de teléfono, la tableta del niño con Family Link, compartir en familia o el paso de pago único a suscripción: todas las apps tienen quejas de este tipo.
5. **Las familias sin tarjeta.** Varias reseñas latinoamericanas dicen que no pueden pagar. Ninguna app lo resuelve, porque depende de la tienda, pero sí se puede dar más gratis y mejor elegido.
6. **El contenido religioso como opción.** Hoy o lo incluyen sin avisar (Storybook, y un cuento gratis de Readmio) o no lo hay. Nadie lo marca para que cada familia decida.

## 5. Plan para Mininoches

Leyenda: ✅ ya lo resuelve · 🟡 a medias · ☐ no. Las tallas S, M y L son como en [docs/07](../docs/07-backlog.md). El orden va por **impacto** (cuántas veces aparece la queja y con cuánto enojo) por **lo barato que es arreglarlo**.

| # | problema (sección) | ¿Mininoches? | qué tiene hoy | arreglo concreto | talla |
| --- | --- | --- | --- | --- | --- |
| 1 | Cobro sorpresa y no saber cancelar (2.1) | 🟡 | El muro de pago muestra la línea de tiempo «Día 5: te avisamos», hay una notificación local 2 días antes de que termine la prueba (`store/paywall_page.dart`) y Ajustes muestra «Prueba gratis hasta…». **No hay botón para cancelar** y **no hay aviso antes de que termine la promoción de 3 meses a 0,99**, que es justo el caso de Storybook con la renovación a $999. | **a)** Botón «Cancelar o cambiar mi plan» en Ajustes, que abra la página de suscripciones de Google Play. **b)** Notificación 3 días antes del fin de la promoción («desde el [fecha] el precio pasa a USD 2,99 al mes»). **c)** Si el adulto no dio permiso de notificaciones, un aviso dentro de la app los días 5 y 6. **d)** Que el muro de pago diga, en una línea, qué pasa al terminar la promoción. | S |
| 2 | Audio que se corta y app que se congela en Android (2.3) | 🟡 sin comprobar | Hay voz grabada que se descarga y queda guardada, y la voz del teléfono si falta el audio. El plan maestro dice «falta probarlo en un teléfono» (A6). | Probar a fondo en 2 o 3 teléfonos Android baratos: pantalla apagada, llamada que entra, audífonos que se desconectan, poca memoria, sin internet a mitad de la descarga, la app minimizada. Que un audio que falla **nunca deje la pantalla trabada**: pasar a la voz del teléfono sin cortar. | M |
| 3 | Pagaron y no tienen acceso (2.4) | 🟡 | Hay «Restaurar compras», verificación en el servidor y no hay cuentas que puedan fallar. | Probar la restauración en otro teléfono y en una tableta con **Family Link**. Ver si Google Play permite **compartir la suscripción con la familia** y activarlo si se puede. Escribir una ayuda de 3 pasos («cambié de teléfono»). | S–M |
| 4 | Lo gratis no alcanza o se siente trampa (2.2) | 🟡 | 3 cuentos gratis y **completos**, que no se cortan a la mitad, y una prueba de 7 días. | **a)** Que el muro de pago y la ficha de la tienda digan que los gratis son cuentos completos. **b)** Un **cuento gratis de la semana** que rota y que la familia puede elegir de una lista corta. Encaja con B1, «un cuento nuevo cada semana». **c)** Nunca cortar un cuento a la mitad para cobrar. | M |
| 5 | Contenido repetido o que no se renueva (2.5) | 🟡 | Catálogo propio, recomendación de la noche que evita lo ya contado, insignia «Nuevo». El servidor todavía no publica cuentos nuevos (B1). | Hacer **B1**: un cuento nuevo grabado cada semana, desde el servidor y con aviso en el inicio. Prometer el ritmo («cuentos nuevos cada semana») solo si se puede cumplir. | M |
| 6 | El final despierta al niño; que suene seguido (2.10, §3) | 🟡 | «Solo escuchar» con la pantalla oscura y un temporizador (10, 20 o 30 min) que **baja la voz, la música y el brillo poco a poco** antes de apagar (`ui/sleep_timer.dart`). Al terminar el cuento no sigue nada (B6 está pendiente). | **a)** Al terminar en «Solo escuchar», seguir con música suave hasta que acabe el temporizador, sin pantalla de «¿repetir?» ni sonido de premio (B6). **b)** Opción «otro cuento después», con 2 o 3 cuentos seguidos y el mismo apagado gradual. | S (a) · M (b) |
| 7 | Idioma, acento y vocabulario (2.6) | ✅ | Español de América Latina, textos auditados con una regla contra palabras de España y una voz latina (Isabela). | Mantener la regla del validador y sumar una lista de **palabras difíciles** para la edad, como «farfulló» o «barruntó». | S |
| 8 | Cuentos sin dibujos (2.7) | ✅ | «Ver y escuchar» con escenas animadas. | Nada que arreglar. Es un argumento de venta frente a Readmio, sin nombrarlo. | — |
| 9 | Descuentos falsos y ventanas que insisten (2.8) | ✅ casi | Sin anuncios. La oferta de prueba sale **una sola vez**, al terminar el asistente. | Regla escrita: ninguna ventana de venta ni de «comparte la app» antes de un cuento, y nunca a quien ya paga. El precio de la oferta tiene que ser el mismo que cobra la tienda. | S |
| 10 | Religión sin avisar (2.9) | ✅ por lo visto | En una búsqueda rápida de palabras en `content/` no salió ningún cuento religioso. | Mantenerlo así y decirlo en la ficha de la tienda («cuentos con valores para todas las familias»). Si algún día hay cuentos religiosos, que vayan marcados y en su propio paquete. | S |
| 11 | La inteligencia artificial (2.11) | 🟡 riesgo | Los textos los **escriben personas** ([docs/04](../docs/04-contenido-y-derechos.md), [docs/00](../docs/00-vision.md)), pero la voz es **sintética** (ElevenLabs). | En la ficha y en la app, decir solo lo que es cierto: «escritos por personas». **No decir «sin IA» ni «narrados por personas».** Si alguien pregunta por la voz, responder con la verdad. Que la animación sea de arte propio, como ya lo es. | S |
| 12 | El niño toca «comprar» (2.12) | ✅ | La compra la protege la cuenta de la tienda del adulto (decisión del 18 de noviembre de 2026, docs/36 §9). | Revisar en la prueba cerrada que la tienda pida huella o contraseña. Si no la pide, volver a poner la pregunta para adultos **solo** en «Comprar». | S |
| 13 | Ojear el catálogo mientras suena un cuento (§3) | ☐ | — | Mini reproductor abajo en «Solo escuchar». Solo vale la pena si las familias lo piden: es una sola reseña. | M |
| 14 | Escuchar y leer a la vez (§3) | ✅ | «Leemos juntos» resalta la frase que va leyendo la voz. | Nada. | — |

**Los 5 arreglos que más rinden**, en orden: **#1** (cancelar y avisar antes del fin de la promoción, S), **#2** (probar el audio en teléfonos baratos, M), **#6a** (música al terminar en «Solo escuchar», S), **#3** (restaurar, Family Link y compartir en familia, S–M) y **#4** (decir que los gratis son completos y dar un cuento gratis de la semana, M).

## 6. Ángulo de posicionamiento

Las tres frases caben en la descripción corta de Google Play (80 caracteres como máximo). No dicen cuántos cuentos hay, no dicen edades y no nombran a la competencia.

**A. «Cuentos animados para dormir, sin anuncios y con aviso antes de cobrar»** (71 caracteres)
- *Para* familias que se sintieron estafadas por una prueba gratis.
- *Por qué:* responde a la queja más repetida y con más enojo (2.1, unas 34 reseñas en 5 apps) y suma «animados» (2.7) y «sin anuncios» (2.8). Es una promesa que Mininoches ya cumple: el aviso 2 días antes existe.
- *Riesgo:* hablar de cobro en la primera línea puede sonar raro. Va mejor como segunda frase de la descripción larga.

**B. «Ve, escucha o léele tú: cuentos con enseñanza y pantalla oscura para dormir»** (75 caracteres)
- *Para* el adulto cansado que unas noches lee y otras solo quiere poner el audio.
- *Por qué:* junta los tres modos, que ninguna app de la competencia ofrece juntos (Readmio no tiene dibujos, Moshi y Storybook no tienen modo para que lea el adulto). También usa lo que más elogian (la enseñanza, leer a oscuras) y responde a 2.10 con la pantalla oscura y el temporizador.
- *Riesgo:* es la más descriptiva y la menos emotiva.

**C. «Cuentos para dormir en español latino, escritos por personas y sin anuncios»** (75 caracteres)
- *Para* familias latinoamericanas que no encuentran algo hecho para ellas, o que desconfían de la IA.
- *Por qué:* responde a 2.6 (Moshi en inglés, vocabulario de España o rebuscado) y a 2.11 (desconfianza de la IA). «Escritos por personas» es cierto según docs/04, y Readmio ya lo usa como argumento.
- *Riesgo:* **no** se puede ampliar a «narrados por personas»: la voz es sintética.

**Recomendación:** usar **B** como descripción corta, porque vende la experiencia de cada noche. Poner **A** y **C** en las dos primeras líneas de la descripción larga:

> «Te avisamos antes de que termine la prueba, y cancelas cuando quieras. Cuentos escritos por personas, en español de Latinoamérica.»

Así la confianza (A) y el origen (C) quedan a la vista sin ocupar la frase principal.

**Recordatorios:**
- Las citas de este documento son **investigación**: no van en la ficha ni en anuncios, como testimonios.
- Mininoches no se compara con ninguna app por su nombre en la tienda.
