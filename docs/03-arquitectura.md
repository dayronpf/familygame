# 03 · Arquitectura

## Resumen de decisiones

| Tema | Decisión propuesta | Alternativas | ADR |
|---|---|---|---|
| Multiplataforma | **Flutter (Dart)**, un solo código para Android e iOS | React Native, Unity | 001 |
| Backend | **Ninguno en el MVP** (offline-first); CDN estático para packs | Firebase, backend propio | 002 |
| Formato de contenido | **JSON versionado por pack** (ver [06](06-modelo-de-contenido.md)) | SQLite precargada | 003 |
| Voz | Empezar con **TTS del sistema**; decidir tras spike | TTS neuronal offline, TTS en la nube, grabación humana | 004 |
| Animación | **Capas 2D con animaciones nativas de Flutter + Lottie/Rive** | Flame, Unity | 005 |
| Compras | `in_app_purchase` o RevenueCat | — | 006 |

> Son propuestas razonadas, no dogmas: cada una tiene un spike o criterio para revisarla.
> Por qué Flutter: un solo código, excelente rendimiento 2D, buen soporte de TTS y de compras, y facilidad para
> renderizar la misma escena cuatro veces (holograma). Unity sería excesivo para una app de cuentos 2D.

## Vista de capas

```
┌─────────────────────────────────────────────────────────┐
│ UI (Flutter): Biblioteca · Lector · Escena · Holograma  │
├─────────────────────────────────────────────────────────┤
│ Orquestador de cuento: texto ⇄ voz ⇄ escena (reloj común)│
├───────────────┬───────────────┬─────────────────────────┤
│ Motor de      │ Narrador      │ Motor de escenas        │
│ cuentos       │ (TTS/audio)   │ (animaciones)           │
├───────────────┴───────────────┴─────────────────────────┤
│ Repositorio de packs (descarga, verificación, caché)    │
├─────────────────────────────────────────────────────────┤
│ Almacenamiento local · Compras · Ajustes parentales     │
└─────────────────────────────────────────────────────────┘
```

## 1. Motor de cuentos («el caldero»)

Entrada: packs activos, **enseñanza**, banda de edad, duración, nivel de «susto» (0–3), semilla, personajes elegidos por el niño (opcional).
Salida: lista ordenada de **escenas** `{texto, directivas de escena, duración estimada}`.

Algoritmo (implementado en el prototipo `tools/prototype/caldero.py`):

1. **Enseñanza primero.** Se elige (o el adulto escoge) el valor: honestidad, generosidad, valentía…
2. **Esqueleto narrativo:** apertura → problema → ayuda → prueba → clímax → resolución → cierre (+ enseñanza). Un esqueleto define etapas y cuántos fragmentos admite cada una (esto da cuentos de 5, 10 o 15 min).
3. **Reparto:** héroe, ayudante, antagonista, lugares, filtrados por etiquetas y por edad.
4. **Selección con estado:** cada fragmento declara `requires` (qué debe haber ocurrido) y `adds` (qué cambia en la historia). Así el clímax solo puede ser el que resuelve el problema planteado → **coherencia causal**, no un collage aleatorio.
5. **Gramática:** las plantillas usan formas (`{hero.el}`, `{villain.del}`, `{hero.o}`…) que resuelven género y contracciones del español.
6. **Controles de calidad:** sin fragmentos repetidos, sin superar duración ni nivel de susto, semilla reproducible (el mismo cuento puede repetirse o compartirse con un código).

**Riesgo conocido (honesto):** la combinatoria por sí sola produce cuentos «de plantilla». Para evitarlo:
(a) muchos fragmentos por etapa con *estado*, (b) *arcos* escritos a mano que fijan la estructura de causalidad,
(c) variantes de frase por personaje (voz y rasgos) y (d) pruebas con familias reales desde la 0.1.

Casos del español a cubrir: género y número, contracciones (*del/al*), sustantivos femeninos con *el* (*el agua*) vía `article_override`, plurales («los tres cerditos»), y concordancia de participios (`{hero.o}`).

