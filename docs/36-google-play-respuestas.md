# 36 · Google Play: respuestas propuestas para «Contenido de la app»

> 18-nov-2026. Respuestas **propuestas** para los cuestionarios de Play Console de la app «Mininoches» (`com.mininoches.app`).
> Son declaraciones legales en nombre de TuVendor: **las revisa y envía el dueño del producto**. Están basadas en lo que
> la app hace hoy ([22](22-privacidad-y-tiendas.md), [30](30-servidor-y-panel.md)). Si algo no es cierto, se corrige aquí antes de enviarlo.

## Ya hecho en Play Console (borrador, sin enviar)

- **Política de privacidad:** `https://audio.tuvendor.com/legal/privacidad.html`
- **Categoría:** Aplicación · Libros y referencias.
- **Contacto:** `ventas@tuvendor.com` · web `https://audio.tuvendor.com/legal/soporte.html`.
- **Ficha principal (es-419):**
  - nombre, descripción corta y descripción completa, sacados de [tools/store/ficha.es.md](../tools/store/ficha.es.md);
  - icono de 512 px, gráfico destacado de 1024×500 y 6 capturas de teléfono.

## 1. Acceso a la app

- **¿Hay partes restringidas?** Sí: los cuentos de pago, que van con la suscripción.
- **Instrucciones para el revisor:**
  > La app no tiene cuentas ni inicio de sesión. Tres cuentos son gratis («Las sombras del cuarto», «Galletas para todos» y «¿Dónde está Chispa?»). El resto se abre con la suscripción «mininoches_premium», que tiene 7 días de prueba; usen una cuenta de pruebas de licencias de Google Play para no pagar. Los ajustes y la compra están detrás de una pregunta para adultos: una multiplicación sencilla cuya respuesta aparece en pantalla.

## 2. Anuncios

- **¿La app contiene anuncios?** **No.**

## 3. Clasificación de contenido (cuestionario IARC)

- **Categoría:** «Referencia, noticias o educación» (o «Todas las demás apps»).
- **Violencia:** no. Solo hay sustos suaves, como sombras o ruidos en la noche, que se resuelven sin daño.
- **Miedo:** contenido de miedo leve (sombras, oscuridad, tormenta) en un contexto infantil y tranquilizador. Si el formulario lo pregunta, sí: «leve».
- **Sexualidad, lenguaje soez, drogas, alcohol, tabaco y apuestas:** no.
- **Interacción entre usuarios, chat o contenido generado por usuarios:** no.
- **Compartir la ubicación:** no.
- **Compras digitales:** **sí** (suscripción).
- **Resultado esperado:** 3+ / PEGI 3 / Para todos.

## 4. Público objetivo y contenido

- **Edades objetivo:** **5 años o menos**, **6–8** y **9–12**.
  - La app es para niños de 2 a 12 años, acompañados por un adulto.
  - Al elegir edades de niños se aplica la **Política para Familias**.
- **¿Puede atraer sin querer a niños?** No aplica: va dirigida a niños.
- **Cumplimiento de la Política para Familias:**
  - **Anuncios:** no tiene.
  - **SDK de terceros:** ninguno que recoja datos.
  - **Identificadores:** no recoge identificadores de publicidad ni de dispositivo.
  - **Pregunta para adultos:** los enlaces externos, las compras y los ajustes están detrás de ella.
  - **Contenido:** apropiado para niños.
- **Programa «Aprobadas por profesores»:** opcional; se puede dejar para después.

## 5. Seguridad de los datos

**Respuestas propuestas, con la app y el servidor de hoy.**

**Recopilación:**
- **¿Recopila o comparte datos de usuario?** Sí, recopila. **No los comparte** con terceros.
- **¿Se cifran en tránsito?** Sí: todo va por HTTPS.
- **¿Se pueden borrar?** Sí:
  - Lo que está en el teléfono se borra en Ajustes → «Borrar los datos de este teléfono».
  - Para lo del servidor se escribe a ventas@tuvendor.com.

**Tipos de datos:**

| Tipo | ¿Se recopila? | Para qué | ¿Opcional? |
|---|---|---|---|
| **Historial de compras** (verificación de la suscripción con Google; token de compra cifrado) | Sí | Funcionalidad de la app | No (solo si compra) |
| **ID de la app** (identificador de instalación aleatorio, no ligado a la persona) | Sí | Funcionalidad de la app (asociar la suscripción a la instalación) | No |
| **Interacciones con la app** (valoración de 1 a 5 de un cuento, sin identidad ni hora) | Sí | Análisis, para mejorar los cuentos | **Sí**: se puede apagar en Ajustes |
| Nombre, correo, ubicación, contactos, fotos, audio del micrófono | **No** | — | — |

