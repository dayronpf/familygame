# Mininoches · servidor

API para la app (catálogo, verificación de compras de Google Play y App Store, códigos, derechos firmados y valoraciones) y panel web del
SuperAdmin. Laravel 13, PHP ≥ 8.3 con las extensiones **sodium**, **openssl** y **pdo** (SQLite por defecto; también
MySQL o Postgres).

Contratos que cumple: [`docs/api/store.openapi.yaml`](../docs/api/store.openapi.yaml) y
[`docs/api/feedback.openapi.yaml`](../docs/api/feedback.openapi.yaml). Diseño y estado: [`docs/30-servidor-y-panel.md`](../docs/30-servidor-y-panel.md).

## 1. Instalar (en su computadora)

```bash
cd server
composer install
cp .env.example .env                 # y revise los valores (todos están explicados dentro)
php artisan key:generate
php artisan migrate --seed           # crea database/database.sqlite, el producto y la versión del catálogo
php artisan mininoches:keys          # par de claves Ed25519 (ver §2)
php artisan mininoches:admin tu@correo   # el único SuperAdmin; pide la contraseña (mín. 12 caracteres)
php artisan mininoches:import-packs  # carga los cuentos de ../content/packs/*/pack.json
php artisan test                     # pruebas (SQLite en memoria, no tocan su base de datos)
```

Atajo: `composer run setup` hace la instalación, el `.env`, la clave, las migraciones y la importación.

Para empezar de cero: `php artisan migrate:fresh --seed && php artisan mininoches:import-packs` (borra todo, también el admin).

## 2. Clave de firma de los derechos

Cada respuesta de `/v1/purchases/verify`, `/v1/redeem` y `/v1/entitlements` lleva una firma **Ed25519** sobre:

```
installId|premium(0/1)|source|productId|expiresAt|issuedAt
```

(cadena vacía para los nulos; fechas ISO-8601 en UTC con `Z`, sin fracciones, p. ej. `2026-11-08T21:15:00Z`).

```bash
php artisan mininoches:keys          # imprime ENTITLEMENT_SIGNING_KEY=... (SECRETA → .env) y la clave pública (→ app)
php artisan mininoches:keys --show   # vuelve a mostrar la pública de la clave configurada
```

- La línea `ENTITLEMENT_SIGNING_KEY=…` va **solo** en el `.env` del servidor (nunca en el repositorio).
- La clave pública (32 bytes en base64) se compila dentro de la app para verificar la firma sin conexión.
- Sin clave, compras, códigos y derechos responden `503 store_unavailable` con un mensaje claro.
- Si PHP no tiene la extensión **sodium**, el servidor no arranca y lo dice (actívela con `extension=sodium` en `php.ini`).
- Cambiar la clave invalida los derechos firmados con la anterior en las apps que tengan la pública vieja.

## 3. Probar desde el teléfono en la misma Wi-Fi

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

Averigüe la IP de su computadora (macOS: `ipconfig getifaddr en0`) y apunte la app a `http://ESA_IP:8000`, p. ej.
`flutter run --dart-define=CALDERO_API=http://192.168.1.20:8000`. Compruebe con:

```bash
curl http://localhost:8000/v1/catalog
```

El panel está en `http://localhost:8000/admin`. Android bloquea HTTP sin cifrar en compilaciones de producción: para
pruebas locales use una compilación de depuración o un túnel HTTPS.

## 4. Panel del SuperAdmin (`/admin`)

- **Un solo administrador.** `php artisan mininoches:admin tu@correo` lo crea o le cambia la contraseña
  (`--password=` para scripts). Si ya existe otro correo, se niega. No hay registro público.
- Entrada con límite de intentos (5 por minuto por correo e IP) y CSRF en todos los formularios.
- **Panel:** suscriptores, pruebas, compras de 30 días, códigos canjeados, valoraciones y cuentos por revisar.
- **Cuentos:** filtros por pack, edad, enseñanza, estado y gratis; la ficha muestra cada escena con todas sus variantes
  (las `{marcas}` resaltadas) y las valoraciones de ese cuento. *Aprobar*, *Rechazar* (desaparece de la app),
  *Dejar pendiente*, notas y **Gratis**. Los pendientes siguen saliendo en la app. Cada cambio sube la versión del catálogo.
