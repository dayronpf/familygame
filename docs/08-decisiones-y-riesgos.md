# 08 · Decisiones, supuestos y riesgos

## Registro de decisiones (ADR)

| # | Decisión | Estado | Motivo | Revisar cuando |
|---|---|---|---|---|
| 001 | Flutter/Dart para Android + iOS | **En uso** (Flutter 3.47.6; falta probar en dispositivos) | Un código, buen 2D, buena integración con TTS/compras; render múltiple fácil para el holograma | Si el spike de animación (S-04) no llega a 60 FPS |
| 002 | ~~Offline-first, sin backend en MVP~~ | **Reemplazada por 011** | Cambió el requisito: el contenido, las actualizaciones y las compras deben administrarse desde un panel | — |
| 003 | Packs en JSON versionado + `manifest.json` | **Aceptada** (validada en spike S-01) | Legible por autores, validable en CI, independiente del lenguaje | Si el volumen exige base de datos |
| 004 | Voz: TTS del sistema al inicio; decidir tras S-02 | Abierta | Gratis y offline, pero calidad variable | Resultado de S-02 |
| 005 | Animación 2D vectorial modular (Rive / Lottie / dibujo propio) | Abierta | Estilo propio, barato de producir y ligero | Resultado de S-04 (ver [10](10-arte-y-estilo-visual.md)) |
| 006 | Compra única por pack y suscripción «Familia»; verificación en servidor (capa propia o RevenueCat, S-06) | Propuesta | Las tiendas son la fuente de verdad; el backend refleja | Resultado de S-06 |
| 007 | Modo por defecto: Lectura compartida | **Aceptada** | Alineado con la misión de rescatar el hábito de leer | Pruebas con familias |
| 008 | Todo el texto es de autor humano; la IA solo ayuda a borradores | **Aceptada** | Derechos de autor y calidad | Cambios legales/tecnológicos |
| 009 | Generador aleatorio propio (mulberry32) en el motor, no `dart:math` | **Aceptada** | La secuencia de `Random` no está garantizada entre versiones del SDK; las semillas guardadas o compartidas deben dar siempre el mismo cuento | Nunca a la ligera: cambiarlo invalida los cuentos guardados (hay una prueba que lo fija) |
| 010 | Monorepo: `app/` + `packages/caldero_engine/` + `content/` | **Aceptada** | El motor se prueba sin Flutter (rápido) y el contenido tiene su propio flujo | Si el contenido pasa a un repositorio aparte |
| 011 | Backend propio con panel web como fuente de verdad del contenido; la app sigue siendo offline-first para leer (starter embebido + caché) | **Aceptada** (tecnología por decidir en S-07) | Permite crecer el universo de historias sin publicar la app; centraliza compras y licencias | Resultado de S-07 |
| 012 | Un solo validador (el del motor) en CI, panel y app; versiones de pack inmutables y manifiesto firmado | **Aceptada** | Un pack roto no debe llegar nunca a un teléfono | — |
| 013 | Arte modular y vectorial propio (rigs + piezas + paletas), con contrato de cesión; IA solo para explorar | **Aceptada** (formato por decidir en S-04) | Derechos claros, bajo peso, escala a cientos de personajes | Resultado de S-04 |

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
| Estilo visual que se parezca a obras existentes | Media | Alto | Guía de estilo propia, prueba de parecido, contrato de cesión, licencias obligatorias en el panel |
| El holograma multiplica el coste de dibujo (4 vistas) | Media | Medio | Registrar la escena una vez y repetirla (S-03), límite de FPS, modo bajo consumo |
