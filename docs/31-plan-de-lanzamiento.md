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
| A5 | Grabar los 50 cuentos con Isabela, 106 453 caracteres (≈ USD 6 de créditos extra), y revisar cada audio con el transcriptor | ☐ ← **siguiente** |
| A6 | La app reproduce el audio grabado: los 3 gratis dentro de la app, los demás se descargan, y la voz del teléfono queda de respaldo | ☐ |
| A7 | El catálogo de la app muestra solo esos 50 cuentos y puede recibir cuentos nuevos del servidor sin actualizar la app | ☐ |
| A8 | Servidor en HTTPS y audio en Cloudflare R2 (gratis) | ☐ (tú, con mi guía) |
| A9 | Productos de suscripción en las dos tiendas y compras de prueba | ☐ (tú) |
| A10 | Prueba cerrada de Google Play (14 días con 12 personas, si tu cuenta lo exige) | ☐ (tú, **empezar ya**) |
| A11 | Ficha de tienda revisada con `/replica-launch` y lista final con `/replica-deploy` | ☐ |
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
