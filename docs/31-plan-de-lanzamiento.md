# 31 · Plan maestro

> El mapa de todo lo que falta. Se actualiza cada vez que se cierra un paso. Última actualización: 17-nov-2026.
>
> ✅ hecho · 🔄 en curso · ☐ pendiente

## Etapa A · Lanzar con 50 cuentos en español, con voz de ElevenLabs

| # | Paso | Estado |
|---|---|---|
| A1 | Elegir la voz: **Isabela** de ElevenLabs ([prueba de escucha](https://claude.ai/artifact/Tzem2r691gE4dqwnHkevVV)) | ✅ |
| A2 | Elegir los 50 cuentos: de 2 a 8 años, las 6 enseñanzas, los 3 mundos y los 3 gratis | ✅ |
| A3 | Fijar un texto por cuento: sin el nombre del niño, sin preguntas, protagonistas niño y niña alternados | ✅ |
| A4 | Auditar los 50 textos ([32](32-auditoria-50-cuentos.md)), aprobar y aplicar las correcciones en los tres mundos completos, y añadir al validador la regla contra palabras de España. «La niña de la mochila verde» se cambió por «La bolsa del pozo» (ver B11). Lista fija en [content/catalogo/lanzamiento-es.json](../content/catalogo/lanzamiento-es.json) | ✅ |
| A5 | Grabar los 50 cuentos con Isabela, 106 453 caracteres, y revisar cada audio con el transcriptor (`tools/voice/render_catalog.py`). **Hecho (17-nov):** los 50 cuentos en dos tandas, 384 escenas y **2 h 29 min** de audio, con 106 679 caracteres gastados. El transcriptor no marcó ninguna escena. El audio está en `builds/voz/` (138 MB, fuera de git): hay que guardarlo también en R2 o en otra copia de respaldo | ✅ |
| A5b | **Llegar a 100 cuentos.** 39 auditados y corregidos ([33](33-auditoria-39-cuentos.md)) y 11 nuevos. **97 de 100 grabados y publicados** en audio.tuvendor.com. Faltan 3 (cosmos: funcion_planetario, noche_festival, tormenta_lunar) por créditos de ElevenLabs: recargar y volver a lanzar `render_catalog.py` | 🔄 97/100 |
| A6 | La app reproduce el audio grabado (`narration/recorded_voice.dart`): título, escenas y enseñanza con la voz de Isabela; los 3 gratis dentro de la app, los demás se descargan y quedan guardados; si falta un audio, suena la voz del teléfono. `tools/voice/export_app.py` prepara el audio para la app y para el servidor | ✅ (falta probarlo en un teléfono) |
| A7 | Con `catalogOnly` (brand.dart), la app muestra solo los cuentos del catálogo, siempre con su texto fijo, y «Crear cuento» elige uno de ellos | ✅ · **Falta:** recibir cuentos nuevos del servidor sin actualizar la app (pasa a B1) |
| A8 | Servidor publicado en `https://cuentos2.tuvendor.com` (cPanel, PHP 8.4 por `.htaccess`, base de datos, despliegue automático con GitHub Actions y FTP). Audio, cuentos nuevos y páginas legales en `https://audio.tuvendor.com` (R2) | ✅ · **tú:** crear el usuario del panel (`mininoches:admin`) |
| A9 | Productos de suscripción en las dos tiendas y compras de prueba. **Hecho:** identificador `com.mininoches.app` y app «Mininoches» creada en Play Console (cuenta TuVendor, gratis, es-419); credenciales en `credenciales/.env` | 🔄 |
| A10 | Prueba cerrada de Google Play (14 días con 12 personas, si tu cuenta lo exige) | ☐ (tú, **empezar ya**) |
| A11 | Ficha de Google Play en borrador (textos, icono, gráfico, 6 capturas, privacidad, categoría, contacto). Respuestas de los cuestionarios propuestas en [36](36-google-play-respuestas.md). Versión firmada `builds/mininoches-1.0.0.aab` | 🔄 · **tú:** subir el .aab, revisar los cuestionarios, crear la suscripción |
| A12 | Enviar a revisión a Google y Apple | ☐ |

## Etapa B · Después del lanzamiento: ser mejores que Readmio

Del estudio de Readmio ([replica/recon.md](../replica/recon.md)). Mininoches cubre hoy **79,5 de 100** de lo que hace Readmio.

| # | Mejora | Estado |
|---|---|---|
| B1 | Un cuento nuevo grabado cada semana, desde el servidor | ☐ |
| B2 | Opciones de letra: todo en mayúsculas y letra para dislexia | ☐ |
| B3 | Preguntas para conversar después del cuento | ☐ |
| B4 | Leer la primera escena de un cuento bloqueado | ☐ |
| B5 | Cuento al azar | ☐ |
| B6 | Música para dormir después del cuento | ☐ |
| B7 | Volver a decir el nombre del niño en el cuento grabado | ☐ |
| B8 | Grabar la voz de mamá o papá | ☐ |
| B9 | Otros idiomas: inglés y luego portugués | ☐ |
| B10 | Widgets en la pantalla de inicio del teléfono | ☐ |
| B11 | «La niña de la mochila verde»: el niño que se burla usa el dibujo del molinero adulto. Hay que dibujar un niño nuevo o reescribir esa parte | ☐ |

**Lo que no se copia de Readmio:** la lectura con micrófono que dispara sonidos, y su catálogo, arte y mascota.

## Ya hecho antes de este plan

- **Para niños y familias:** explorar, ficha del cuento, filtros, recomendación de la noche, avisos, progreso y premios, recordatorio y varios niños por familia.
- **Pago y tiendas:** suscripción con 7 días de prueba, 3 cuentos gratis, muro de pago, canje de códigos de la tienda, términos y privacidad, y pregunta para adultos.
- **Servidor y marca:** servidor Laravel con panel de administración, verificación de compras de Google y Apple, logo, nombre Mininoches y capturas de tienda.
