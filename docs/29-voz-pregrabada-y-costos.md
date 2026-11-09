# 29 · Voz de calidad sin pagar por cada cuento

> **Va en la última fase**, después de las compras (decisión del 8 de noviembre de 2026, ver [28 §3](28-referencia-readmio-y-plan.md)).
> 8 de noviembre de 2026. Precios de terceros a esa fecha: **confirmarlos en la página de cada proveedor** antes de presupuestar.

## 1. El problema

Hoy la app narra con la voz del teléfono (`flutter_tts`). ElevenLabs suena mucho mejor, pero si se llama a su API **cada
vez que se genera un cuento**:

| Supuesto | Valor |
|---|---|
| Cuento medio | ≈ 6 000 caracteres (8–10 min) |
| ElevenLabs Multilingual v2 / Flash | ≈ USD 0.08 / 0.04 por 1 000 caracteres |
| Costo por cuento | ≈ USD 0.48 / 0.24 |
| Familia que lee 5 noches por semana (≈ 260 cuentos al año) | **≈ USD 62–125 al año** |
| Suscripción anual en Latinoamérica | ≈ USD 10–15 al año, menos la comisión de la tienda |

Pierde dinero con cada suscriptor. Descartado.

## 2. La idea clave: nuestros cuentos ya son finitos

El motor no inventa texto: **combina fragmentos escritos por personas** ([06](06-modelo-de-contenido.md)). Hoy los cuatro
paquetes suman **1 139 fragmentos y ≈ 427 000 caracteres** por idioma. Si cada fragmento se narra **una sola vez** y se
guarda el audio, la app solo tiene que **unir audios** cuando arma un cuento. El costo de voz deja de depender de cuántos
cuentos se lean y pasa a depender de cuánto **contenido** publicamos.

### Lo que varía dentro de un fragmento

| Hueco | Cómo se resuelve |
|---|---|
| `{helper}`, `{villain}`, `{item…}`, `{place…}`, `{camino…}` | Son listas cerradas del paquete. Se renderiza **cada combinación que el motor puede producir** (el motor ya sabe enumerarlas; el validador recorre 4 000 semillas). Estimación: × 3–8 sobre el texto base → **≈ 1.5–3.5 M caracteres por idioma**. |
| Género del héroe (`{hero.o}`, `{hero.El}`…) | Dos versiones, niño y niña. |
| **Nombre del niño** (`{hero}`) | Está en **92 %** de los fragmentos (1 953 veces). No se puede pregrabar todo. Ver §3. |

## 3. El nombre del niño: frases cortadas en el nombre

1. El texto de cada frase se parte por el nombre: `«…y entonces» · [NOMBRE] · «miró al dragón.»`.
2. Cada trozo se renderiza con ElevenLabs pasándole `previous_text` / `next_text` (la API lo admite para continuidad) con un
   nombre de relleno, para que la entonación quede natural alrededor del hueco.
3. El **nombre** se graba aparte, con la misma voz, en 3 entonaciones: *a mitad de frase*, *antes de coma* y *final de frase / exclamación*.
4. **Nombres frecuentes pregrabados**: los ~2 000 nombres más comunes por idioma × 3 entonaciones × voz ≈ 60 000 caracteres ≈ USD 5.
5. **Nombre raro**: el servidor lo pide **una vez** (≈ 30 caracteres, menos de un centavo), lo guarda para siempre y lo comparte con
   cualquier otra familia que tenga ese nombre. Mientras llega, el cuento usa el apodo del héroe del paquete.
6. La app une los trozos con un cruce de 20–40 ms. Prueba de escucha antes de decidir: si se nota el corte, ver §6 opción C.

## 4. Costos con voz pregrabada

| Concepto | Una vez | Recurrente |
|---|---|---|
| Renderizar un idioma con 1 voz (≈ 3 M caracteres a USD 0.08) | **≈ USD 240** | — |
| Cada voz extra (narradora y narrador) | ≈ USD 240 | — |
| Cada idioma nuevo (traducido y revisado por personas) | ≈ USD 240 por voz | — |
| Cada paquete nuevo (≈ 100 k caracteres × combinaciones) | ≈ USD 25–60 | — |
| Nombres raros | — | céntimos al mes |
| Plan de ElevenLabs con licencia comercial (para tener créditos al renderizar) | — | solo los meses en que se renderiza |
| Almacenar y servir audio (≈ 70 h por idioma y voz; Opus 32 kbps ≈ 1 GB) en Cloudflare R2 | — | ≈ USD 0.015/GB al mes, **sin costo de salida** |

**Costo de voz por suscriptor: prácticamente cero.** Un cuento de 10 min en Opus 32 kbps pesa ≈ 2.4 MB; se descargan solo
los trozos de ese cuento y quedan en caché.

**Antes de pagar:** confirmar en los términos de ElevenLabs que el audio generado con plan de pago puede **guardarse y
distribuirse dentro de la app** (uso tipo audiolibro). Si hubiera límites, aplicar la misma idea con la opción B.

