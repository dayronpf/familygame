# 22 · Privacidad, textos legales y requisitos de las tiendas

> **Estado (v0.7.0):** la app ya tiene política de privacidad, términos de uso, «Ver mis datos» y «Borrar los datos de este teléfono».
> Los textos son un **borrador técnico**: dicen con exactitud lo que hace la app, pero **no son asesoramiento legal** y
> **deben revisarlos una persona con formación legal** antes de publicar (sobre todo por tratarse de una app para niños).

## 1. Qué hace la app con los datos (inventario)

| Dato | Dónde vive | Sale del teléfono | Cómo se borra |
|---|---|---|---|
| Perfiles de los niños: nombre (opcional, lo escribe un adulto), edad (perfil de 4 tramos), género del protagonista, idioma, voz, velocidad, «preguntas en el cuento» | `shared_preferences` (almacén privado de la app) | **No** | Ajustes → «Borrar los datos de este teléfono»; desinstalar |
| «Mis cuentos»: semilla, enseñanza, protagonista, caminos elegidos (códigos, no texto) | `shared_preferences` | **No** | Ídem; al quitar un niño se borran los suyos |
| Ajustes (música, efectos, volumen, «enviar valoraciones») | `shared_preferences` | **No** | Ídem |
| Valoraciones pendientes de enviar y cuentos por valorar | `shared_preferences` | Solo si «Ayudar a mejorar los cuentos» está activo **y** existe el servidor (hoy **no existe**: nada se envía) | Desactivar el ajuste (borra la cola) o «Borrar los datos» |
| Voz del cuento | El motor de voz **del sistema** (Android/iOS) | El texto del cuento lo lee el motor del teléfono; algunos motores usan la nube (política del fabricante) | — |

**Lo que la app NO hace:** cuentas, correo, teléfono, ubicación, fotos, micrófono, contactos, anuncios, compras, redes sociales, analítica de uso,
identificadores de publicidad ni de instalación, ni SDK de terceros que recojan datos. (Comprobar al añadir cualquier dependencia nueva.)

**Lo que se enviaría (cuando exista el servidor y un adulto lo permita):** `RatingEvent` (nota 1–5, motivos de una lista cerrada,
`recipe` con códigos, día sin hora, versión de la app). Contrato exacto: [api/feedback.openapi.yaml](api/feedback.openapi.yaml) y [12](12-valoraciones-y-mejora-continua.md).
El evento lleva un `id` aleatorio **por valoración** (no por persona ni por dispositivo) para no duplicar si se reintenta.

**Permisos de Android** (`AndroidManifest.xml`): `INTERNET` (valoraciones), `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` y
`POST_NOTIFICATIONS` (el cuento sigue con la pantalla bloqueada, [07](07-backlog.md)), `WAKE_LOCK` (no dormirse a media frase). iOS: modo de fondo `audio`.

## 2. Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Política de privacidad (texto) | `content/legal/politica-de-privacidad.es.md` → `app/assets/legal/` (`tools/sync_assets.sh`; CI comprueba que no se desincronice) |
| Términos de uso | `content/legal/terminos-de-uso.es.md` |
| Pantallas | `app/lib/src/legal/legal_page.dart` (lee y rellena `{{APP}}`, `{{TITULAR}}`, `{{CORREO}}`, `{{FECHA}}`), `my_data_page.dart`; entradas en `settings_page.dart` («Privacidad y datos») |
| Titular, correo y fecha | `app/lib/src/brand.dart` (`legalOwner`, `contactEmail`, `legalDate`, `feedbackServerLive`). Mientras `legalOwner`/`contactEmail` empiecen por `[`, las pantallas legales enseñan el aviso «Versión de prueba» |
| Borrado | `AppSettings.resetAll`, `StoryShelf.clearAll`, `FeedbackService.clearAll`; tras borrar vuelve el asistente de bienvenida |
| Protección de adultos | `askAdult` (pregunta de multiplicar) delante de Ajustes |
| Pruebas | `app/test/privacy_test.dart` (marcadores, contenido de la política, pantallas, ver y borrar datos) |

## 3. Lista de comprobación antes de publicar

