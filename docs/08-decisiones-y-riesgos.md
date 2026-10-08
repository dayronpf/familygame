# 08 · Decisiones, supuestos y riesgos

## Registro de decisiones (ADR)

| # | Decisión | Estado | Motivo | Revisar cuando |
|---|---|---|---|---|
| 001 | Flutter/Dart para Android + iOS | Propuesta | Un código, buen 2D, buena integración con TTS/compras; render múltiple fácil para el holograma | Si el spike de animación (S-04) no llega a 60 FPS |
| 002 | Offline-first, sin backend en MVP | Propuesta | Menos coste, menos riesgo de privacidad infantil | Al necesitar cuentas, sincronización o verificación de recibos en servidor |
| 003 | Packs en JSON versionado + `manifest.json` | **Aceptada** (validada en spike S-01) | Legible por autores, validable en CI, independiente del lenguaje | Si el volumen exige base de datos |
| 004 | Voz: TTS del sistema al inicio; decidir tras S-02 | Abierta | Gratis y offline, pero calidad variable | Resultado de S-02 |
| 005 | Animación 2D por capas (Flutter + Lottie/Rive) | Propuesta | Estilo propio, barato de producir | Resultado de S-04 |
| 006 | Compra única por pack; suscripción más adelante | Propuesta | Más simple de explicar a los padres | Datos de conversión |
| 007 | Modo por defecto: Lectura compartida | **Aceptada** | Alineado con la misión de rescatar el hábito de leer | Pruebas con familias |
| 008 | Todo el texto es de autor humano; la IA solo ayuda a borradores | **Aceptada** | Derechos de autor y calidad | Cambios legales/tecnológicos |

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
