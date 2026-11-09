# 19 · Nombre del juego y dominios

Consulta del 2026‑10‑11. Se probaron **110 nombres** (cuento + caldero + luna + arrullo + lumbre…, en español y algunos en inglés)
contra los registros oficiales de **.com, .net, .app y .org**. `tools/naming/check_domains.py` repite la comprobación
(`candidatos.txt` es la lista completa).

> **Qué significa «libre».** El servicio RDAP del registro contestó «no existe» (404): el dominio **no está registrado hoy**. No garantiza
> que se pueda comprar al precio normal (puede estar reservado o ser *premium*), ni que el nombre esté libre como **marca**. Antes de
> decidir hay que confirmarlo en un registrador (ver «Lo que falta»). Se probó con dominios conocidos para validar el método
> (google.com → registrado; un nombre inventado → libre).

## Recomendación

| # | Nombre | Por qué | .com | .app | .net | .org |
|---|---|---|---|---|---|---|
| 1 | **Cuentacaldero** | Juega con «cuentacuentos» y conserva la imagen del caldero. Se dice y se recuerda fácil; distintivo (el nombre actual es descriptivo y difícil de proteger como marca) | libre | libre | libre | libre |
| 2 | **Sopaluna** | Caldero + luna en dos sílabas; tierno y fácil para un niño. Ojo: puede sugerir comida o un restaurante | libre | libre | libre | libre |
| 3 | **Arrullaluna** | «Arrullar» (cantar o contar para dormir) + luna: dice «cuentos para dormir» sin explicarlo | libre | libre | libre | libre |
| 4 | **Cuentalumbre** | «Lumbre» (el fuego del hogar, el del caldero) + cuento: cálido y poco común | libre | libre | libre | libre |
| 5 | **Caldero de Cuentos** (el actual) | Mantiene lo ya hecho (splash, pantallas, enlaces) | libre (`calderodecuentos`) | libre | libre | libre |

Para el mercado en inglés: **Cauldrella** y **Sleepwick** (sleep + wick, la mecha de una vela) están libres en los cuatro.

**Mi sugerencia:** **Cuentacaldero** como nombre y «cuentos para dormir con dibujos animados» como descriptor. Si se prefiere algo más
corto y para niños, **Sopaluna**. Mantener «Caldero de Cuentos» como nombre del *primer paquete* o eslogan no cuesta nada.

## Otros nombres con los cuatro dominios libres

`cuentilla` · `cuentallama` (ojo: se lee «llama», el animal) · `caldaluna` · `lunacaldero` · `cuenticaldero` · `ollamagica` · `ollacuentos` ·
`cuentacaldo` · `soplaluna` · `soplacuentos` · `cuentacuna` · `cunacuentos` · `cuentarrullo` · `arrullacuentos` · `fabulumbre` · `cuentolumbre` ·
`cuentahechizo` · `hechizuentos` · `cuentabrujas` · `murmullocuentos` · `susurracuentos` · `reinodeluna` (el nombre del primer paquete) ·
`holofabula` · `holoarrullo` · `holocuento` (si se quiere destacar el holograma) · `lunadecuentos` · `sopadecuentos` · `cuentasol` · `cuentabruma` ·
`mininoches` · `velacuentos` · `hadacuentos` · `cuentamecedora`.

## Descartados (el .com está tomado)

`cuentaluna`, `cuentanube`, `nubecuentos`, `cuentario`, `fabulario`, `duermecuentos`, `suenacuentos`, `cuentoverso`, `cuentolandia`, `cuentanoche`,
`nanacuentos`, `moonpot`, `moontale`, `dreamtale`, `storywick`, `sleepytale`, `fablemoon`, `lullatale`, `lunaria`, `erase`, `arrullo`, `ollaluna`.

## Otras señales (superficiales)

Búsqueda web de **Cuentacaldero, Sopaluna, Arrullaluna, Cuentalumbre, Cuentilla** y **«Caldero de Cuentos»** junto a «app», «cuentos», «juego»:
no apareció ninguna app, juego ni marca con esos nombres (sí muchas apps de cuentos con otros: Cuentología, Peq Cuentos, Kido, «Cuentos para
dormir: HD»…). Es una pista, **no** una búsqueda de marcas: los buscadores no muestran bien las marcas registradas ni las apps nuevas.

## Lo que falta antes de decidir

