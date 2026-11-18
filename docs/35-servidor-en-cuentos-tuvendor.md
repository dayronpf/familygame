# 35 · El servidor en cuentos.tuvendor.com

> 18-nov-2026. Paso A8 del [plan maestro](31-plan-de-lanzamiento.md). El diseño está en [34](34-alojamiento-y-mejora-continua.md).

## Ya hecho

- **Subdominio** `cuentos.tuvendor.com` en el cPanel (hosting24). Su carpeta raíz es `/home/tuven780/external/cuentos.tuvendor.com/public`, que es la carpeta `public` de Laravel.
- **PHP 8.4** solo para ese subdominio: aislamiento por sitio. Los demás sitios siguen con 7.4. Las extensiones necesarias ya están activas. `sodium` no se pudo activar en el panel, así que el servidor usa `paragonie/sodium_compat`, que hace lo mismo.
- **Base de datos** `tuven780_cuentos`.
- **Publicación automática:** `.github/workflows/server-deploy.yml`. En cada push a la rama `servidor`:
  1. corre las pruebas;
  2. instala las dependencias de producción y copia los paquetes de cuentos;
  3. sube `server/` por FTP (nunca el `.env`);
  4. llama a `POST /internal/deploy`, protegido con una clave, que hace las migraciones, importa los paquetes y arma las cachés.

## Lo que haces tú, una sola vez

> Anota cada clave en `credenciales/.env` (plantilla en `credenciales/.env.ejemplo`): es el único lugar donde viven
> todas las credenciales del proyecto, y git no lo sube.

Son contraseñas y claves, así que las pones tú. No me las pases por el chat.

1. **Cloudflare (DNS de tuvendor.com):**
   - Registro `A` con nombre `cuentos` → `151.106.103.15`, con la nube naranja (proxy) encendida.
   - En SSL/TLS, el modo **Full**. Si cPanel emite un certificado para el subdominio (AutoSSL), mejor **Full (strict)**.
2. **cPanel → Manage My Databases:**
   - Crea el usuario `tuven780_cuentos` con una contraseña fuerte.
   - Agrégalo a la base de datos `tuven780_cuentos` con **ALL PRIVILEGES**.
3. **cPanel → FTP Accounts:**
   - Crea la cuenta `deploy@cuentos.tuvendor.com` (o el nombre que prefieras).
   - Su carpeta debe ser `external/cuentos.tuvendor.com`. Ojo: no la carpeta `public`.
4. **El archivo `.env` del servidor:** créalo en cPanel → File Manager, en `external/cuentos.tuvendor.com/.env`, con esto:
   ```
   APP_NAME=Mininoches
   APP_ENV=production
   APP_DEBUG=false
   APP_URL=https://cuentos.tuvendor.com
   APP_KEY=                      # paso 5
   DB_CONNECTION=mysql
   DB_HOST=localhost
   DB_PORT=3306
   DB_DATABASE=tuven780_cuentos
   DB_USERNAME=tuven780_cuentos
   DB_PASSWORD=<la del paso 2>
   SESSION_DRIVER=file
   CACHE_STORE=file
   QUEUE_CONNECTION=sync
   MININOCHES_DEPLOY_TOKEN=<una clave larga al azar, la misma que DEPLOY_TOKEN en GitHub>
   ```
   Lo demás (Google Play, Apple, clave de firma) sale de `server/.env.example` y se llena cuando tengas esas cuentas.
5. **GitHub → el repositorio → Settings → Secrets and variables → Actions:**
   - Crea los secretos `FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD` y `DEPLOY_TOKEN`.
   - En Settings → Environments, crea el entorno `produccion`.
6. **La primera vez, después del primer despliegue, en cPanel → Terminal.** Ojo: en la terminal, `php` es la 7.4, así que hay que usar la 8.4 por su ruta:
   ```
   cd ~/external/cuentos.tuvendor.com
   /opt/alt/php84/usr/bin/php artisan key:generate --force
   /opt/alt/php84/usr/bin/php artisan mininoches:keys
   /opt/alt/php84/usr/bin/php artisan migrate --force
   /opt/alt/php84/usr/bin/php artisan mininoches:admin tu@correo.com
   ```
   - `mininoches:keys` crea la clave que firma las compras; sigue lo que te indique.
   - `mininoches:admin` te pide la contraseña del panel.

Después, cada `git push` a la rama `servidor` publica solo. El panel queda en `https://cuentos.tuvendor.com/admin`.

## Audio y cuentos nuevos (Cloudflare R2)

Se configura igual de una sola vez:
- Crea un bucket R2, por ejemplo `mininoches`, con el dominio propio `audio.tuvendor.com` o `cuentos-audio.tuvendor.com`.
- Crea una clave de API de R2 con permiso de escritura en ese bucket, y guárdala en `credenciales/.env` (ver `credenciales/.env.ejemplo`) para `tools/content/publish.py --subir`.
- Después lleno `contentBaseUrl` y `recordedVoiceBaseUrl` en `app/lib/src/brand.dart` y publico el contenido.