- **Compras y suscripciones:** Google Play y App Store, filtro por tienda, búsqueda por installId, hash del token o el token mismo (en iOS, el
  originalTransactionId); detalle con la respuesta de la tienda (en iOS, la transacción y la renovación ya verificadas, sin los id).
- **Códigos:** aleatorios `MINI-XXXX-XXXX` o propios, días, usos máximos, caducidad, activar/desactivar.
- **Valoraciones:** por pack y por cuento, peor valorados primero, con los motivos de las notas bajas.
- **Productos:** las suscripciones del catálogo (sembrado: `mininoches_premium`, Android, `anual` P1Y y `mensual` P1M, 7 días de prueba;
  los de iOS se añaden aquí con plataforma `ios`, ver §6).
- **Auditoría:** quién hizo qué y cuándo (sin IP).

## 5. Google Play

1. **Cuenta de servicio.** En Google Cloud (el proyecto vinculado a Play Console) cree una cuenta de servicio y una
   clave JSON. Active la *Google Play Android Developer API* en ese proyecto.
2. **Permisos en Play Console** → *Usuarios y permisos* → invite el correo de la cuenta de servicio con acceso a la app y
   los permisos **«Ver datos financieros»** y **«Gestionar pedidos y suscripciones»**. (Los cambios pueden tardar hasta 24 h.)
3. Guarde el JSON fuera de `public/` (p. ej. `storage/app/private/google-play.json`, ya ignorado por git) y ponga en el `.env`:
   ```
   GOOGLE_PLAY_PACKAGE=com.calderodecuentos.cuentos
   GOOGLE_SERVICE_ACCOUNT_JSON=/ruta/absoluta/google-play.json
   ```
   (o el contenido del JSON en una línea si su hosting solo admite variables).
4. **Notificaciones en tiempo real (RTDN).** En Google Cloud → Pub/Sub cree un tema (p. ej. `play-rtdn`), dé permiso de
   publicador a `google-play-developer-notifications@system.gserviceaccount.com`, y cree una suscripción **push** a:
   ```
   https://SU-SERVIDOR/v1/webhooks/google?token=EL_VALOR_DE_GOOGLE_RTDN_TOKEN
   ```
   En Play Console → *Monetizar* → *Configuración de monetización* ponga el nombre del tema y pulse «Enviar notificación de
   prueba» (aparece en *Compras y suscripciones → Últimas notificaciones*). Genere el token con
   `php -r "echo bin2hex(random_bytes(24)), PHP_EOL;"`.
5. Pruebe con una cuenta de *probador de licencias*: las compras de prueba salen marcadas «prueba» en el panel.

Cómo decide el servidor (`purchases.subscriptionsv2.get`): `ACTIVE` y `IN_GRACE_PERIOD` → premium; `CANCELED` → premium
hasta la fecha de fin; `EXPIRED`, `ON_HOLD`, `PAUSED` → `402 expired`; pendiente o token desconocido → `402 invalid_purchase`;
Google caído o sin configurar → `503 store_unavailable` (la app reintenta). La prueba gratis se detecta por
`offerPhase.freeTrial` (o una oferta con «trial» en el id o las etiquetas). Si la compra llega sin confirmar, el servidor la
confirma (`GOOGLE_ACKNOWLEDGE`), porque Google reembolsa las suscripciones no confirmadas a los 3 días.

## 6. App Store (iOS)

Si ya tenía el servidor instalado, ejecute `php artisan migrate` (añade `notification_id` a las notificaciones).

1. **Clave de la App Store Server API.** En App Store Connect → *Usuarios y acceso* → *Integraciones* → *Compra dentro
   de la app* (In-App Purchase) pulse «+», póngale nombre y descargue el archivo `SubscriptionKey_XXXXXXXXXX.p8`
   (**solo se puede descargar una vez**). Anote el **Key ID** (10 caracteres) y el **Issuer ID** (el UUID que sale
   arriba en *Integraciones → App Store Connect API*). Hace falta el rol Admin o Account Holder para crearla.
