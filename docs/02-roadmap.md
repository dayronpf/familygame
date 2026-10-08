# 02 · Hoja de ruta

Sprints de 2 semanas. Las duraciones son **indicativas** (suponen un equipo pequeño a tiempo parcial);
lo que manda son los **criterios de salida** de cada release.

## Vista general

```
AHORA                      SIGUIENTE                         DESPUÉS
S0  S1-S3         S4-S5     S6-S8        S9-S10      S11-S13       Post-1.0
│   │             │         │            │           │             │
Fund. 0.1 Chispa  0.2 Voz   0.3 Vida     0.4 Holo    1.0 Lanzam.   Packs, idiomas,
      (motor+texto)(narración)(animación)(pirámide)  (freemium)    personalización
```

## Releases

### Sprint 0 · Fundamentos (en curso)
- Visión, plan, arquitectura, reglas de contenido y derechos. ✅
- Prototipo del caldero (spike S-01) y modelo de contenido. ✅
- **Falta:** elegir nombre y comprobar marca; crear proyecto Flutter y CI; cuentas de desarrollador.

### 0.1 «Chispa» — el caldero cuenta (S1–S3) · *alfa interna*
**Objetivo:** que un cuento generado *se sienta bien* leído por un adulto.
- Motor de cuentos en Dart (portado del prototipo) con pruebas.
- Validador de packs en CI.
- Pack semilla: ~25 personajes, ~15 lugares, ~120 fragmentos, 6 enseñanzas.
- App mínima: elegir enseñanza → ver cuento en texto grande, modo noche.
- **Salida:** 10 familias/amistades leen ≥ 3 cuentos cada una; ≥ 70 % dice «me contaría otro» y no se detectan errores gramaticales graves.

### 0.2 «Voz» — narración (S4–S5)
- Spike y decisión de voz (sistema vs. neuronal offline vs. nube) — ver ADR-004.
- Modo **Escucha** (narración automática) y modo **Lectura compartida** (texto + pasar página).
- Temporizador de sueño con bajada gradual de volumen y brillo; biblioteca de favoritos/historial (local).
- **Salida:** un cuento de 8 min se narra sin cortes en 2 Android y 2 iOS; la voz es aceptable según 5 familias.

### 0.3 «Vida» — animación (S6–S8)
- Motor de escenas: cada fragmento trae directivas de escena (`bg`, `actors`, `mood`) → animaciones sincronizadas con la narración.
- Kit visual de partida: 1 estilo artístico, ~10 personajes animados, ~6 fondos, ~20 efectos de sonido/ambiente.
- Sincronización con eventos de la voz (por frase) y con el avance manual de página.
- **Salida:** 60 FPS en un teléfono de gama media; las escenas de un cuento completo se ven coherentes con el texto.

### 0.4 «Holograma» — pirámide (S9–S10)
- Spike previo (en S6) con 3 teléfonos distintos y una pirámide de prueba.
- Modo holograma: 4 vistas giradas sobre fondo negro, calibración de tamaño, brillo y bloqueo de apagado de pantalla.
- Plantilla imprimible (PDF) y guía de montaje con materiales caseros (acetato / caja de CD).
- **Salida:** 5 familias montan la pirámide en menos de 10 min y el efecto se distingue claramente a oscuras.

### 1.0 «Lanzamiento» — freemium (S11–S13)
- Pack gratuito «Bosque Encantado» + infraestructura de packs descargables con manifiesto firmado.
- Compras integradas, restauración, **control parental** (puerta para adultos), política de privacidad.
- Prueba cerrada en tiendas (Play exige un periodo mínimo de pruebas para cuentas nuevas personales; verificar requisitos vigentes), ficha de tienda, capturas, categoría «Familias/Niños».
- **Salida:** revisión de tiendas aprobada; 0 fallos bloqueantes en 2 semanas de beta; checklist legal completo.

### Post-1.0 (cadencia «tren de contenido»)
- Un pack premium cada 4–6 semanas (tema + 3–4 enseñanzas nuevas + personajes y fondos nuevos).
- Cuentos con el nombre del niño; segundo idioma (inglés); modo cuna (solo audio, pantalla apagada).
- Mejoras del holograma (efectos, tamaños de pirámide), sonidos ambientales, logros suaves (sin presión).
- Posible capa de IA *solo* como ayuda para autores en el flujo de contenido, nunca generación libre sin revisión.

## Dependencias críticas

```
Modelo de contenido ─▶ Motor ─▶ Narración ─▶ Animación ─▶ Holograma
                          └──▶ Packs/compras ──────────────────────▶ 1.0
Contenido (carril paralelo) alimenta a todos los pasos
```

## Cómo se mide el avance

- Un release termina cuando se cumple su **criterio de salida**, aunque tarde un sprint más.
- Cada revisión de sprint incluye una **demo en dispositivo real** y una nota de aprendizaje.
- Si en un sprint aparece algo que contradice la visión, se detiene y se revisa el roadmap (no se parcha).
