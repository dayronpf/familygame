# 34 · Dónde viven los cuentos y cómo llegan cuentos nuevos

> 18-nov-2026. Pasos A8 y B1 del [plan maestro](31-plan-de-lanzamiento.md).

## 1. Qué hay que alojar

| Qué | Tamaño | Quién lo pide |
|---|---|---|
| Audio de los cuentos (Isabela, AAC 64 kbps) | ≈ 75 MB hoy, ≈ 160 MB con 100 cuentos; un cuento ≈ 1,5 MB | la app, al abrir un cuento que no tiene |
| Contenido: paquetes (texto), catálogo y manifiesto de voz | ≈ 1–2 MB por idioma | la app, una vez al día |
| Servidor Laravel (compras, derechos, catálogo, valoraciones, panel) | — | la app y Google o Apple |
| Página con la política de privacidad y los términos | — | las tiendas lo exigen |

## 2. Cómo lo planteo

```
                 ┌────────── Almacén de archivos (Cloudflare R2) ──────────┐
App ──GET────────▶ contenido/es/indice.json · paquetes · catálogo · voz     │  sin costo por descarga
    ──GET────────▶ voz/es/<huella>.m4a                                      │
                 └──────────────────────────────────────────────────────────┘
    ──API────────▶ Servidor Laravel (compras, derechos, gratis y ocultos, valoraciones, panel)
```

- **Los archivos no pasan por el servidor.** El audio y el contenido son archivos que no cambian. Van en un almacén, para que una noche con muchas familias no tumbe el servidor ni cueste dinero en tráfico. **Cloudflare R2** sale gratis hasta 10 GB y no cobra por descarga.
- **El servidor solo hace lo que necesita lógica:** compras, derechos y la lista de gratis y ocultos que se decide en el panel.
- **La app trae todo dentro para funcionar sin conexión el primer día:** los 3 cuentos gratis con su voz, los paquetes y el catálogo. Lo de afuera solo suma.

## 3. Mejora continua: cuentos nuevos sin actualizar la app

1. **Escribir** los cuentos nuevos en el paquete, con las mismas reglas: guía de autoría, rúbrica y validador.
2. **Auditar** como en [32](32-auditoria-50-cuentos.md) y [33](33-auditoria-39-cuentos.md), y que el dueño del producto apruebe.
3. **Añadirlos al catálogo** (`content/catalogo/lanzamiento-es.json`). El catálogo sube de versión.
4. **Grabar** solo lo nuevo con `tools/voice/render_catalog.py`, que no repite lo grabado ni lo cobra dos veces.
5. **Publicar** con una herramienta que:
   - valida;
   - prepara el audio (`export_app.py`);
   - sube al almacén el audio nuevo, los paquetes, el catálogo y el manifiesto;
   - al final, sube `indice.json` con la versión y la huella de cada archivo.
6. **Al día siguiente, la app** lee `indice.json`:
   - Si hay versión nueva y su motor la entiende, baja los archivos, comprueba sus huellas y los guarda.
   - Desde ese momento «Explorar» muestra los cuentos nuevos, con la insignia *Nuevo*.
   - Si algo falla, sigue con lo que tenía.

**Límite:** un cuento nuevo solo puede usar personajes, lugares y dibujos que ya existen en la app. Un mundo nuevo, con arte nuevo, sí necesita una actualización en las tiendas.

**Otros idiomas:**
- Cada idioma tiene su propio catálogo (`lanzamiento-en.json`) y su propio audio (`voz/en/`).
- La app elige según el idioma de los cuentos que está en Ajustes.
- El texto de cada idioma lo escribe o lo revisa una persona.

**Qué sale de las valoraciones:** cada valoración llega con la receta exacta del cuento ([12](12-valoraciones-y-mejora-continua.md)). Los cuentos con notas bajas se revisan primero.

## 4. Decisión del dueño del producto: dónde vive cada cosa

Hace falta **una dirección de internet** para tres cosas:
- el servidor;
- el almacén de audio;
- la página de privacidad, que las tiendas piden como URL.

