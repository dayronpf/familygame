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
