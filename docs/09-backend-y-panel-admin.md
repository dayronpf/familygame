# 09 · Backend y panel de administración

> Reemplaza la decisión ADR-002 («sin backend en el MVP»). La app sigue siendo *offline-first* para **leer**,
> pero el catálogo, las actualizaciones y las compras pasan por un backend propio administrado desde una web.

## 1. Principios

1. **El backend es la fuente de verdad del contenido.** Personajes, lugares, villanos, fragmentos, enseñanzas, packs y arte se crean y publican desde el panel.
2. **La app nunca depende de la red para leer** un cuento ya descargado. Lleva un pack inicial *embebido* (starter) por tres razones: la primera noche puede no haber WiFi, los revisores de las tiendas prueban sin sesión estable, y es el plan B si el backend cae. En el primer arranque la app va al backend, trae el catálogo vigente y lo reemplaza.
3. **Un único validador en todas partes:** el mismo del motor valida en CI, en el panel (mientras el autor escribe) y en la app (antes de instalar un pack).
4. **Las tiendas son la fuente de verdad del dinero.** El backend verifica, registra y refleja; no cobra por su cuenta.
5. **Privacidad infantil por diseño:** el backend no recibe datos personales de niños (ver §7).

## 2. Vista general

```
 ┌────────────┐   catálogo / packs / entitlements    ┌──────────────────────────┐
 │  App móvil │ ◀──────────────────────────────────▶ │  API pública (CDN + caché)│
 └─────┬──────┘                                       └────────────┬─────────────┘
       │ compra (IAP)                                              │
       ▼                                                           ▼
 ┌────────────┐   webhooks (renovación, reembolso)   ┌──────────────────────────┐
 │ Apple/Google│ ────────────────────────────────────▶│  Backend (API + jobs)    │
 └────────────┘                                       │  Postgres · Storage · CDN│
                                                      └────────────┬─────────────┘
 ┌─────────────────────────────┐   API de administración          │
 │ Panel web (autores, editores,│ ◀────────────────────────────────┘
 │ publicadores, finanzas)      │
 └─────────────────────────────┘
```

Tres superficies, con permisos distintos: **API pública** (solo lectura de catálogo + entitlements), **API de administración** (autenticada, con roles) y **webhooks** de las tiendas.

## 3. Flujo editorial (de la idea a la app)

```
Borrador ─▶ Validación automática ─▶ Revisión editorial ─▶ Publicar versión ─▶ Manifiesto firmado ─▶ Apps
              • esquema del pack          (otra persona)      (inmutable,         (CDN)
              • gramática/contracciones                        con hash)
              • cobertura por enseñanza
              • licencias de assets completas
```

- Cada **versión publicada es inmutable** (se identifica por número y hash). Corregir = publicar otra versión; hacer *rollback* = apuntar de nuevo a la anterior.
- **Vista previa en el panel:** el editor puede pulsar «generar 10 cuentos de muestra» con el mismo motor (compilado a JavaScript) y leer cómo suenan antes de publicar.
- **El libro de licencias vive en la base de datos:** un asset no puede publicarse si no tiene autor, fuente, licencia y prueba adjunta. Esto convierte la regla de derechos de autor (docs/04) en algo que el sistema *hace cumplir*, no en un buen propósito.

## 4. Sincronización en la app

- **Cuándo:** primer arranque; luego al abrir la app (máx. 1 vez al día) y manualmente desde Ajustes de adultos.
- **Qué recibe:** `GET /v1/catalog` (con `ETag`, así casi siempre responde «sin cambios»). Un manifiesto con, por pack: `id`, `version`, `schema`, `minAppVersion`, `sizeBytes`, `sha256`, `tier` (`free`/`premium`), `productId`, `url`.
- **Cómo instala:** descarga reanudable → verifica `sha256` y la **firma Ed25519** del manifiesto (la clave pública va dentro de la app) → instala de forma atómica (carpeta temporal y renombrar) → conserva la versión anterior para *rollback*.
- **Compatibilidad:** si el pack exige un esquema o una versión de app mayor, la app lo ignora y muestra «actualiza la app» (nunca se rompe).
- **Packs gratuitos:** URL pública en CDN. **Premium:** URL firmada de corta duración, solo tras comprobar el entitlement.
- **Más adelante:** actualizaciones diferenciales (por ahora packs temáticos pequeños, lo que ya limita la descarga).
- **Descargas responsables:** pedir permiso adulto para descargas > cierto tamaño, usar WiFi por defecto, mostrar tamaño y permitir borrar packs.

## 5. Compras y suscripciones enlazadas con el panel

```
App ──compra──▶ Tienda ──recibo/token──▶ App ──POST /v1/purchases/verify──▶ Backend
                                                                              │ verifica con la API de la tienda
                                                                              ▼
                              entitlement firmado ◀── crea/actualiza entitlement
```

- **Verificación en servidor** con la App Store Server API y la Google Play Developer API (nunca confiar solo en el cliente).
- **Notificaciones servidor-a-servidor** (App Store Server Notifications y Google Real-time Developer Notifications) para renovaciones, cancelaciones, reembolsos y periodos de gracia.
- **Entitlement firmado y con caducidad** guardado en el teléfono: permite usar lo comprado sin conexión durante un periodo de gracia.
- **Restaurar compras:** reconsulta a la tienda y al backend.
- **Panel:** compras por pack, suscriptores activos, ingresos recurrentes, reembolsos, cancelaciones, y un «buscar por recibo» para soporte.
- **Decisión abierta (spike S-06):** *capa propia* (más control, más trabajo) frente a un servicio como RevenueCat (menos trabajo, comisión por encima de cierto volumen y un SDK de terceros que hay que confirmar que es admisible en la categoría infantil de cada tienda). Hasta decidir, el diseño es válido para ambas.

