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

## 7. Lo que falta para publicar

1. Subir `builds/mininoches-1.0.0.aab` a **Probar y lanzar → Pruebas → Prueba interna** y crear la versión. Pesa 65 MB; es arrastrarlo al navegador.
2. Llenar los cuestionarios 1–6 con estas respuestas, revisándolas.
3. **Monetizar → Productos → Suscripciones:** crear `mininoches_premium` con dos planes de base, anual y mensual, cada uno con 7 días de prueba gratis. Los precios por región los decide el dueño del producto ([05](05-modelo-freemium.md)).
4. Cuenta de servicio de Google Cloud con acceso a Play Console. Su JSON va en `credenciales/` y en el `.env` del servidor (`GOOGLE_SERVICE_ACCOUNT_JSON`), para verificar las compras.
5. «Declarar estado de comerciante», con plazo hasta el 1 de febrero de 2027.
6. Enviar a revisión desde «Descripción general de la publicación».