2. Guarde el `.p8` fuera de `public/` (p. ej. `storage/app/private/apple-iap.p8`, ya ignorado por git) y ponga en el `.env`:
   ```
   APPLE_ISSUER_ID=57246542-96fe-1a63-e053-0824d011072a
   APPLE_KEY_ID=2X9R4HXF34
   APPLE_PRIVATE_KEY=/ruta/absoluta/apple-iap.p8
   APPLE_BUNDLE_ID=com.calderodecuentos.cuentos
   APPLE_ENVIRONMENT=production
   APPLE_PRODUCT_IDS=mininoches_premium_anual:anual,mininoches_premium_mensual:mensual
   ```
   (o el PEM del `.p8` en una sola línea con `\n` si su hosting solo admite variables).
3. **Productos.** En la App Store cada duración es un producto distinto dentro de un **grupo de suscripción**
   (p. ej. `mininoches_premium_anual` y `mininoches_premium_mensual`, con la oferta introductoria «Prueba gratis 7 días»).
   Ponga los mismos id en `APPLE_PRODUCT_IDS` o créelos en el panel (*Productos*, plataforma `ios`) para que salgan en
   el catálogo. Una compra de otro producto o de otro bundle responde `402 invalid_purchase`.
4. **App Store Server Notifications V2.** En App Store Connect → su app → *Información general de la app* → *App Store
   Server Notifications* ponga, en **URL del servidor de producción** y en **URL del servidor de sandbox**, la misma
   dirección y elija la **versión 2**:
   ```
   https://SU-SERVIDOR/v1/webhooks/apple
   ```
   (no lleva token: cada notificación viene firmada por Apple y se verifica). Pruebe con
   `POST /inApps/v1/notifications/test` de la App Store Server API; aparece en *Compras y suscripciones → Últimas
   notificaciones* con el resultado `test`.
5. Pruebe con una cuenta de *Sandbox* (App Store Connect → *Usuarios y acceso* → *Sandbox*) o desde TestFlight; esas
   compras salen marcadas «prueba» en el panel. Las del archivo de StoreKit de Xcode **no** sirven: van firmadas con
   un certificado local, no con el de Apple, y el servidor las rechaza.

Cómo decide el servidor: con el `transactionId` que manda la app consulta `GET /inApps/v1/transactions/{id}` y luego
`GET /inApps/v1/subscriptions/{originalTransactionId}` (en producción y, si responde 404, en sandbox). Estado `1`
(activa) → premium hasta `expiresDate`; `4` (periodo de gracia) → premium hasta `gracePeriodExpiresDate`; `2` (caducada)
y `3` (reintento de cobro) → `402 expired`; `5` o `revocationDate` (reembolso o revocación) → `402 invalid_purchase`.
La prueba gratis se detecta por `offerDiscountType: FREE_TRIAL` (u `offerType: 1` con precio 0). Apple sin configurar,
caído o rechazando la clave → `503 store_unavailable`.

**Verificación de las firmas.** Todo lo que viene de Apple (`signedTransactionInfo`, `signedRenewalInfo` y el
`signedPayload` de las notificaciones) es un JWS ES256 que se verifica antes de usarlo: cadena `x5c` hasta **Apple Root
CA - G3** (fijada en `resources/certs/AppleRootCA-G3.pem`, de <https://www.apple.com/certificateauthority/>, y aceptada
solo si su huella SHA-256 coincide con la de `config/mininoches.php`), intermedio con el OID `1.2.840.113635.100.6.2.1`,
hoja con el OID `1.2.840.113635.100.6.11.1`, fechas de vigencia y firma. Si algo falla, la compra es `402` y la
notificación `400` (y no se guarda). No se consulta OCSP (revocación de certificados en línea).

