# 24 · Prueba editorial con lectores de verdad (cuentos pequeños)

Hasta ahora los cuentos de 2–3 y 4–5 años los han revisado **una persona** (con las ilustraciones) y el **validador**, y las vueltas de
[14](14-rubrica-editorial.md) fueron revisiones hechas por lectores simulados (modelos de IA con la rúbrica). Sirven para cazar
errores de coherencia, pero **no sustituyen a un niño de tres años y a un adulto que lee en voz alta**: lo que suena raro en la boca,
lo que no se entiende o lo que asusta solo se descubre así. Esta es la prueba mínima para hacerlo **antes de la prueba cerrada**.

> Esto no es un estudio. Con 5–10 familias se descubren frases torpes, sustos inesperados y cuentos que no se entienden; no se
> demuestra que un cuento «enseñe» ni que mejore el sueño.

## 1. Quién

| Grupo | Cuántos | Qué hace |
|---|---|---|
| **Adultos que leen en voz alta** (madres, padres, educadoras de infantil, cuentacuentos) | 5–8 | Leen 3–4 cuentos cada uno **a un niño** de la edad del cuento y rellenan la hoja. |
| **Niños de 2–3 y de 4–5 años** | ≥ 5 por franja | Escuchan; el adulto apunta lo que hacen y lo que dicen. |
| *(opcional)* **Lectura en frío**, sin niño | 3 | Leen los cuentos en silencio y marcan frases torpes. Más rápido, menos fiable. |

Que no los conozca el equipo y que no hayan visto la app. Un cuento por noche y niño como máximo (no es un examen).

## 2. Material

```bash
export PATH=/opt/flutter-sdk/flutter/bin:$PATH
cd packages/caldero_engine
dart run bin/reader_sheets.dart ../../content/packs/medieval/pack.json /tmp/hojas 2-3,4-5 2
```

Escribe una hoja HTML por cuento (se imprime o se lee en el móvil; sin ilustraciones ni directivas, solo lo que oirá el niño), un
`index.html` y `respuestas.csv` con las columnas de la hoja. Último argumento = cuentos por enseñanza y edad (2 = dos premisas distintas
de cada enseñanza). Reparte las hojas de forma que **cada cuento lo lean al menos 2 adultos distintos**.

## 3. Cómo se lee

1. Leer en voz alta, **despacio y una sola vez**, sin explicar la enseñanza ni corregir al niño.
2. Anotar mientras se lee: dónde se distrajo, qué repitió, qué preguntó, si se rio o se asustó.
3. Al terminar, preguntar «¿de qué iba el cuento?» y apuntar **sus palabras**, sin ayudar.
4. Rellenar la hoja (seis preguntas, cinco minutos) y, si se durmió, **no** despertarlo para preguntar.

## 4. Qué se mira y qué se hace con ello

| Señal | Umbral | Decisión |
|---|---|---|
| «¿Se entiende?» (1–5) | media ≥ 4 en cada cuento | Si baja de 4, se reescribe la escena que los lectores señalen. |
| Frases raras o difíciles de leer | cualquiera que **dos** lectores marquen | Se reescribe tal cual la marquen (y se añade al validador si es un patrón). |
| Susto en 2–3 | **un solo** niño asustado | Se revisa la escena (vocabulario, imagen, sonido) aunque pase el validador. |
| «¿De qué iba?» en 4–5 | ≥ 2 de cada 3 niños nombran la idea (con sus palabras) | Si no, la enseñanza no se *muestra*: se revisa el clímax y el cierre, no se explica más. |
| Edad | ≥ 70 % «justo» | Si domina «muy fácil» o «muy difícil», se mueve el cuento de franja. |
| Atención / dormirse | informativo | Sirve para comparar cuentos entre sí, no para puntuar. |

Los cambios se hacen en `content/packs/medieval/pack.json` (subiendo la versión del pack), se valida y se **registra una nueva vuelta
en [14](14-rubrica-editorial.md)** con la etiqueta «lectores reales» (para no mezclarla con las de lectores simulados).

## 5. Ética y privacidad (mínimos)

* Participan adultos que lo han aceptado; no se recoge **nombre, foto, voz ni vídeo** del niño. En las hojas, solo la edad.
* Las respuestas son anónimas (un código por lector) y se guardan en un archivo local, no en la app. Coherente con la política de
  [22](22-privacidad-y-tiendas.md): la app no envía nada de esto.
* Nadie debe oír un cuento si el niño no quiere: si se asusta o se aburre, se para.
