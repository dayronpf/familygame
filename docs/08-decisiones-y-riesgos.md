# 08 · Decisiones, supuestos y riesgos

## Registro de decisiones (ADR)

| # | Decisión | Estado | Motivo | Revisar cuando |
|---|---|---|---|---|
| 001 | Flutter/Dart para Android + iOS | **En uso** (Flutter 3.47.6; falta probar en dispositivos) | Un código, buen 2D, buena integración con TTS/compras; render múltiple fácil para el holograma | Si el spike de animación (S-04) no llega a 60 FPS |
| 002 | ~~Offline-first, sin backend en MVP~~ | **Reemplazada por 011** | Cambió el requisito: el contenido, las actualizaciones y las compras deben administrarse desde un panel | — |
| 003 | Packs en JSON versionado + `manifest.json` | **Aceptada** (validada en spike S-01) | Legible por autores, validable en CI, independiente del lenguaje | Si el volumen exige base de datos |
| 004 | Voz: TTS del sistema al inicio; decidir tras S-02 | Abierta | Gratis y offline, pero calidad variable | Resultado de S-02 |
| 005 | Animación 2D vectorial modular: **dibujo propio en Flutter** (ver 014); Rive/Lottie quedan de plan B | **Aceptada** (pendiente de medir) | Estilo propio, barato de producir y ligero | Resultado de S-04 (ver [10](10-arte-y-estilo-visual.md)) |
| 006 | Compra única por pack y suscripción «Familia»; verificación en servidor (capa propia o RevenueCat, S-06) | Propuesta | Las tiendas son la fuente de verdad; el backend refleja | Resultado de S-06 |
| 007 | Modo por defecto: Lectura compartida | **Aceptada** | Alineado con la misión de rescatar el hábito de leer | Pruebas con familias |
| 008 | Todo el texto es de autor humano; la IA solo ayuda a borradores | **Aceptada** | Derechos de autor y calidad | Cambios legales/tecnológicos |
| 009 | Generador aleatorio propio (mulberry32) en el motor, no `dart:math` | **Aceptada** | La secuencia de `Random` no está garantizada entre versiones del SDK; las semillas guardadas o compartidas deben dar siempre el mismo cuento | Nunca a la ligera: cambiarlo invalida los cuentos guardados (hay una prueba que lo fija) |
| 014 | Personajes, animaciones y escenas son **datos JSON versionados** (`caldero-rig`, `caldero-clips`, `caldero-scene`, versión 1) con un renderizador propio en Flutter y **sin dependencias externas de animación** | **Aceptada** (verificada en navegador; falta medir en Android) | Pesan KB, el panel puede editarlos, una misma biblioteca de clips sirve a todos los personajes del mismo esqueleto | Tras medir en Android de gama media (si no llega a 60 fps se optimiza o se evalúa Rive) |
| 015 | **La valoración (1–5) es lo único que se recoge**, más un **motivo opcional** de cinco códigos fijos cuando la nota es ≤ 3 (nunca texto libre); viaja con la receta del cuento (códigos, sin texto ni nombres), solo el día (sin hora) y **sin identificador de instalación**; la IP no se guarda. **Activada por defecto** con transparencia y borrado al desactivar. **No** se registra el abandono de cuentos | **Aceptada** (decidida por el dueño del producto; ver [12 §9](12-valoraciones-y-mejora-continua.md)) | Mejora continua sin datos personales de menores; el motivo separa coherencia de susto o largo | Revisión legal antes de 1.0; si algún día se quiere medir el abandono |
| 016 | El análisis **marca, no decide**: regresión ridge que estima todos los efectos a la vez (no promedios simples); umbral doble (efecto < −0,3 y z < −2, ≥ 20 apariciones); revisión humana obligatoria | **Aceptada** (validada por simulación) | Un promedio simple confunde enseñanza con fragmento (se estanca en ~83 % de aciertos) | Con datos reales: recalibrar umbrales |
| 017 | La mejora se aplica como **versión nueva del pack** (textos y pesos); nunca cambios en caliente | **Aceptada** | Cada cuento sigue siendo reproducible y auditable | — |
| 010 | Monorepo: `app/` + `packages/caldero_engine/` + `content/` | **Aceptada** | El motor se prueba sin Flutter (rápido) y el contenido tiene su propio flujo | Si el contenido pasa a un repositorio aparte |
| 011 | Backend propio con panel web como fuente de verdad del contenido; la app sigue siendo offline-first para leer (starter embebido + caché) | **Aceptada** (tecnología por decidir en S-07) | Permite crecer el universo de historias sin publicar la app; centraliza compras y licencias | Resultado de S-07 |
| 012 | Un solo validador (el del motor) en CI, panel y app; versiones de pack inmutables y manifiesto firmado | **Aceptada** | Un pack roto no debe llegar nunca a un teléfono | — |
| 013 | Arte modular y vectorial propio (rigs + piezas + paletas). **Con presupuesto cero la vía principal es arte generado por código** (escrito con ayuda de IA, dirigido y aprobado por el dueño del producto); los modelos de imagen generativa no se usan para arte final; el contrato de cesión pasa a ser opcional (si se contrata a alguien) | **Aceptada**, ver [11](11-pipeline-de-arte-por-codigo.md) (probada en el generador y el navegador; falta el renderizador de Flutter) | Derechos claros, ~8 KB por personaje, escala a cientos de personajes, sin herramientas de pago | Tras A2 (medición en Android de gama media) y la revisión legal previa a 1.0 |