## 2. Narración

- **Escucha:** TTS lee escena por escena; los eventos de inicio/fin de frase marcan el reloj de la animación.
- **Lectura compartida:** texto grande en modo noche; el adulto avanza (toque/deslizar) y la escena se anima con ese ritmo.
- **Cuestión abierta (ADR-004):** TTS del sistema = gratis, offline, calidad variable según el teléfono. TTS neuronal
  offline (p. ej. modelos ONNX) = mejor calidad pero hay que **revisar la licencia de cada voz** y el peso de la app.
  Voz en la nube = mejor calidad pero coste recurrente y requiere conexión. Locución humana de frases fijas = no sirve con nombres variables.
  **Spike S-02** compara las tres con familias.

## 3. Motor de escenas (animación)

Cada fragmento lleva directivas de escena (ver ejemplo en el pack):

```json
{"bg": "place2", "actors": ["hero", "villain"], "mood": "tension"}
```

- `bg`: fondo del lugar (capas con parallax).
- `actors`: qué personajes aparecen; cada personaje tiene un set pequeño de *poses/acciones* (idle, caminar, saltar, sorprendido, feliz, esconderse).
- `mood`: iluminación, música y efectos (calma, tensión, esperanza, alegría, sueño).
- Sincronización: el orquestador emite «eventos de frase»; el motor de escenas los traduce a movimientos.
- Se prioriza **animación por capas con interpolaciones** (barata y con estilo propio) antes que animación esquelética completa.

## 4. Modo holograma (pirámide invertida)

Técnica: *Pepper's ghost* con pirámide truncada de plástico transparente (45° respecto a la pantalla) apoyada sobre el teléfono.

- La app renderiza **la misma escena 4 veces**, rotadas 0°/90°/180°/270° alrededor del centro, sobre **negro puro** (en OLED el negro no emite luz, lo que mejora el efecto).
- Los colores y el contraste deben diseñarse para este modo: personajes con siluetas claras y luminosas, fondos oscuros.
- **Calibración:** tamaño de la base de la pirámide (cm) → escala y separación de las 4 vistas; test con rejilla.
- Controles para adultos: brillo máximo, evitar apagado de pantalla (`wakelock`), bloqueo de rotación, bloqueo de toques accidentales (mantener pulsado para salir).
- **Plantilla imprimible** (PDF) para recortar la pirámide de acetato o de una caja de CD.
- **Spike S-03:** probar con 3 teléfonos y 2 tamaños de pirámide antes de comprometer el diseño artístico.
- Limitación realista: el efecto funciona mejor con poca luz y escenas simples; en pantallas pequeñas la imagen será pequeña.
  Hay que comunicarlo bien para no generar falsas expectativas en la ficha de tienda.

## 5. Packs y datos

```
pack/
  manifest.json         # id, versión, hash, tamaño, requisitos, precio-id
  pack.json             # entidades y fragmentos
  assets/{img,audio,anim}/
```

- Pack gratuito **embebido** en la app; los demás se descargan, se verifican (hash/firma) y se cachean.
- Compatibilidad: versión de esquema en cada pack; la app ignora packs con un esquema que no entiende.
- Actualizaciones de contenido sin nueva versión de app.

## 6. Calidad y CI

- Pruebas unitarias del motor y de la gramática; **pruebas de propiedades** (para 1000 semillas ningún cuento falla ni repite fragmento).
- **Validador de packs** (equivalente al `--lint` del prototipo): formas inexistentes, frases mal terminadas, artículos en mayúscula a mitad de frase, cobertura de cada enseñanza.
- Pruebas de widgets y capturas de referencia (golden) del lector y del holograma.
- GitHub Actions: `lint → test → validar packs → build`.

## 7. Seguridad y privacidad (resumen)

Sin cuentas ni datos personales de menores en el MVP; ajustes parentales detrás de una puerta para adultos;
analítica mínima y agregada (ver [04](04-contenido-y-derechos.md)).
