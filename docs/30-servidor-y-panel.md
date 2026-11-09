# 30 · Servidor y panel (Laravel)

> Implementa la parte de compras y catálogo de [09](09-backend-y-panel-admin.md) con el modelo de suscripción de
> [05](05-modelo-freemium.md). Código en [`server/`](../server/README.md) (instalación, Google Play y despliegue ahí).

## Arquitectura

```
App ──GET /v1/catalog (ETag)──────────────▶ ┌──────────────────────────────┐
    ──POST /v1/purchases/verify──────────▶ │ Laravel 13 (server/)          │──▶ Google Play Developer API
    ──POST /v1/redeem · GET /v1/entitlements│  API JSON sin cookies         │    (subscriptionsv2, JWT RS256 propio)
    ──POST /v1/feedback───────────────────▶ │  Panel /admin (Blade, sesión) │
Google Pub/Sub ──POST /v1/webhooks/google─▶ │  SQLite · MySQL · Postgres    │
Apple ──POST /v1/webhooks/apple (guarda)──▶ └──────────────────────────────┘
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
  instalación ni hora, tokens de compra cifrados y buscados por hash, sesiones del panel en archivos.

## Qué está verificado

39 pruebas de PHPUnit (`php artisan test`, SQLite en memoria):

| Área | Comprobado |
|---|---|
| Catálogo | 3 gratis por defecto, productos sembrados, ETag/304, reimportar no pisa la revisión, sin cookies |
| Compras Android | activa, prueba gratis (y acknowledge), cancelada pero pagada, caducada, en espera, token desconocido, otro producto, Google caído, sin configurar → 503; JWT RS256 verificado con la clave pública; token cifrado y hash |
| iOS | se guarda y responde 503 |
| Canje | correcto, desconocido 404, usado/caducado/desactivado 409, mismo teléfono no repite, suma días, límite 5/min |
| Derechos | sin nada → `none` firmado, firma verificable con la clave pública, alterar un campo la invalida, sin clave → 503 |
| Webhooks | Google con token malo o sin configurar → 403; con token reconsulta y actualiza; Apple guarda |
| Valoraciones | acepta, idempotente, rechaza fragmento/opción/enseñanza/pack/día/motivos/reparto/campos de más, 50 eventos y 64 KB → 413, cuerpo mal formado → 400, sin columnas de IP/instalación/hora |
| Panel | crear/restablecer admin y negarse a un segundo, contraseña interactiva, login/logout, límite de intentos, sin registro, aprobar/rechazar/gratis cambian el catálogo, códigos, productos, todas las páginas cargan con token CSRF |

Además se probó a mano: `php artisan serve` + `curl /v1/catalog` con los packs reales (90 cuentos, 3 gratis), y el
panel en el navegador (inicio y ficha de un cuento con sus variantes y valoraciones).

## Qué falta

| Pieza | Estado |
|---|---|
| Llamadas reales a Google Play | ☐ solo probadas con respuestas simuladas (`Http::fake`); falta una compra de probador de licencias real |
| **iOS:** App Store Server API y Server Notifications v2 | ☐ las peticiones y notificaciones se guardan; la verificación (JWT ES256, JWS firmados) llega con la publicación en iOS |
| La app usando `/v1/catalog`, `/v1/purchases/verify`, `/v1/redeem`, `/v1/entitlements` y verificando la firma | ☐ la app hoy solo usa `/v1/feedback` |
| Servir packs y manifiesto firmado (docs/09 §4), cuentos nuevos semanales | ☐ |
| Panel: 2FA, roles, informe de calidad por regresión (docs/12 §6) | ☐ |
| Reembolsos y cambios de plan (`linkedPurchaseToken`) | ◐ se reconsulta el estado; no se marca la compra vieja como reemplazada |
| Despliegue en un servidor real con HTTPS | ☐ |
