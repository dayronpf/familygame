# 02 · Hoja de ruta

Sprints de 2 semanas. Las duraciones son **indicativas** (suponen un equipo pequeño a tiempo parcial);
lo que manda son los **criterios de salida** de cada release.

> **Cambio de plan:** al incorporar el backend y el panel de administración ([09](09-backend-y-panel-admin.md))
> se añade la versión **0.2 «Catálogo»** (≈ 3 sprints). El plan pasa de ~13 a ~16 sprints hasta el lanzamiento.
> Es el precio de que todo el contenido, las actualizaciones y las compras vivan en un sistema administrable.

## Vista general

```
AHORA                  SIGUIENTE                                              DESPUÉS
S0  S1-S3        S4-S6       S7-S8     S9-S11      S12-S13     S14-S16       Post-1.0
│   │            │           │         │           │           │             │
Fund. 0.1 Chispa 0.2 Catálogo 0.3 Voz  0.4 Vida    0.5 Holo    1.0 Lanzam.   Packs, idiomas,
      (motor)    (backend+sync)(narración)(animación)(pirámide) (compras)     personalización,
                 + panel v0                                                   compositor
```

## Releases

### Sprint 0 · Fundamentos ✅
Visión, plan, arquitectura, reglas de contenido y derechos; prototipo del caldero.

### 0.1 «Chispa» — el caldero cuenta (S1–S3) · *alfa interna*
**Objetivo:** que un cuento generado *se sienta bien* leído por un adulto.
- S1 ✅ Motor en Dart, validador, esquema de pack, CI, primera pantalla.
- S2: lectura compartida (escenas, historial, favoritos, edad/duración/susto).
- S3: pack semilla (~25 personajes, ~15 lugares, ~120 fragmentos, 6 enseñanzas), prueba con 10 familias, **contrato OpenAPI + servidor simulado + elección de tecnología de backend (S-07)**.
- **Salida:** ≥ 70 % de las familias dice «me contaría otro»; sin errores gramaticales graves; contrato de API acordado.

### 0.2 «Catálogo» — backend y sincronización (S4–S6) · *nuevo*
**Objetivo:** el contenido vive en el backend y la app lo trae sola.
- S4–S5: backend v0 (catálogo, almacenamiento/CDN, versiones inmutables, **manifiesto firmado**); la app sincroniza en el primer arranque y luego periódicamente, verifica hash/firma, instala de forma atómica y conserva el **starter embebido** como plan B. **Spike S-04 de arte** (personaje modular) para fijar el formato de los assets del pack.
- S6: **panel de administración v0:** crear/editar personajes, lugares, fragmentos y enseñanzas, validar con el mismo validador, vista previa de cuentos, publicar versión.
- **Salida:** un autor publica un pack desde el panel y aparece en un teléfono recién instalado sin tocar código; la app funciona en modo avión con lo ya descargado; un pack con errores no se puede publicar.

### 0.3 «Voz» — narración (S7–S8)
- Spike y decisión de voz (sistema vs. neuronal offline vs. nube) — ADR-004. **Spike S-06 de compras** (para adelantar los trámites de tiendas).
- Modo **Escucha** y modo **Lectura compartida** con voz; temporizador de sueño con bajada gradual de volumen y brillo.
- **Salida:** un cuento de 8 min se narra sin cortes en 2 Android y 2 iOS; la voz es aceptable según 5 familias.

### 0.4 «Vida» — animación (S9–S11)
- Motor de escenas: directivas `scene` → animaciones sincronizadas con la narración, según el sistema modular de [10](10-arte-y-estilo-visual.md).
- Kit del pack gratuito: 3–4 rigs, ~10 personajes, ~6 fondos, partículas y ambientes; assets entregados por el catálogo.
- **Salida:** presupuesto de rendimiento cumplido (60 FPS gama media, tamaños de [10 §4](10-arte-y-estilo-visual.md)); las escenas son coherentes con el texto.

### 0.5 «Holograma» — pirámide (S12–S13)
- Spike previo S-03 (3 teléfonos, 2 tamaños de pirámide). Modo holograma: 4 vistas, calibración, brillo, bloqueo de apagado, plantilla imprimible.
- **Salida:** 5 familias montan la pirámide en menos de 10 min y el efecto se distingue claramente a oscuras.

### 1.0 «Lanzamiento» — freemium (S14–S16)
- **Compras y suscripciones:** verificación en servidor, entitlements, webhooks de tiendas, panel de ventas, restaurar compras, **control parental**.
- Roles y auditoría del panel, copias de seguridad, pruebas de carga.
- Pack gratuito «Bosque Encantado», política de privacidad, formularios de tiendas, prueba cerrada (verificar requisitos vigentes de Google Play para cuentas nuevas), ficha de tienda.
- **Salida:** revisión de tiendas aprobada; 0 fallos bloqueantes en 2 semanas de beta; compra y suscripción verificadas de punta a punta con cuentas de prueba; checklist legal completo.

### Post-1.0 (cadencia «tren de contenido»)
- Un pack premium cada 4–6 semanas, **publicado desde el panel sin nueva versión de app**.
- Compositor de personajes por piezas en el panel; cuentos con el nombre del niño; segundo idioma; modo cuna (solo audio).
- Cuenta opcional de adulto para compartir compras entre dispositivos.
- IA solo como ayuda de borradores para autores, nunca generación libre sin revisión.

## Dependencias críticas

```
Modelo de contenido ─▶ Motor ─▶ Contrato API ─▶ Backend + sync ─▶ Panel v0 ─▶ Packs
                                      │                │
                                      └──▶ App sincroniza ──▶ Narración ─▶ Animación ─▶ Holograma
Compras (S-06 temprano) ─────────────────────────────────────────────────────────────▶ 1.0
Contenido y arte (carriles paralelos) alimentan todos los pasos
```

## Cómo se mide el avance

- Un release termina cuando se cumple su **criterio de salida**, aunque tarde un sprint más.
- Cada revisión de sprint incluye una **demo en dispositivo real** y una nota de aprendizaje.
- Si en un sprint aparece algo que contradice la visión, se detiene y se revisa el roadmap (no se parcha).