## Supuestos que conviene confirmar contigo

1. **Equipo:** se asume 1–3 personas a tiempo parcial. Si es distinto, cambia la duración de los sprints, no el orden.
2. **Idioma inicial:** español. Inglés después.
3. **Edad objetivo:** 3–8 años en dos bandas.
4. **Mercado y país:** afecta a marca, privacidad (COPPA/RGPD/leyes locales), impuestos y precios.
5. **Presupuesto para arte y voz:** define si se encarga, se compra con licencia o se usan assets CC0 al principio.
6. **Dispositivos de prueba:** al menos 1 Android y 1 iPhone (para compilar en iOS hace falta un Mac).
7. **Nombre:** «Caldero de Cuentos» es provisional.

## Riesgos principales

| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Los cuentos suenan a «plantilla» y repetitivos | Alta | Alto | Estado causal, muchos fragmentos por etapa, arcos escritos, pruebas con familias desde la 0.1 |
| Volumen de contenido de calidad (cientos de elementos) | Alta | Alto | Carril de contenido con su propio flujo, plantilla de autor, validador, cadencia realista por packs |
| Voz poco natural o con licencia restrictiva | Media | Alto | Spike S-02, ADR-004, plan B de lectura compartida |
| El holograma decepciona (tamaño, luz, pirámide casera) | Media | Medio | Spike S-03 temprano, plantilla imprimible, expectativas claras en la ficha |
| Rechazo o restricciones en tiendas por ser app infantil | Media | Alto | Diseñar desde ya sin anuncios/rastreo, puerta parental, revisar políticas vigentes |
| Infracción de derechos (assets, nombres, voces) | Baja si hay proceso | Muy alto | Libro de licencias, política de contenido, revisión legal previa a 1.0 |
| Pérdida de visión / sobre-ingeniería del motor | Media | Medio | Esqueleto andante, criterios de salida por release, objetivo de sprint de una frase |
| Rendimiento/consumo en teléfonos de gama baja | Media | Medio | Presupuesto de 60 FPS, perfiles de rendimiento por sprint, assets ligeros |
| Uso excesivo de pantalla por la noche | Media | Medio | Modo noche, temporizador de sueño, cierre de cuento tranquilo, modo solo audio |
| El backend añade coste operativo y una superficie de seguridad nueva | Alta | Alto | Tecnología gestionada, ambientes separados, 2FA y roles en el panel, copias de seguridad probadas, límites de tasa |
| El backend recibe datos de menores sin querer | Baja si hay diseño | Muy alto | Solo identificador anónimo y tokens de compra; nombre del niño solo en el teléfono; revisión de privacidad antes de 1.0 |
| Un SDK de compras de terceros no es admisible en la categoría infantil | Media | Medio | Spike S-06; plan B de verificación propia con las APIs de las tiendas |
| Estilo visual que se parezca a obras existentes | Media | Alto | Guía de estilo propia, prueba de parecido, licencias obligatorias en el panel, referencias de terceros fuera del repositorio |
| El arte generado por código no alcanza la calidad esperada | Media | Alto | Ciclos de revisión visual, ajuste de estilo con tu criterio, medir con familias; plan B: contratar a un ilustrador solo para el estilo base y seguir con el sistema modular |
| Protección legal incierta del material creado con ayuda de IA | Media | Medio | Dirección y aprobación humana documentadas, registro de marca del nombre y personajes principales, revisión legal antes de 1.0 |
| El holograma multiplica el coste de dibujo (4 vistas) | Media | Medio | Registrar la escena una vez y repetirla (S-03), límite de FPS, modo bajo consumo |
| Pocas familias al inicio ⇒ las valoraciones tardan semanas en dar señal | Alta | Medio | Salir pronto a un grupo de prueba; recordatorio de la mañana; no tocar contenido con menos de ~1 000 valoraciones |
| Sesgo de respuesta o notas que miden otra cosa (voz, susto, cansancio) | Media | Medio | Informar siempre con n y z; motivo opcional (D2); revisión humana; no confundir «gustar» con «coherencia» |
| Notas falsas o ráfagas maliciosas contra un fragmento | Baja | Medio | Validar contra el catálogo, límite de ritmo, estadística robusta, atestación de la app más adelante |
| Marco legal de recogida de datos de menores (aunque sea anónima) | Media | Alto | No hay identificadores; transparencia y borrado en ajustes; **revisión legal antes de 1.0** |