## 5. Varios idiomas con la misma calidad

- ElevenLabs Multilingual mantiene **la misma voz** en ~30 idiomas: el narrador suena igual en español, inglés o portugués.
- El texto de cada idioma lo escribe o revisa una persona (regla de [00](00-vision.md): nada sin revisar). La IA puede hacer el primer
  borrador de la traducción; el validador del paquete se aplica igual en cada idioma.
- Orden sugerido: español → inglés → portugués (Brasil).

## 6. Alternativas y respaldo

| Opción | Calidad | Costo | Cuándo usarla |
|---|---|---|---|
| **A. ElevenLabs pregrabado** (§2–4) | La mejor | ≈ USD 240 por idioma y voz, una vez | Plan principal |
| **B. Modelo abierto pregrabado en servidor** (Chatterbox multilingüe, MIT; Kokoro, Apache 2.0) en una GPU alquilada por horas | Buena, algo menos expresiva | ≈ USD 5–20 de GPU por idioma | Si los términos o el precio de ElevenLabs no sirven, o para idiomas secundarios |
| **C. Voz en el teléfono con modelo neuronal** (Kokoro 82M vía `sherpa-onnx`) | Buena, mucho mejor que la del sistema | USD 0; +80–150 MB de app o descarga aparte | Respaldo sin conexión, nombres aún no grabados, paquete gratis |
| D. Voz del sistema (`flutter_tts`, lo de hoy) | Correcta | USD 0 | Último respaldo |
| Google Chirp 3 HD / Azure HD en tiempo real | Muy buena | ≈ USD 22–30 por millón (≈ USD 0.15 por cuento) | No: sigue cobrando por cuento |

## 7. «Cuentos prediseñados» (destacados de la semana)

Además del caldero, publicar cada semana 2–3 **cuentos destacados**: una semilla y unas elecciones elegidas por el equipo y
revisadas a mano. Como su texto es fijo:

- se renderizan **completos** (≈ USD 0.50 cada uno), con **voces distintas por personaje** y las etiquetas de emoción de ElevenLabs v3;
- dan la insignia *Nuevo* y el «tren de contenido» que sostiene la suscripción (como las novedades semanales de Readmio);
- el nombre del niño entra igual que en §3, o el cuento se ofrece con su héroe original.

250 destacados ≈ USD 125 en voz.

## 8. Cambios técnicos

| ID | Historia | Talla |
|---|---|---|
| V-01 | **Herramienta de render** `tools/voice/render_pack.py`: enumera con el motor todos los textos posibles por fragmento, género y combinación de huecos; parte por el nombre; llama a ElevenLabs con `previous_text/next_text`; guarda Opus con nombre = hash(texto, voz, idioma, versión); manifiesto JSON. Solo re-renderiza lo que cambió. | L |
| V-02 | **Manifiesto de audio** por paquete y versión (hash → archivo, duración), publicado con el paquete en el CDN. | S |
| V-03 | `RecordedNarrator` (nueva clase de `Narrator`): para cada frase busca sus trozos y el nombre en el manifiesto, descarga y cachea, los une y avisa a `playback.dart` igual que hoy. Si falta algo → voz del teléfono (C o D) solo para esa frase. | M |
| V-04 | **Nombres**: lista de nombres comunes pregrabados; endpoint `POST /v1/names` que encola un nombre raro y devuelve su URL cuando existe. El nombre viaja sin el resto de los datos del niño ([22](22-privacidad-y-tiendas.md)). | M |
| V-05 | **Prueba de escucha** con 10 cuentos y 20 nombres: ¿se nota el corte? Decide entre §3 tal cual o enviar el nombre como trozo más largo. | S |
| V-06 | Voz neuronal en el teléfono (Kokoro + `sherpa-onnx`) como respaldo. | M · *Después* |
| V-07 | Cuentos destacados semanales con varias voces (§7). | M |

Orden: V-05 con un prototipo manual (unos cuantos trozos a mano) → V-01 → V-02 → V-03 → V-04 → V-07.

## Fuentes

- Precios de ElevenLabs: [Cartesia](https://www.cartesia.ai/learn/elevenlabs-pricing), [Puter](https://developer.puter.com/tutorials/elevenlabs-api-pricing/), [goodvibecode](https://www.goodvibecode.com/text-to-speech/elevenlabs-api-pricing-explained)
- Google, Azure y OpenAI: [texttolab · Google](https://texttolab.com/blog/google-cloud-tts-pricing), [speechify · precios por volumen](https://speechify.ai/blog/tts-api-pricing-at-volume-2026), [texttolab · OpenAI](https://texttolab.com/blog/openai-tts-pricing)
- Modelos abiertos: [pinggy](https://pinggy.io/blog/best_open_source_self_hosted_text_to_speech_models/), [GetStream · en el dispositivo](https://getstream.io/blog/best-on-device-tts-models/), [openvoxai](https://openvoxai.com/blog/best-free-local-tts-models-2026)