### Para quien publica (decisiones y trámites)
- [ ] **Titular y contacto:** quién publica la app (persona o empresa, país) y un correo de contacto real → `brand.dart`. Sin esto las tiendas rechazan la ficha.
- [ ] **URL pública de la política** (las dos tiendas la piden): publicar el texto en una página web estable (p. ej. GitHub Pages del repositorio o el sitio del proyecto) y poner el enlace en las fichas.
- [ ] **Revisión legal** de la política y los términos (RGPD/LOPDGDD en España y UE, COPPA en EE. UU., ley de protección de datos del país del titular). Hay que decidir si, al no recoger datos personales, aplica alguna obligación adicional.
- [ ] **Cuentas de desarrollador** (Google Play, Apple Developer) y datos fiscales del titular.
- [ ] **Decisión D-legal-1: valoraciones activadas por defecto.** Hoy «Ayudar a mejorar los cuentos» viene **activado** (los datos son anónimos y de lista cerrada, [12](12-valoraciones-y-mejora-continua.md)). Para una app dirigida a niños es más prudente que sea **opt-in** (apagado hasta que un adulto lo active, p. ej. en el asistente). Cambiarlo es una línea (`feedback_store.dart`, `readEnabled` por defecto `false`) y un paso en el asistente; recomendado antes del servidor.
- [ ] **Decisión D-legal-2: edad mínima** declarada (la app es para que la usen adultos con niños; los ajustes están tras la pregunta de adultos).

### Google Play (categoría «Para toda la familia» / Families Policy)
- [ ] Público objetivo: niños (p. ej. 2–12) → se aplica la **Families Policy**: sin anuncios de terceros, sin SDK no certificados para niños, sin identificadores de publicidad, **sin permisos innecesarios**. Revisar `POST_NOTIFICATIONS`/servicio en primer plano (necesarios para el audio con pantalla bloqueada; documentarlo).
- [ ] **Formulario «Seguridad de los datos»** (con la app tal como está, sin servidor): *no recopila ni comparte datos*; los datos de los perfiles se guardan solo en el dispositivo. Con servidor: «Interacciones con la app» (valoración), **no vinculado a una identidad**, no compartido, cifrado en tránsito, el usuario no puede pedir su borrado (anónimo).
- [ ] Cuestionario de **clasificación IARC** (contenido: cuentos con un susto suave, sin violencia gráfica) → previsible 3+/PEGI 3.
- [ ] Declarar el uso del **servicio en primer plano de tipo `mediaPlayback`** (Android 14).
- [ ] Ficha: capturas, texto, política (URL), correo, categoría «Libros y referencias»/«Educación».

### App Store (categoría Niños, guía 1.3 y 5.1.4)
- [ ] Si se elige la categoría **Kids**: sin analítica ni publicidad de terceros, **puerta para padres** delante de enlaces externos, compras y ajustes (ya hay `askAdult` delante de Ajustes, donde están «Recomendar a un amigo», la guía en PDF y la política).
- [ ] **Etiqueta de privacidad** («nutrition label»): hoy «Datos no recopilados»; con servidor, «Uso del producto» no vinculado a la identidad ni usado para seguimiento.
- [ ] `UIBackgroundModes: audio` justificado (cuento con la pantalla bloqueada). Probar en un iPhone real.
- [ ] URL de soporte y de privacidad; clasificación por edad (4+).

### En la app (hecho o pendiente)
- [x] Política y términos dentro de la app; «Ver mis datos»; «Borrar los datos de este teléfono»; «Licencias y créditos».
- [x] Sin cuentas, anuncios, compras ni analítica.
- [ ] Texto de la política de privacidad en **otros idiomas** cuando haya otra versión del producto.
- [ ] Enlace a la política desde las fichas y desde el asistente de bienvenida (hoy está en Ajustes, tras la pregunta de adultos).
- [x] «Recomendar a un amigo» (abre la hoja de compartir del sistema) está dentro de Ajustes, es decir, tras la puerta de adultos.

## 4. Si algún día hay servidor, cuentas o compras
La política deberá actualizarse **antes** (qué datos, base legal, proveedor y país del servidor, conservación, derechos con un canal real de ejercicio), y las tiendas
exigirán revisar de nuevo la ficha de datos. Las **compras** requieren control parental ([02](02-roadmap.md)) y ya no valdría «sin compras» en los textos.
