# 04 · Contenido, derechos de autor y privacidad infantil

> Esto es una guía de ingeniería y producto, **no asesoría legal**. Antes del lanzamiento 1.0, revisa estas
> políticas con un abogado de propiedad intelectual de tu país (y registro de marca).

## 1. Qué protege (y qué no) el derecho de autor

- **No** se protegen las *ideas*, estructuras ni arquetipos: «el héroe, el ayudante sabio, el villano tramposo,
  la prueba, el regreso» son patrimonio común (Propp, Campbell). Nuestro motor se basa en esas estructuras.
- **Sí** se protegen las *expresiones concretas*: textos, ilustraciones, diseños de personajes, música, grabaciones,
  y los **nombres y diseños de marca** (Disney, Pixar, etc.) incluso si el cuento original es de dominio público.
- Las **obras en dominio público** (Grimm, Andersen, Perrault…) pueden reutilizarse, pero **no sus adaptaciones modernas**
  (películas, ilustraciones, traducciones recientes). El dominio público varía por país y por edición.

## 2. Reglas de contenido (política del proyecto)

1. **Todo texto se escribe de cero** por humanos del equipo. Nada de copiar ni «parafrasear de cerca» cuentos existentes.
2. **Personajes = arquetipos originales** (*la tortuga valiente*, *el cuervo tramposo*) con nombres propios inventados.
   No usar nombres/diseños de personajes de marcas ni de obras recientes. Antes de fijar un nombre propio, buscarlo en las bases de marcas
   (OEPM/EUIPO, USPTO, el registro de tu país) y en tiendas de apps.
3. **Evitar mimetizar estilos reconocibles** de estudios/ilustradores. Definir una guía de estilo propia.
4. **Uso de IA en el flujo de trabajo** (si se usa): solo como borrador; revisión y reescritura humana; guardar registro
   del proceso. La protección legal de material generado por IA es incierta y varía por país, así que no debe ser la
   base del valor. Para ilustración, **preferir artistas con contrato de cesión** de derechos.
5. **Revisión editorial** de cada fragmento: tono, edad, valores, sin estereotipos dañinos, sin violencia gráfica,
   nivel de «susto» etiquetado (0–3), vocabulario acorde a la banda de edad.
6. **Validador automático** (CI): formato, gramática de plantillas, cobertura, longitud, palabras vetadas.

## 3. Libro de licencias de assets (`ASSETS_LICENSES.md`, a crear en S1)

Cada imagen, sonido, música, fuente o animación se registra con: **id, autor, fuente/URL, licencia, fecha, prueba (captura o contrato)**.

| Origen | ¿Usable? | Notas |
|---|---|---|
| Creado por el equipo | Sí | Guardar fuentes editables |
| Encargo a artistas | Sí | Contrato de cesión/licencia por escrito, con uso comercial y en apps |
| **CC0 / dominio público** (p. ej. Kenney, OpenGameArt-CC0, Freesound-CC0) | Sí | Verificar que el *autor original* publica bajo CC0 |
| CC-BY | Sí, con atribución | Pantalla de créditos obligatoria |
| CC-BY-NC, CC-BY-SA, «gratis para uso personal» | **No** | NC prohíbe uso comercial; SA contagia la licencia |
| Fuentes de Google Fonts (OFL) | Sí | Incluir licencia |
| Voces TTS | Revisar cada una | Algunas voces/modelos prohíben uso comercial |
| Música «sin copyright» de dudosa procedencia | **No** | Solo con licencia verificable |

## 4. Privacidad y seguridad de niños (requisito de tiendas)

Una app para niños tiene reglas estrictas. Para 1.0 se recomienda:

- **Sin anuncios** ni SDK de publicidad/rastreo. Sin cuentas ni perfiles de niños. Sin chat ni contenido generado por usuarios.
- **Compras detrás de una puerta parental** (p. ej. pregunta de cálculo o mantener pulsado).
- Analítica **mínima, agregada y sin identificadores publicitarios** (o ninguna en el MVP).
- Política de privacidad pública y clara; datos almacenados localmente en el dispositivo.
- Cumplir con: **COPPA** (EE. UU.), **GDPR-K/RGPD** (UE), normativa local de datos personales; en tiendas,
  **Google Play – política de Familias / Diseñado para familias** y **Apple – categoría Niños (guías 1.3 y 5.1.4)**.
  Verificar siempre el texto vigente de cada tienda al preparar la 1.0.
- Seguridad física del holograma: instrucciones para adultos (superficie estable, cuidado con bordes del acetato, no dejar el teléfono recalentándose).

## 5. Checklist de lanzamiento (copiar al backlog de la 1.0)

- [ ] Nombre y logotipo con búsqueda de marca y dominio.
- [ ] Libro de licencias completo y revisado.
- [ ] Contratos de artistas/narradores archivados.
- [ ] Pantalla de créditos y avisos de licencia en la app.
- [ ] Política de privacidad y términos publicados.
- [ ] Formularios de tiendas (clasificación por edad, público infantil, seguridad de datos) completados.
- [ ] Revisión por un abogado de PI.
