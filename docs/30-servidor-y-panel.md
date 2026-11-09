# 30 · Servidor y panel (Laravel)

> Implementa la parte de compras y catálogo de [09](09-backend-y-panel-admin.md) con el modelo de suscripción de
> [05](05-modelo-freemium.md). Código en [`server/`](../server/README.md) (instalación, Google Play y despliegue ahí).

## Arquitectura

```
App ──GET /v1/catalog (ETag)──────────────▶ ┌──────────────────────────────┐
    ──POST /v1/purchases/verify──────────▶ │ Laravel 13 (server/)          │──▶ Google Play Developer API
    ──POST /v1/redeem · GET /v1/entitlements│  API JSON sin cookies         │    (subscriptionsv2, JWT RS256 propio)
    ──POST /v1/feedback───────────────────▶ │  Panel /admin (Blade, sesión) │──▶ App Store Server API
Google Pub/Sub ──POST /v1/webhooks/google─▶ │  SQLite · MySQL · Postgres    │    (transactions, subscriptions; JWT ES256
Apple ──POST /v1/webhooks/apple (JWS v2)──▶ └──────────────────────────────┘     propio; JWS verificados hasta Apple Root CA - G3)
                                                    ▲ php artisan mininoches:import-packs ← content/packs/*/pack.json
```

- **Un solo servidor monolítico** (decisión práctica frente a la propuesta de Supabase de docs/09 §8): un lenguaje
  conocido, cualquier hosting PHP, y la lógica de dominio aislada en `app/Services` por si se migra.
- **Contenido:** los packs siguen viviendo en `content/packs`; el servidor los **importa** (texto, enseñanzas, edades,
  versiones) para que el SuperAdmin los revise y para validar las valoraciones contra la versión exacta del pack.
  La revisión y «Gratis» nunca se pisan al reimportar. Aún **no** sirve los packs ni un manifiesto firmado (docs/09 §4).
- **Catálogo:** `freeStories` (por defecto `medieval:sombras`, `mar:galletas_todos`, `cosmos:chispa_perdida`),
  `hiddenStories` (los **rechazados**; los pendientes se siguen mostrando), `products` y `version`, que sube con cada
  cambio del panel. `ETag` + `If-None-Match` → 304.
- **Derechos:** uno por `installId`, con lo de la tienda y lo de los códigos por separado; vale el que dure más. Un
  código suma sus días sobre lo que ya haya. Firma Ed25519 (`installId|premium|source|productId|expiresAt|issuedAt`).
- **Un único SuperAdmin** (`php artisan mininoches:admin`), sin registro, con auditoría. Los roles de docs/09 §7 quedan para después.
- **Privacidad:** sin IP guardada (límites de ritmo con HMAC de la IP en caché de un minuto), valoraciones sin
  instalación ni hora, tokens de compra (y la transacción original de Apple) cifrados y buscados por hash, sesiones del
  panel en archivos.