- **Perfiles de los niños** (nombre opcional y edad): se guardan **solo en el teléfono**. No se recopilan.

## 6. Otras declaraciones

- **App de gobierno:** no.
- **Funciones financieras:** no.
- **Salud:** no.
- **Servicio en primer plano de tipo `mediaPlayback`** (Android 14), si lo pregunta: sí. Sirve para que el cuento siga sonando con la pantalla bloqueada, y empieza cuando el usuario pulsa reproducir.
- **Permisos sensibles:** ninguno: no pide ubicación, cámara, micrófono ni contactos.

## 7. Estado (18-nov-2026) y lo que falta

**Hecho en Play Console:**
- «Contenido de la app»: todas las declaraciones completadas.
  - **Anuncios:** no.
  - **ID de publicidad:** no; el manifiesto no tiene AD_ID.
  - **App gubernamental, funciones financieras y salud:** no.
  - **IARC:** la categoría es «El resto de los tipos de app». Hay contenido en línea (los cuentos que se descargan) y compras digitales; no hay contenido sensible. Resultado: PEGI 3, ESRB E, USK 0 y Brasil +14 (por las compras).
  - **Público objetivo:** menos de 5, 6–8 y 9–12, con la Política para Familias. Sin «Aprobadas por profesores».
  - **Seguridad de los datos:** como en el punto 5. La URL de borrado es `https://audio.tuvendor.com/legal/borrar-datos.html`.
  - **Detalles de acceso:** instrucciones en inglés y el **código de revisión** (secreto `REVIEW_CODE`; el gancho de despliegue lo crea en el servidor). Lo canjea «Canjear código → Código de Mininoches», desde la versión 1.0.0+23.
- **Ficha de Play Store:** guardada; recursos sin etiqueta de IA (dibujos hechos con nuestro código y capturas de la app).
- **Prueba interna:** versión «22 (1.0.0)» lista para publicar, con los verificadores «Equipo TuVendor» y «Tester».

**Falta (lo hace el dueño):**
1. **Prueba interna → «Guardar y publicar».** La versión 22 sirve para probar; para producción hay que subir `builds/mininoches-1.0.0-23.aab`, que es la que acepta el código del revisor.
2. **Cuenta de comerciante de Google Payments** (Configuración → Perfil de pagos): datos bancarios y fiscales. Sin ella no se pueden crear suscripciones.
3. Después, en **Monetizar → Suscripciones:**
   - crear `mininoches_premium` con los planes de base `anual` (P1Y) y `mensual` (P1M) y 7 días de prueba;
   - precios de referencia: USD 39.99 y 5.99 en EE. UU., y Latinoamérica más bajo ([05](05-modelo-freemium.md)).
4. Cuenta de servicio de Google Cloud con acceso a Play Console. Su JSON va en `credenciales/` y en el `.env` del servidor (`GOOGLE_SERVICE_ACCOUNT_JSON`).
5. «Declarar estado de comerciante», antes del 1 de febrero de 2027.
6. Enviar a revisión desde «Descripción general de la publicación».

## 8. Códigos de canje propios: qué dicen las tiendas (revisado el 18-nov-2026)

- **Google Play:** la [política de pagos](https://support.google.com/googleplay/android-developer/answer/9858738) exige la facturación de Google Play cuando la app cobra o acepta un pago por funciones o contenido, y prohíbe llevar al usuario a otra forma de pago. No habla de regalar acceso. Los códigos de Mininoches en Android son **gratuitos**: sirven para regalos, promociones y para el revisor. Así se cumple.
  - **No se pueden vender** fuera de Google Play: ni a escuelas, ni por la web, ni en efectivo. Si algún día se quiere cobrar, se usan los códigos promocionales de Play Console o las tarjetas de regalo de Google Play.
- **Apple:** la [guía 3.1.1](https://developer.apple.com/app-store/review/guidelines/) no permite «mecanismos propios para desbloquear contenido». En iPhone la app no acepta códigos propios, solo los de la tienda (offer codes). Así está programado.
- **Revisores:** Google pide un modo de acceso completo sin pagar. El código de revisión (`REVIEW_CODE`) es gratuito y es lo que se usa. Está descrito en «Detalles de acceso».
- Lo mismo explica el panel en «Códigos de regalo».