| Opción | Costo | Qué tiene de bueno | Qué tiene de malo |
|---|---|---|---|
| **A. Dominio propio en Cloudflare** (por ejemplo `mininoches.app`) + R2 + un servidor pequeño (VPS de ≈ USD 5 al mes o Laravel Cloud) | dominio ≈ USD 10–15 al año + servidor ≈ USD 5 al mes; R2 gratis | Todo bajo un nombre propio: `api.`, `audio.` y la web. Sirve también para el correo y la landing. Es lo normal para lanzar | Hay que pagar el dominio y el servidor |
| B. Sin dominio: R2 con su dirección `r2.dev` + un servidor con subdominio gratis del proveedor | servidor ≈ USD 5 al mes | No se compra dominio | Cloudflare dice que `r2.dev` es solo para pruebas y le pone límite de velocidad. Las direcciones quedan feas y cambiarlas después obliga a actualizar la app |

**Recomendación: A.** Es lo que pide la ficha de las tiendas (web, privacidad y soporte con un nombre fiable) y evita cambiar direcciones después del lanzamiento. Las cuentas y los pagos los hace el dueño del producto. Yo dejo los pasos exactos, los registros DNS y la configuración.

## 5. Qué se puede hacer ya, sin decidir el alojamiento

- La app con contenido remoto: lee `indice.json`, baja, comprueba la huella y usa lo nuevo. La dirección es una constante que se llena al decidir.
- La herramienta de publicación, que funciona con cualquier almacén compatible con S3 (R2 lo es). Con `--en-carpeta`, deja todo en `builds/publicar/` para probar sin subir nada.

## 6. Cómo publicar cuentos nuevos

Desde la raíz del repositorio, en este orden:

1. **Escribir** los cuentos en su paquete (`content/packs/<id>/pack.json`), con la guía de autoría y la rúbrica.
2. **Validar:**
   ```
   cd packages/caldero_engine && dart run bin/validate_pack.dart ../../content/packs/<id>/pack.json && cd -
   ```
3. **Añadirlos al catálogo** (`content/catalogo/lanzamiento-es.json`): subir `version` (por ejemplo de `1.1` a `1.2`) y poner a cada cuento nuevo `"desde": "1.2"`. Los que tienen `desde` igual a la versión del catálogo llevan la insignia *Nuevo*. Luego `tools/sync_assets.sh`, para que la app también los traiga dentro.
4. **Grabar** solo lo nuevo:
   ```
   python3 tools/voice/render_catalog.py
   ```
5. **Preparar el audio** para la app y el servidor:
   ```
   python3 tools/voice/export_app.py
   ```
6. **Publicar.** Primero en carpeta, para revisar (`builds/publicar/`); después, de verdad:
   ```
   python3 tools/content/publish.py --en-carpeta
   python3 tools/content/publish.py --subir --env ~/.config/mininoches/r2.env
   ```
   `publish.py` vuelve a validar los paquetes y se niega a seguir si el audio no está listo (con `--exportar`, ejecuta antes `export_app.py`). Sube primero el audio que falta, luego los paquetes, el catálogo y la voz, y al final `indice.json`. Las credenciales van en el entorno o en el `.env` (`S3_ENDPOINT_URL`, `S3_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`), nunca en el repositorio.

**En la app** (`app/lib/src/content/remote_content.dart`):
- La raíz del almacén es `contentBaseUrl` en `brand.dart`. Se llena en A8. Vacía = apagado.
- Una vez al día, después de arrancar, lee `contenido/es/indice.json`. Si la `version` es mayor que la guardada, el `motor` no pasa de `contentEngineVersion` y el catálogo no es más viejo que el que trae la app, baja solo los archivos que cambiaron. Comprueba su sha256, los lee con el motor y los guarda. El índice local se escribe al final.
- Lo nuevo vale desde el siguiente arranque. Si algo no cuadra (sin red, huella mala, JSON roto, motor viejo), sigue con lo anterior o con lo que trae dentro.
- El audio de los cuentos nuevos lo baja `CachedClipStore` de `voz/es/` en la misma raíz, salvo que `recordedVoiceBaseUrl` diga otra cosa.
- `contentEngineVersion` (`packages/caldero_engine/lib/src/catalog.dart`) sube solo cuando cambia el formato del contenido, de modo que una app vieja ya no lo entendería.
