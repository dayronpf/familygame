# 05 · Modelo freemium

> **Cambio del 8 de noviembre de 2026:** pasamos de «compra única por paquete» a **suscripción con prueba gratis**,
> el modelo de Readmio (ver [28](28-referencia-readmio-y-plan.md)). Lo hace viable que la voz se grabe una sola vez
> en lugar de generarse en cada cuento ([29](29-voz-pregrabada-y-costos.md)).

## Principio

El paquete gratuito debe ser **completo y entrañable**: que una familia pueda tener un ritual semanal sin pagar.
La suscripción añade **variedad, voz de calidad y cuentos nuevos cada semana**, nunca quita seguridad ni presiona al niño.

## Estructura

| Nivel | Qué incluye | Precio (a validar por región) |
|---|---|---|
| **Gratis** | **3 cuentos completos**, uno por paquete y de edades distintas: *Las sombras del cuarto* (Reino de la Luna, 4–5, valentía, con pregunta), *Galletas para todos* (Mar de las Estrellas, 2–3, generosidad) y *¿Dónde está Chispa?* (Aldea de las Nubes, 6–8, amistad), con todas las funciones (leer, escuchar, leemos juntos, holograma, premios); vista previa (primera escena) de los demás | $0 |
| **Suscripción anual** (la principal) | Todos los paquetes actuales y futuros, voz premium pregrabada en todos los idiomas, cuentos destacados nuevos cada semana, grabar la voz de mamá o papá, progreso y premios | EE. UU. ≈ USD 39.99; Latinoamérica ≈ USD 9.99–14.99 |
| **Suscripción mensual** («Ver otros planes») | Lo mismo, pagando mes a mes | EE. UU. ≈ USD 5.99; Latinoamérica ≈ USD 1.99–2.99 |
| **De por vida** (opcional, más adelante) | Un solo pago, solo para promociones puntuales | ≈ 4 años de anual |

- **Prueba gratis de 7 días** de la anual, con una línea de tiempo honesta: *hoy* acceso total, *día 5* aviso (notificación local) de que la prueba termina, *día 7* empieza el cobro. «Cancela cuando quieras» visible.
- **Precio por región** con los niveles de precio de cada tienda; el anual se muestra también como equivalente mensual.
- **Compartir en familia** (Family Sharing de Apple y grupo familiar de Google Play) activado en el producto.
- **Canjear código**: códigos de oferta de las tiendas para socios, escuelas y regalos (p. ej. 30 días gratis).
- **Recurrencia que sostiene la suscripción**: cuentos destacados nuevos cada semana con insignia *Nuevo*, progreso de la familia, premios suaves y recordatorio de la hora del cuento (fases 1–3 de [28](28-referencia-readmio-y-plan.md)).

**Objetivo del nivel gratis (decisión del 8-nov-2026):** que la familia **pruebe y use** la app y le vea utilidad antes de pagar.
Por eso los 3 cuentos gratis tienen todas las funciones y se pueden repetir sin límite, y la prueba de 7 días abre todo lo demás.

## Qué es de pago y qué no

- ✅ De pago: los demás paquetes, voz premium, cuentos destacados semanales, grabaciones de voz, nombre del niño narrado con voz premium.
- ❌ Nunca de pago: seguridad, modo noche, temporizador de sueño, plantilla básica del holograma, accesibilidad, el paquete gratis completo con voz del teléfono.
- ❌ Nunca: anuncios, cuentas atrás, ofertas que caducan en minutos, mensajes dirigidos al niño para comprar, rachas que castigan.

## Reglas de tiendas a respetar

- Muro de pago y compras detrás de la **puerta para adultos**; botón **Restaurar compras**; ✕ siempre visible.
- Suscripciones: precio, periodo, renovación automática y cómo cancelar, escritos junto al botón (Apple 3.1.2 y la política de Google Play).
- La prueba gratis solo una vez por cuenta de tienda (la tienda lo controla).
- Comisión: 15 % en el programa para pequeños desarrolladores y desde el segundo año de cada suscriptor; modelar el margen con eso.

## Números que tienen que cuadrar

Con voz pregrabada, el costo de voz por suscriptor es casi cero ([29 §4](29-voz-pregrabada-y-costos.md)). Lo que queda:
la comisión de la tienda, la entrega de audio (CDN sin costo de salida) y el servidor de verificación. Generar la voz en
tiempo real con ElevenLabs costaría ≈ USD 0.25–0.50 por cuento, más que una suscripción latinoamericana de un mes en una
semana de uso: **queda descartado**.

## Métricas

Inicio de prueba → conversión a pago, cancelaciones en la prueba, renovación del primer año, ingresos por suscriptor
por región, reembolsos y, **sobre todo**, noches con cuento completado (North Star).

## Entrega técnica

`in_app_purchase` con productos de suscripción (anual, mensual) en un grupo de suscripción; **verificación en el servidor**
(App Store Server API, Google Play Developer API y notificaciones en tiempo real) que emite un *entitlement* firmado y lo
registra en el panel ([09 §5](09-backend-y-panel-admin.md)). La app guarda el entitlement para funcionar sin conexión y lo
revalida al abrir. Paquetes y audio se descargan bajo demanda, con caché y borrado manual.
