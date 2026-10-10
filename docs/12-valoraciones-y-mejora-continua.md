# 12 · Valoraciones y mejora continua de los cuentos

> **Meta:** que desde el primer día cada cuento leído nos diga, con una sola pulsación, cuánto gustó; y que con esas
> notas los cuentos se vuelvan más coherentes con el tiempo. **Restricción:** la valoración es el único dato que se recoge
> (con un motivo opcional cuando es baja), y no identifica a nadie.
>
> **Decisiones tomadas (D1–D4):** activada por defecto con total transparencia y borrado al desactivar · motivo opcional con 5 botones
> si la nota es ≤ 3 · **no** se registra el abandono de cuentos · se mantiene el recordatorio de la mañana. Ver [§9](#9-decisiones).

## 1. La idea en una frase

Cada nota (1 a 5) viaja pegada a la **receta** del cuento (qué enseñanza, qué personajes, qué fragmentos). Con miles de
notas, la estadística separa *qué pieza* hace peor un cuento. Un humano revisa lo marcado, y el resultado vuelve al pack como
una versión nueva.

```
Cuento ──leído──▶ Ficha de 5 caritas ──▶ Cola local (sin red OK) ──▶ POST /v1/feedback ──▶ Base de datos
                          │                                                                        │
                   «Ahora no» / mañana                                                    Análisis nocturno (ridge)
                                                                                                   │
Pack versión N+1 ◀── revisión humana ◀── Panel «Calidad» (fragmentos y transiciones marcados) ◀────┘
 (textos corregidos / pesos nuevos)
```

## 2. Por qué una nota sola no sirve, y qué se añade

Una nota de «3» sin saber *qué cuento fue* no permite mejorar nada. Por eso la nota viaja con la **receta**:
identificadores (no texto, no nombres) del pack y su versión, la semilla, la enseñanza, el reparto y los fragmentos (desde el esquema 2, `premisa.escena.variante`: la premisa se lee en el primer id)
elegidos. Es la misma clase de dato («un cuento valorado»); no hay ningún otro dato sobre la familia. Como el motor es
determinista, con el pack y la semilla se reconstruye el cuento exacto; además la receta es autodescriptiva (lleva los ids), así
que sigue sirviendo aunque el algoritmo cambie.

## 3. La experiencia (probada en pantalla)

- **Al final del cuento**, después de la enseñanza: «¿Cuánto les gustó este cuento?» con **cinco caritas grandes** (Nada, Poco,
  Regular, Bien, ¡Me encantó!). Las entiende un niño y las pulsa un adulto. Un toque y listo.
- **Si la nota es 1, 2 o 3** aparece un segundo paso, opcional y sin texto libre: «¿Qué pasó? Si quieren, cuéntennos» con cinco botones que
  se pueden combinar: *No tuvo sentido · Se repitió · Muy largo o muy corto · Dio miedo · No me gustó la enseñanza*. «Omitir» (o «Listo» si
  eligieron alguno). **La nota ya está guardada al tocar la carita**: si se van a mitad, se envía igual, sin motivo. Con 4 o 5 no se pregunta nada más.
- **Tranquila, es de noche:** colores suaves, sin sonidos ni animaciones, «¡Gracias! Buenas noches» con una luna. Una salida
  clara: **«Ahora no»**. Nunca se pregunta antes de llegar al final y nunca se insiste.
- **La mañana siguiente:** si leyeron hasta el final y no respondieron, al abrir la app aparece una tarjeta «¿Cuánto les gustó
  “Honestidad · Nilo”?». Un adulto con sueño a las 11 de la noche responde menos y peor que por la mañana. Caduca a los 3 días y
  guarda como máximo 3.
- **Sin conexión no pasa nada:** la nota se guarda en el teléfono (hasta 200) y se envía cuando haya red. Reintentos con espera
  creciente (1 min → 6 h). Nunca bloquea la lectura.
- **Transparencia total** (ajustes para adultos, detrás de una pregunta de multiplicar): interruptor «Ayudar a mejorar los cuentos»,
  lista de qué se envía y qué no, y **un ejemplo exacto** del dato. Al desactivarlo se borra lo que esperaba enviarse y deja de
  preguntar.
- Accesible: cada carita es un botón con etiqueta para lectores de pantalla («Valorar con 4 de 5: Bien») y objetivo táctil amplio.

## 4. Qué viaja (y qué no)

Contrato completo: [`docs/api/feedback.openapi.yaml`](api/feedback.openapi.yaml). Ejemplos reales: [`rating-event.json`](api/examples/rating-event.json) y [`rating-event-with-reasons.json`](api/examples/rating-event-with-reasons.json).

| Campo | Para qué | Riesgo |
|---|---|---|
| `id` (UUID aleatorio por valoración) | No duplicar si la app reintenta | Ninguno: no identifica al usuario ni se repite |
| `rating` 1–5 | El dato | — |
| `day` (solo el día, UTC) | Ver tendencias; nunca la hora | Mínimo |
| `app` (versión) | Detectar errores de una versión | Mínimo |
| `recipe.packId`, `packVersion`, `engine` | Saber qué contenido y qué algoritmo | Ninguno |
| `reasons` (opcional, solo con nota ≤ 3) | Separar «no tuvo sentido» de «dio miedo» o «largo» | Uno o más de 5 códigos fijos; **nunca texto escrito** |
| `recipe.seed`, `value`, `cast`, `fragments` | Qué cuento fue, para atribuir la nota | Códigos, sin texto ni nombres |

**No se envía, ni se guarda:** identificador de instalación, de dispositivo ni de usuario; IP (solo se usa en memoria para limitar
envíos); hora exacta; nombres, edades, voz, ubicación; el texto del cuento. **A propósito no hay identificador de instalación en
las valoraciones** (aunque el catálogo sí use uno anónimo para otra cosa): así el servidor no puede agrupar las notas de una misma
familia. El precio es no poder corregir el sesgo de «quien siempre pone 5»; se compensa con volumen y un método robusto.

**El contrato se prueba en ambos lados:** una prueba de Dart exige que el evento real de la app sea idéntico (campos, nombres,
tipos, orden) al ejemplo; una prueba de Python exige que el ejemplo cumpla el esquema y que **cualquier campo extra
(usuario, dispositivo, hora, texto, nombre) sea rechazado**.

## 5. ¿Una nota basta para encontrar lo malo? Evidencia por simulación

No lo di por hecho: `tools/feedback/simulate.py` inventa un pack del tamaño del real (98 fragmentos, 6 enseñanzas, 576
transiciones posibles), **planta** 6 fragmentos malos (−1,0 puntos) y 3 transiciones incoherentes (−1,2), genera valoraciones
ruidosas (σ = 0,9: humor del adulto, sueño, voz, etc.), y comprueba si el análisis los encuentra.

| Valoraciones | Veces que sale cada fragmento | Promedio simple (recall@6) | **Regresión (recall@6)** | Marcados bien (de 6) | Falsos marcados | Transiciones (recall@3) |
|---:|---:|---:|---:|---:|---:|---:|
| 250 | 18 | 56 % | 79 % | 3,0 | 0,1 | 19 % |
| 500 | 36 | 66 % | 89 % | 4,1 | 0,1 | 31 % |
| **1 000** | 71 | 81 % | **98 %** | 5,2 | 0,1 | 53 % |
| 2 000 | 143 | 81 % | 97 % | 5,3 | 0,0 | 85 % |
| 5 000 | 357 | 83 % | 98 % | 5,3 | 0,1 | 96 % |
| 10 000 | 714 | 88 % | 100 % | 5,5 | 0,0 | 100 % |

Con **más ruido** (adultos muy cansados, σ = 1,7, el doble) a 5 000 valoraciones aún se encuentra el **94 %** de los fragmentos
malos y el 62 % de las transiciones.

**Conclusiones que cambian el diseño:**
1. **Sí funciona**, pero para defectos claros. Con ~1 000 valoraciones ya se encuentran casi todos los fragmentos malos
   (−1 punto) con ~0,1 falsas alarmas. Las **transiciones incoherentes** (la causa típica de «no tuvo sentido») piden 2 000–5 000.
2. **El promedio simple no basta** (se estanca en ~83 %): una enseñanza menos querida arrastra a todos sus fragmentos. Hay que usar
   la regresión que estima todos los efectos a la vez (`analyze.py`; una prueba exige que no culpe a los fragmentos de una enseñanza
   impopular).
3. **Hace falta variedad para aprender:** si una etapa tiene una sola opción no hay con qué comparar. **El pack de demostración
   actual casi no tiene alternativas** (muchas etapas con 1 opción). El pack real necesita **≥ 3 variantes por etapa y enseñanza**
   (se incluirá en la guía editorial, historia E3-04).
4. **Tiempo hasta tener datos** (suponiendo que el 30 % valora y 3 cuentos por familia a la semana): 200 familias activas → 11
   semanas para 2 000 valoraciones; 1 000 familias → ~2 semanas; si solo valora el 15 %, ~4 semanas. Con pocas familias el aprendizaje
   será lento: **cuanto antes salga la app a un grupo de prueba, antes empieza a servir esto.**

**¿Cuánto ayudan los motivos?** Se simularon 3 fragmentos malos por *incoherencia* y 3 por *susto*, igual de malos por nota (la
nota sola no distingue unos de otros). Con nota ≤ 3 contesta el motivo la mitad de las veces y acierta la causa el 80 %
(`python3 tools/feedback/simulate.py --reasons`):

| Valoraciones | Malos detectados (de 6) | Causa bien identificada **con motivos** | Sin motivos |
|---:|---:|---:|---:|
| 500 | 5,4 | **91 %** | 50 % (azar) |
| 1 000 | 5,8 | 98 % | 50 % |
| 2 000 | 6,0 | 100 % | 50 % |

Si responde mucho menos gente al motivo (solo el **10 %**), a 1 000 / 2 000 / 5 000 valoraciones la causa sigue bien identificada el
**81 % / 90 % / 94 %** de las veces. **Los motivos son lo que convierte «este fragmento baja la nota» en «este fragmento no tiene sentido»**,
que es justo la mejora de coherencia que se busca.

*Límites de la simulación:* los efectos y el ruido son supuestos; los defectos reales pueden ser más sutiles (−0,3) y necesitar
mucho más volumen. La app real tendrá además sesgo de respuesta (quien valora quizá no es representativo). Se recalibra con datos reales.

## 6. Cómo se usa lo aprendido (de menos a más automático)

1. **Informe de calidad** (`tools/feedback/analyze.py`, luego en el panel): lista de fragmentos y transiciones **a revisar**, no a
   borrar, y **por qué se quejan** (los fragmentos que más provocan «No tuvo sentido» o «Se repitió» son la prioridad de coherencia; los de «Dio miedo»,
   de edad/susto). Se marca solo con efecto < −0,3 puntos, z < −2 y ≥ 20 apariciones. *Los efectos aparecen encogidos* (por el techo de la
   escala y la prudencia de la regresión: un defecto de −1,0 sale como ≈ −0,45): **el ranking es fiable; la magnitud, subestimada.**
2. **Revisión humana:** un editor lee el fragmento en contexto y lo reescribe, lo desactiva o lo deja. Se publica una **versión nueva
   del pack**.
3. **Pesos** (ya soportados por el motor: campo `weight` por fragmento, 0 = desactivado): el panel puede proponer bajar el peso de
   lo malo y subir el de lo bueno. Reglas de seguridad: **nunca bajar a 0 automáticamente** (peso mínimo 0,2 para seguir midiendo),
   cambios acotados (±50 % por versión), siempre con aprobación humana, y los pesos van **dentro del pack**, así que cada cuento sigue
   siendo reproducible.
4. **Más adelante:** selección adaptativa (muestreo de Thompson) con una exploración mínima fija. Solo si hay mucho volumen.

*Cuando se edita el texto de un fragmento, sus estadísticas anteriores dejan de valer:* el análisis es por versión del pack y solo
se combina entre versiones para fragmentos cuyo texto no cambió.

## 7. Sesgos y límites (hay que saberlos)

- **Gustar ≠ coherencia.** Una nota baja puede ser por miedo, voz, largo o cansancio. El método asume que, **en promedio**, un
  fragmento incoherente baja la nota; no demuestra *por qué* bajó. Por eso existe el motivo opcional (§3).
- **Correlación, no causa.** La aleatorización del motor ayuda (los fragmentos se eligen al azar entre alternativas), pero no es un
  experimento controlado.
- **El motivo es opcional:** solo contesta una parte; el análisis cuenta las no respuestas como «sin queja», así que **subestima** el número de quejas pero conserva el ranking.
- **Quién responde.** Posible sesgo (más respuestas de familias contentas). El «recordatorio de la mañana» ayuda a responder más.
- **Techo de la escala.** La mayoría dará 4–5; la señal está en las diferencias pequeñas.
- **Muchas comparaciones.** Con cientos de fragmentos, algunos salen «malos» por azar: por eso el umbral doble (efecto y z) y la
  revisión humana. Informar siempre con el número de apariciones.
- **Niño vs. adulto.** Responde un adulto «por» el niño; refleja su percepción.
- **Manipulación.** Un actor malicioso podría enviar notas falsas (§8).

## 8. Seguridad y abuso (cuando exista el backend)

- Validar contra el esquema **y** contra el catálogo publicado: `packId`/`packVersion`/`fragments`/`value`/`cast` deben existir en esa
  versión (así no se pueden inventar fragmentos); `day` ni futuro ni de más de 60 días.
- Idempotencia por `id` (los reintentos no duplican). Límite de tamaño (50 eventos/64 KB) y **límite de ritmo por IP en memoria**
  (la IP no se guarda).
- Estadística robusta: ignorar ráfagas anómalas (muchos eventos con la misma semilla o el mismo día) y poder excluir un lote.
- Más adelante, atestación de la app (Play Integrity / App Attest) para que solo apps genuinas envíen.
- La base de datos **solo admite inserciones** desde la API pública; las lecturas son del panel (rol autenticado).

```sql
create table story_ratings (
  event_id     uuid primary key,                       -- idempotencia
  pack_id      text not null, pack_version text not null, engine text not null,
  seed         bigint not null, value_id text not null,
  cast_ids     jsonb not null, fragment_ids text[] not null,
  rating       smallint not null check (rating between 1 and 5),
  reasons      text[] check (reasons <@ array['no_sense','repeated','length','scary','moral']
                         and (reasons is null or rating <= 3)),   -- opcional, solo con nota baja
  rated_on     date not null,                          -- solo el día
  app_version  text not null,
  received_on  date not null default current_date      -- sin hora de recepción
);
create index on story_ratings (pack_id, pack_version);
-- Sin columnas de usuario, instalación, IP ni hora. RLS: insertar solo vía función de validación.
```

## 9. Decisiones

| # | Decisión | Resultado |
|---|---|---|
| D1 | Valoración **activada por defecto**, con transparencia total y borrado al desactivar | ✅ **Decidido: sí.** Ajustes para adultos: interruptor, qué se envía y qué no, ejemplos exactos; al desactivar se borra lo pendiente. *Pendiente de buena práctica:* revisión legal antes de 1.0 (COPPA, RGPD, reglas de tiendas) |
| D2 | **Motivo opcional** con nota ≤ 3, cinco botones | ✅ **Decidido: sí.** No tuvo sentido · Se repitió · Muy largo o muy corto · Dio miedo · No me gustó la enseñanza. Implementado y probado |
| D3 | Registrar si **abandonan** un cuento a medias | ✅ **Decidido: no por ahora** (se respeta «solo la valoración»). *Nota:* la respuesta original mezclaba un «sí» con la recomendación de no hacerlo; se aplicó la opción conservadora. Si se quiere lo contrario, se añade más adelante |
| D4 | **Recordatorio de la mañana** | ✅ **Decidido: sí.** Implementado |

## 10. Estado

| Pieza | Estado |
|---|---|
| Receta del cuento, versión del motor y pesos por fragmento en el motor | ✅ hecho y probado (33 pruebas del motor) |
| Ficha de 5 caritas, «Ahora no», recordatorio de la mañana | ✅ verificado en pantalla y con pruebas de widget |
| Segundo paso de **motivos** (nota ≤ 3): 5 botones combinables, omitible, la nota ya está guardada | ✅ 63 pruebas de la app (flujos, límites 3/4, salir a mitad, tarjeta de la mañana, desactivado) |
| Cola local con tope, reintentos con retroceso, envío por lotes, idempotencia; **sin pérdidas ni pisadas** si se valora o se añade un motivo durante un envío | ✅ 32 pruebas de lógica |
| Ajustes para adultos con transparencia, interruptor y borrado | ✅ |
| Contrato OpenAPI + pruebas en ambos lados (app y esquema) | ✅ |
| Análisis estadístico (nota y motivos) + simulación | ✅ 11 pruebas con eventos en el formato real |
| **Servidor que recibe `/v1/feedback`** | ☐ no existe aún (backend, versión 0.2): hasta entonces las valoraciones **esperan en el teléfono** y se enviarán solas |
| Panel «Calidad» y propuesta de pesos | ☐ versión 0.2–0.3 del panel |
| Probado en Android/iOS reales | ☐ pendiente (tu medición) |

**Cómo probarlo hoy:** `flutter run`, crea un cuento, baja hasta el final y toca una carita. En Ajustes (engranaje, pregunta de
adultos) verás «Esperando para enviarse: 1». Para apuntar a un servidor de pruebas:
`flutter run --dart-define=CALDERO_API=https://tu-servidor` (la app añade `/v1/feedback`).

## 11. Plan

| Cuándo | Qué |
|---|---|
| ✅ Ahora (S2 adelantado) | Todo lo de arriba menos el servidor, **incluido el motivo opcional** |
| S4–S5 | `POST /v1/feedback` real con las validaciones de §8 (incluida «`reasons` solo con nota ≤ 3») y la tabla de §8 |
| S6 | Panel «Calidad»: tabla de fragmentos/transiciones marcados, ejemplos de cuentos peor valorados (reconstruidos por receta) |
| Con ≥ 1 000 valoraciones | Primera ronda de revisión editorial y propuesta de pesos |
| Packs nuevos | Diseñarlos con ≥ 3 variantes por etapa y enseñanza para que se pueda aprender |