1. **Comprar o reservar el dominio** (.com y .app como mínimo) en un registrador y ver el precio real de cada uno.
2. **Marca:** buscar el nombre en la base de marcas de cada país donde se publicará (OEPM/EUIPO, USPTO, IMPI, INDECOPI…) y en la
   [base de marcas de la OMPI](https://branddb.wipo.int/), en las clases 9 (software), 41 (entretenimiento) y 28 (juegos). Idealmente con un abogado de marcas.
3. **Nombre en las tiendas:** comprobar que no esté ya usado en App Store y Google Play.
4. **Redes:** reservar el usuario en Instagram, TikTok, YouTube y X.
5. **Oído en otros idiomas:** que no signifique algo raro en inglés ni portugués (hoy el contenido es solo en español).
6. **Cambio de nombre en el código:** el nombre aparece en la app (`theme`, splash, textos), el PDF del holograma (`APP_NAME` en
   `tools/guide/make_holograma_pdf.py`), el mensaje de compartir y el identificador de la app (que, ya publicado, no se puede cambiar).

## Segunda ronda (8-nov-2026): nombres sin caldero

El logo y el inicio ya no tienen caldero ni fuego (ahora son un libro abierto y una luna con carita), y «caldero» evoca
brujería. Se buscaron nombres alegres, sin connotación religiosa ni de brujería, que encajen con el libro y la luna.
Comprobado con `tools/naming/check_domains.py` (mismas salvedades: dominio no registrado hoy ≠ marca libre).

| Nombre | Idea | .com | .app | .net | .org |
|---|---|---|---|---|---|
| **Luna de Cuentos** (`lunadecuentos`) | El icono tal cual (luna + libro); conserva «de Cuentos» | libre | libre | libre | libre |
| **Cuentaestrellas** | «Contar estrellas» + contar cuentos; juguetón y de noche | libre | libre | libre | libre |
| **Página Luna** (`paginaluna`) | Libro + luna, corto | libre | libre | libre | libre |
| **Arrullaluna** | «Arrullar» + luna: cuentos para dormir | libre | libre | libre | libre |
| **Mininoches** | Para niños, corto y tierno | libre | libre | libre | libre |
| **Estrellacuentos** | Estrella + cuentos | libre | libre | libre | libre |
| **Libro de Luna** (`librodeluna`) | Muy descriptivo | libre | libre | libre | libre |
| **Cuentapáginas** | Contar páginas: leer juntos | libre | libre | libre | libre |

Descartados en esta ronda (el .com está tomado): `lunalibro`, `libroluna`, `lunitacuentos`, `nochecitas`, `cuentitos`,
`cuentaconmigo`, `leemosjuntos`, `lunalee`.

### Comprobación completa de la segunda ronda (8-nov-2026)

Para tener página web y correo hace falta más que un dominio sin registrar. Se comprobó, por nombre:

1. **Dominio:** whois/RDAP (no registrado) y **Porkbun** (se puede comprar a precio normal, no «premium»): los 8 tienen
   `.com` a USD 11.81/año y `.app` a USD 14.93/año (8.75 el primer año). Con el dominio, el correo (`hola@…`) sale gratis con
   el reenvío de correo del registrador o con un buzón de pago (Porkbun, Zoho, Google Workspace).
2. **Tiendas:** búsqueda en Google Play y en App Store (España, México y EE. UU.).
3. **Marcas:** [TMview](https://www.tmdn.org/tmview) (oficinas de la UE, España, Latinoamérica y otras), búsqueda «contiene». El
   método se validó con «readmio» (aparece su marca en Brasil).
4. **Web:** búsqueda general del nombre exacto.

| Nombre | Dominio .com / .app | Google Play | App Store | Marcas (TMview) | Web | Veredicto |
|---|---|---|---|---|---|---|
| **Página Luna** (`paginaluna`) | se pueden comprar | nada | nada | ninguna | nada | ✅ **limpio**; es el icono (libro + luna) |
| **Mininoches** | se pueden comprar | «ningún resultado» | nada | ninguna | nada | ✅ **limpio**; corto y tierno |
| **Arrullaluna** | se pueden comprar | nada | nada | ninguna | libro «Arrullos de luna» | ✅ limpio; algo difícil de escribir |
| **Cuentapáginas** | se pueden comprar | nada | nada | ninguna | nada | ✅ limpio; poco distintivo |
| **Estrellacuentos** | se pueden comprar | salen apps de horóscopo y tarot | nada | ninguna | nada | ⚠️ se asocia a astrología |
| **Luna de Cuentos** | se pueden comprar | **«Luna: cuentos para dormir»** (MyToonTime) | **«Luna: Cuentos para Dormir IA»** | — | — | ❌ choca con una app del mismo tipo |
| **Cuentaestrellas** | se pueden comprar | nada | **«CuentaEstrellas» (SPOTTERON)** | — | — | ❌ nombre exacto ya usado |
| **Libro de Luna** | se pueden comprar | — | apps de libros y «Grimoire: Libro de Sombras» | — | — | ❌ confuso y con aire de brujería |

Pendiente antes de comprar: reservar el usuario en Instagram, TikTok y YouTube (piden iniciar sesión para comprobarlo) y,
si el presupuesto lo permite, una consulta con un abogado de marcas en los países donde se publicará.

## Decisión (8-nov-2026): **Mininoches**

Elegido por el dueño. Se cambió con `tools/rename_app.py` (app, Android, iOS y guía en PDF), más la ficha de las tiendas, el
README, la visión y el nombre del APK de descarga (`mininoches.apk`). **No se compra dominio por ahora** (decisión del dueño);
`mininoches.com` y `.app` estaban libres y a precio normal el 8-nov-2026. Sin tocar, a propósito: los identificadores técnicos
(`com.calderodecuentos.cuentos`, paquetes `caldero_*`), que no se ven; el `applicationId` hay que decidirlo antes de publicar.