## 6. Modelo de datos (resumen)

| Tabla | Contenido |
|---|---|
| `packs`, `pack_versions` | Pack lógico y sus versiones inmutables (estado: borrador/revisión/publicada/retirada, hash, tamaño) |
| `characters`, `places`, `morals`, `fragments` | El universo, ligado a un pack; cada fila con autor, estado de revisión y edad/susto |
| `assets`, `asset_licenses` | Archivos de arte/audio y su licencia, autor, fuente y prueba |
| `products`, `purchases`, `entitlements` | Productos de tienda, transacciones verificadas y derechos vigentes |
| `installs` | Identificador **anónimo** de instalación, versión de app, idioma (sin datos personales). **No se enlaza con las valoraciones** |
| `story_ratings` | Valoración 1–5 + motivo opcional (códigos, solo con nota ≤ 3) + receta del cuento (códigos) + día. Sin usuario, instalación, IP ni hora (ver [12 §8](12-valoraciones-y-mejora-continua.md)) |
| `admin_users`, `roles`, `audit_log` | Quién puede qué y quién hizo qué, con fecha |

## 7. Privacidad y seguridad

**El backend recibe:** identificador aleatorio de instalación, versión de app/SO, idioma, tokens de compra y las **valoraciones anónimas** de los cuentos (que no llevan ningún identificador). **No recibe:** nombre ni edad del niño, voz, ubicación precisa, identificadores publicitarios. El nombre del niño para cuentos personalizados se queda **solo en el teléfono**.

- Las IP pasan por el CDN/servidor: conservarlas lo mínimo y documentarlo en la política de privacidad.
- Panel: acceso con 2FA, **roles** (autor, editor, publicador, finanzas, administrador), registro de auditoría, y separación de ambientes (desarrollo / pruebas / producción).
- Base de datos con copias de seguridad probadas, secretos fuera del código, límites de tasa en la API pública y premium nunca servido sin entitlement.
- La política de privacidad y los formularios de tiendas deben reflejar este flujo (revisar con abogado).

## 8. Opciones de tecnología (propuesta a validar en un spike)

| Opción | Pros | Contras |
|---|---|---|
| **Supabase** (Postgres + Auth + Storage + funciones) | Arranque rápido, SQL real, políticas de seguridad por fila, almacenamiento con CDN | Dependencia de un proveedor; lógica de compras en funciones |
| Firebase | Muy conocido, buena integración móvil | Modelo documental menos cómodo para catálogo relacional y reportes de ventas |
| Backend propio (Dart o Node + Postgres) | Máximo control y un solo lenguaje con el motor (Dart) | Más trabajo de operación y seguridad |

**Recomendación inicial:** Postgres gestionado (p. ej. Supabase) para empezar, con la lógica de dominio aislada para poder migrar. **Panel web:** aplicación web (React/Next.js o Flutter Web) que usa el **motor compilado a JavaScript** para validar y previsualizar cuentos con el código real. Se decide en el spike S-07 (Sprint 3), mirando también coste mensual, sedes de datos y cumplimiento de privacidad.

## 9. API v1 (borrador de contrato)

| Método y ruta | Quién | Para qué |
|---|---|---|
| `GET /v1/catalog` | App | Manifiesto firmado de packs vigentes (con `ETag`) |
| `GET /v1/packs/{id}/{version}/download` | App | Descarga (pública o con URL firmada si es premium) |
| `POST /v1/installs` | App | Registrar instalación anónima |
| `POST /v1/purchases/verify` | App | Verificar compra y obtener entitlement |
| `GET /v1/entitlements` | App | Derechos vigentes |
| `POST /v1/feedback` | App | Valoraciones anónimas (1–5) de cuentos, por lotes e idempotentes. Contrato: [api/feedback.openapi.yaml](api/feedback.openapi.yaml); diseño en [12](12-valoraciones-y-mejora-continua.md) |
| `POST /v1/webhooks/apple`, `/google` | Tiendas | Eventos de compra y suscripción |
| `…/admin/*` | Panel | CRUD de contenido, validar, publicar, retirar, reportes |

El contrato se formaliza como **OpenAPI** en el Sprint 3, junto con un servidor simulado (*mock*) para que la app avance sin esperar al backend real.

## 10. Fases

| Fase | Entrega | Sprint |
|---|---|---|
| B0 | Contrato OpenAPI + servidor simulado + elección de tecnología (S-07) | S3 |
| B1 | Backend v0: catálogo, almacenamiento, manifiesto firmado; app sincroniza y trae el primer pack | S4–S5 |
| B2 | Panel v0: crear/editar contenido, validar, vista previa, publicar | S6 |
| B3 | Entitlements y verificación de compras, webhooks, panel de ventas | S14–S15 |
| B4 | Roles, auditoría, informes, endurecimiento y pruebas de carga | S15–S16 |
| B5 | Herramientas de creación: compositor de personajes por piezas (ver docs/10) | Post-1.0 |