**Notificaciones.** Se procesan `SUBSCRIBED`, `DID_RENEW`, `DID_FAIL_TO_RENEW` (gracia), `EXPIRED`,
`GRACE_PERIOD_EXPIRED`, `REFUND`, `REVOKE`, `DID_CHANGE_RENEWAL_STATUS`, `OFFER_REDEEMED` (y `DID_CHANGE_RENEWAL_PREF`,
`RENEWAL_EXTENDED`, `REFUND_REVERSED`): se busca la compra por el hash de la transacción original y se actualiza con la
transacción firmada que trae la notificación, sin volver a llamar a Apple. Cada `notificationUUID` se procesa una vez
(repetida → 200 sin hacer nada); una notificación firmada antes del último estado guardado no lo pisa (`stale`). Si la
app aún no presentó la compra, queda como `unknown_purchase`. La transacción original se guarda cifrada y se busca por
su SHA-256 (los id de Apple no quedan en claro: con ellos se podría reclamar la compra desde otra instalación).

## 7. Privacidad (docs/09 §7 y docs/12 §8)

- La API no usa cookies ni sesiones. No guarda IP: los límites de ritmo usan un HMAC de la IP con `APP_KEY` que vive
  un minuto en la caché. Las sesiones del panel van en archivos (`SESSION_DRIVER=file`) porque el driver `database` guarda IP.
- Valoraciones: sin instalación, IP ni hora (solo el día que manda la app y el día de recepción). Se validan contra la
  versión importada del pack; `id` repetido no duplica; máximo 50 eventos / 64 KB.
- Los tokens de compra (y en iOS la transacción original) se guardan cifrados con `APP_KEY` y se buscan por su SHA-256;
  en las notificaciones solo queda el hash.
- Nunca se recibe nombre ni edad del niño ni texto de los cuentos; cualquier campo de más en la petición se rechaza (422).
- Límites por minuto y por IP: API 60, verificar 20, canjear 5, valoraciones 30, webhooks 300 (configurables).

## 8. Publicar en un servidor

- PHP-FPM 8.3+ con Nginx/Apache apuntando a `server/public`, HTTPS obligatorio.
- `.env` de producción: `APP_ENV=production`, `APP_DEBUG=false`, `SESSION_SECURE_COOKIE=true`, `LOG_LEVEL=warning`,
  `APP_URL=https://…`, base de datos MySQL o Postgres, y `TRUSTED_PROXIES` si hay proxy o CDN delante.
- Desplegar: `composer install --no-dev --optimize-autoloader && php artisan migrate --force && php artisan config:cache && php artisan route:cache && php artisan view:cache`.
- Copie la carpeta `content/packs` (o fije `MININOCHES_PACKS_PATH`) y ejecute `php artisan mininoches:import-packs` tras cada versión de los packs.
- Copias de seguridad de la base de datos; guarde `APP_KEY`, `ENTITLEMENT_SIGNING_KEY` y la clave `.p8` de Apple en un gestor de secretos.
- Asegúrese de que los registros del servidor web no guarden la IP (o la recorten) para cumplir la política de privacidad.

## 9. Estructura

```
server/
├── app/
│   ├── Console/Commands/      mininoches:keys · mininoches:admin · mininoches:import-packs
│   ├── Exceptions/            StoreException (errores {"error","message"} del contrato)
│   ├── Http/Controllers/Api/  catálogo, compras, canje, derechos, webhooks, valoraciones
│   ├── Http/Controllers/Admin/ panel
│   ├── Models/                Premise, Pack, PackVersion, Product, Purchase, Entitlement, RedeemCode, StoryRating…
│   └── Services/              Catalog, PackImporter, GooglePlayClient, PurchaseService, EntitlementSigner, FeedbackIngestor
│       └── Apple/             AppStoreClient (JWT ES256), AppleJwsVerifier (cadena x5c + firma), Es256
├── config/mininoches.php      toda la configuración propia
├── database/                  migraciones y semilla
├── resources/certs/           AppleRootCA-G3.pem (raíz fijada para los JWS de Apple)
├── resources/views/           panel (Blade + Tailwind por CDN)
├── routes/api.php · web.php
├── tests/Feature/             pruebas (paquetes de prueba en tests/Fixtures/packs)
└── tests/Support/             AppleTestChain: cadena de certificados de prueba con los OID de Apple
```