- **iOS:** la app manda el `transactionId` de StoreKit; el servidor lo consulta en la App Store Server API (producción y,
  si da 404, sandbox), verifica cada JWS (cadena `x5c` hasta Apple Root CA - G3 fijada por huella, OID de Apple en el
  intermedio y la hoja, vigencia y firma ES256), guarda la compra por su `originalTransactionId` y firma el derecho igual
  que en Android. Las notificaciones v2 se verifican igual, se procesan una vez por `notificationUUID` y actualizan la
  compra con la transacción firmada que traen. Detalle en [`server/README.md` §6](../server/README.md#6-app-store-ios).

## Qué está verificado

67 pruebas de PHPUnit (`php artisan test`, SQLite en memoria):

| Área | Comprobado |
|---|---|
| Catálogo | 3 gratis por defecto, productos sembrados, ETag/304, reimportar no pisa la revisión, sin cookies |
| Compras Android | activa, prueba gratis (y acknowledge), cancelada pero pagada, caducada, en espera, token desconocido, otro producto, Google caído, sin configurar → 503; JWT RS256 verificado con la clave pública; token cifrado y hash |
| Compras iOS | activa, prueba gratis (`FREE_TRIAL`), periodo de gracia hasta `gracePeriodExpiresDate`, renovación desactivada, caducada y reintento de cobro → 402 expired, reembolsada/revocada → 402 invalid, otro bundle, otro producto, productos `ios` del panel, transacción desconocida, respaldo a sandbox (y estado pedido en ese entorno), modo sandbox y sin respaldo, Apple caído o clave rechazada → 503, sin configurar → 503 sin llamar; derecho caducado se reconsulta; JWT ES256 verificado con la pública; ids cifrados y sin rastro en claro |
| Firmas JWS de Apple | con una cadena de certificados de prueba generada en las pruebas (raíz → intermedio → hoja con los OID de Apple) inyectada como raíz de confianza: contenido alterado, otra raíz, cadena falsa con la raíz buena al final, hoja ajena con el intermedio bueno, hoja o intermedio sin OID, sin firma, certificados caducados (también solo la hoja), raíz sin huella fijada; la raíz del repositorio es Apple Root CA - G3 (huella publicada) y no acepta la cadena de prueba; conversión DER ↔ R‖S |
| Canje | correcto, desconocido 404, usado/caducado/desactivado 409, mismo teléfono no repite, suma días, límite 5/min |
| Derechos | sin nada → `none` firmado, firma verificable con la clave pública, alterar un campo la invalida, sin clave → 503 |
| Webhooks | Google con token malo o sin configurar → 403; con token reconsulta y actualiza. Apple: `DID_RENEW` alarga, `REFUND` quita premium, `notificationUUID` repetido → 200 sin reprocesar, gracia y luego `GRACE_PERIOD_EXPIRED`, `DID_CHANGE_RENEWAL_STATUS`, compra desconocida, otro bundle, `TEST`, notificación atrasada (`stale`); firma mala, otra cadena, sin firmar o transacción de dentro mal firmada → 400 sin guardar |
| Valoraciones | acepta, idempotente, rechaza fragmento/opción/enseñanza/pack/día/motivos/reparto/campos de más, 50 eventos y 64 KB → 413, cuerpo mal formado → 400, sin columnas de IP/instalación/hora |
| Panel | compras de iOS en la lista (filtro por tienda, búsqueda por la transacción original) y en la ficha; crear/restablecer admin y negarse a un segundo, contraseña interactiva, login/logout, límite de intentos, sin registro, aprobar/rechazar/gratis cambian el catálogo, códigos, productos, todas las páginas cargan con token CSRF |

Además se probó a mano: `php artisan serve` + `curl /v1/catalog` con los packs reales (90 cuentos, 3 gratis), y el
panel en el navegador (inicio y ficha de un cuento con sus variantes y valoraciones).

## Qué falta

| Pieza | Estado |
|---|---|
| Llamadas reales a Google Play | ☐ solo probadas con respuestas simuladas (`Http::fake`); falta una compra de probador de licencias real |
| Llamadas reales a Apple | ☐ App Store Server API y Server Notifications v2 están hechas, pero **solo probadas con respuestas simuladas** (`Http::fake`) y una cadena de certificados de prueba: nunca se ha llamado a Apple ni verificado un JWS real. Falta: crear la clave `.p8`, una compra de sandbox/TestFlight de punta a punta y la notificación de prueba (`POST /inApps/v1/notifications/test`) |
| iOS: OCSP y `appAccountToken` | ☐ no se consulta la revocación en línea de los certificados de Apple; la compra no se ata a la instalación con `appAccountToken` (como en Android, quien tenga el id de la transacción puede presentarla) |
| La app en iOS | ☐ `plans()` solo entiende los productos de Google Play y pide el id `mininoches_premium`; en la App Store hay un id por duración (`APPLE_PRODUCT_IDS`) |
| La app usando `/v1/catalog`, `/v1/purchases/verify`, `/v1/redeem`, `/v1/entitlements` y verificando la firma | ☐ la app hoy solo usa `/v1/feedback` |
| Servir packs y manifiesto firmado (docs/09 §4), cuentos nuevos semanales | ☐ |
| Panel: 2FA, roles, informe de calidad por regresión (docs/12 §6) | ☐ |
| Reembolsos y cambios de plan (`linkedPurchaseToken`) | ◐ se reconsulta el estado; no se marca la compra vieja como reemplazada |
| Despliegue en un servidor real con HTTPS | ☐ |
