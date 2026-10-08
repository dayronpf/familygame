# 05 · Modelo freemium

## Principio

El pack gratuito debe ser **completo y entrañable**: que una familia pueda tener un ritual semanal sin pagar.
Lo premium añade **variedad y riqueza**, nunca elimina seguridad ni pone presión sobre el niño.

## Estructura propuesta

| Nivel | Contenido | Precio (a validar) |
|---|---|---|
| **Gratis** — «Bosque Encantado» | ~25 personajes, ~15 lugares, 6 enseñanzas, narración básica, animaciones básicas, modo holograma básico | $0 |
| **Packs temáticos** | Mar, Espacio, Ciudad, Fantasía, Granja… (≈ 20–30 personajes, 10–15 lugares, 3–4 enseñanzas nuevas, fondos y sonidos propios) | Compra única por pack |
| **Suscripción «Familia»** (opcional, más adelante) | Todos los packs actuales y futuros + voces premium + cuentos con el nombre del niño | Mensual/anual |
| **Packs de temporada** | Navidad, Día de la Madre, Halloween suave… | Compra única, edición limitada de arte |

> Los precios se deciden con datos (pruebas de precio por región). Empezar por **compra única por pack** es
> más sencillo de explicar a padres y encaja con el «tren de contenido».

## Qué es premium y qué no

- ✅ Premium: más personajes/lugares/enseñanzas, escenas animadas más ricas, voces de mayor calidad, sonidos ambientales, nombre personalizado.
- ❌ Nunca de pago: seguridad, modo noche, temporizador de sueño, plantilla del holograma básica, accesibilidad.
- ❌ Nunca: anuncios, presión para comprar, cuentas atrás, mecánicas de «ludopatía» ni mensajes dirigidos al niño para comprar.

## Reglas de tiendas a respetar

- Compras detrás de **puerta parental**; botón «Restaurar compras».
- Sin enlaces externos ni redes sociales accesibles al niño sin puerta.
- Suscripciones: describir claramente precio, renovación y cancelación.
- Comisiones de tienda (varían; programas para pequeños desarrolladores): modelar el margen con el porcentaje vigente.

## Métricas

Conversión de gratis a premium, packs por familia, retención por pack, reembolsos, tiempo hasta primera compra,
**y sobre todo** noches con cuento completado (North Star).

## Entrega técnica

Manifiesto de packs con `product_id`; verificación de recibo en cliente (MVP) y, más adelante, en servidor;
descarga bajo demanda, caché y borrado manual para liberar espacio.
