# 01 · Metodología ágil

Se propone **Scrum ligero + tablero Kanban**, pensado para un equipo pequeño (1–4 personas) que además
produce mucho contenido. Se puede reducir aún más si trabajas solo/a.

## Roles

| Rol | Quién | Responsabilidad |
|---|---|---|
| Product Owner | Tú | Dueño de la visión y del orden del backlog; decide qué entra y qué no |
| Equipo de desarrollo | Tú / Claude / colaboradores | Construye el incremento |
| Facilitador (Scrum Master) | Rotativo o Claude | Cuida el proceso, quita bloqueos |

## Cadencia

- **Sprint de 2 semanas** (1 semana si dedicas pocas horas; ajustar cuando sea necesario).
- **Planificación** (1 h): objetivo del sprint (una frase) + historias.
- **Seguimiento diario asíncrono** (5 min, por escrito): qué hice, qué haré, qué me bloquea.
- **Revisión** (30 min): se *usa* el incremento en un teléfono real, idealmente con un niño/a o un adulto cercano.
- **Retrospectiva** (30 min): una cosa que seguir, una que parar, una que probar.
- **Refinamiento del backlog** (1 h a mitad de sprint): dejar listas las historias del siguiente sprint.

## Cómo no perder la visión

1. **Objetivo de producto** (Product Goal) fijo, visible en el README: «familias completan cuentos cada noche».
2. **Esqueleto andante (walking skeleton):** primero una versión *fea pero completa* de punta a punta
   (generar → narrar → animar), y solo después se mejora cada parte. Evita meses de motor sin ver nada.
3. **Spikes tempranos** para los riesgos grandes (voz, animación, holograma). Un spike dura máx. 3 días y termina
   en una decisión escrita (ADR).
4. **Hoja de ruta Ahora / Siguiente / Después** (ver [02-roadmap.md](02-roadmap.md)); solo lo de «Ahora» se detalla.
5. **Cada release tiene un criterio de salida medible**, no una fecha.
6. **Dos carriles** con límite de trabajo en curso (WIP): *Ingeniería* y *Contenido*. El contenido es tan
   importante como el código; tiene su propio flujo de calidad.

## Tablero (Kanban dentro del sprint)

`Backlog → Listo → En curso (WIP ≤ 3) → En revisión → Hecho`

## Definición de «Listo» (Definition of Ready)

Una historia puede entrar a un sprint si:
- Tiene formato *«Como [quién], quiero [qué] para [por qué]»*.
- Tiene criterios de aceptación verificables.
- Está estimada (tallas S / M / L; si es L, se parte).
- No depende de algo no resuelto (licencia, asset, decisión técnica).

## Definición de «Terminado» (Definition of Done)

- Compila y pasa lint y pruebas automáticas en CI.
- Probado en **un Android y un iOS** reales (o emulador mientras no haya dispositivo).
- Para contenido: pasa el **validador de packs** y la **revisión editorial** (ver [04](04-contenido-y-derechos.md)).
- Para assets: registrado en el **libro de licencias** con fuente y prueba de licencia.
- Sin dependencias de rastreo/anuncios añadidas.
- Documentación actualizada (si cambia el formato de packs o una decisión).

## Priorización

Valor para la familia × reducción de riesgo ÷ esfuerzo. Etiquetas MoSCoW por release
(*Must / Should / Could / Won't*). Lo que no está en «Must» del release actual no se empieza.

## Herramientas sugeridas

- **Backlog y tablero:** GitHub Issues + Projects (mismo lugar que el código). Este repo guarda el backlog
  inicial en [07-backlog.md](07-backlog.md) para migrarlo cuando quieras.
- **CI:** GitHub Actions (lint, pruebas, validador de packs, build de Android/iOS).
- **Releases:** ramas cortas → `main` siempre desplegable → pistas internas de Play Console y TestFlight.
- **Decisiones:** registros ADR en [08-decisiones-y-riesgos.md](08-decisiones-y-riesgos.md).
