# Mininoches · servidor

API para la app (catálogo, verificación de compras, códigos, derechos firmados y valoraciones) y panel web del
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
- **Compras y suscripciones:** búsqueda por installId, hash del token o el token mismo; detalle con la respuesta de Google.
- **Códigos:** aleatorios `MINI-XXXX-XXXX` o propios, días, usos máximos, caducidad, activar/desactivar.
- **Valoraciones:** por pack y por cuento, peor valorados primero, con los motivos de las notas bajas.
- **Productos:** las suscripciones del catálogo (sembrado: `mininoches_premium`, Android, `anual` P1Y y `mensual` P1M, 7 días de prueba).
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

**iOS:** todavía no se verifica. `platform: ios` guarda la petición y responde `503 store_unavailable`; `/v1/webhooks/apple` solo guarda.

## 6. Privacidad (docs/09 §7 y docs/12 §8)

- La API no usa cookies ni sesiones. No guarda IP: los límites de ritmo usan un HMAC de la IP con `APP_KEY` que vive
  un minuto en la caché. Las sesiones del panel van en archivos (`SESSION_DRIVER=file`) porque el driver `database` guarda IP.
- Valoraciones: sin instalación, IP ni hora (solo el día que manda la app y el día de recepción). Se validan contra la
  versión importada del pack; `id` repetido no duplica; máximo 50 eventos / 64 KB.
- Los tokens de compra se guardan cifrados con `APP_KEY` y se buscan por su SHA-256; en las notificaciones solo queda el hash.
- Nunca se recibe nombre ni edad del niño ni texto de los cuentos; cualquier campo de más en la petición se rechaza (422).
- Límites por minuto y por IP: API 60, verificar 20, canjear 5, valoraciones 30, webhooks 300 (configurables).

## 7. Publicar en un servidor

- PHP-FPM 8.3+ con Nginx/Apache apuntando a `server/public`, HTTPS obligatorio.
- `.env` de producción: `APP_ENV=production`, `APP_DEBUG=false`, `SESSION_SECURE_COOKIE=true`, `LOG_LEVEL=warning`,
  `APP_URL=https://…`, base de datos MySQL o Postgres, y `TRUSTED_PROXIES` si hay proxy o CDN delante.
- Desplegar: `composer install --no-dev --optimize-autoloader && php artisan migrate --force && php artisan config:cache && php artisan route:cache && php artisan view:cache`.
- Copie la carpeta `content/packs` (o fije `MININOCHES_PACKS_PATH`) y ejecute `php artisan mininoches:import-packs` tras cada versión de los packs.
- Copias de seguridad de la base de datos; guarde `APP_KEY` y `ENTITLEMENT_SIGNING_KEY` en un gestor de secretos.
- Asegúrese de que los registros del servidor web no guarden la IP (o la recorten) para cumplir la política de privacidad.

## 8. Estructura

```
server/
├── app/
│   ├── Console/Commands/      mininoches:keys · mininoches:admin · mininoches:import-packs
│   ├── Exceptions/            StoreException (errores {"error","message"} del contrato)
│   ├── Http/Controllers/Api/  catálogo, compras, canje, derechos, webhooks, valoraciones
│   ├── Http/Controllers/Admin/ panel
│   ├── Models/                Premise, Pack, PackVersion, Product, Purchase, Entitlement, RedeemCode, StoryRating…
│   └── Services/              Catalog, PackImporter, GooglePlayClient, PurchaseService, EntitlementSigner, FeedbackIngestor
├── config/mininoches.php      toda la configuración propia
├── database/                  migraciones y semilla
├── resources/views/           panel (Blade + Tailwind por CDN)
├── routes/api.php · web.php
└── tests/Feature/             pruebas (paquetes de prueba en tests/Fixtures/packs)
```
