# Libro de licencias de assets

Regla del proyecto (ver [docs/04](docs/04-contenido-y-derechos.md)): **ningún asset entra al repositorio sin una fila aquí.**
Cada fila necesita autor, fuente, licencia y prueba (captura del sitio, recibo o contrato archivado).

| ID | Tipo | Autor / titular | Fuente | Licencia | Atribución requerida | Prueba | Fecha |
|---|---|---|---|---|---|---|---|
| `content/packs/demo/pack.json` | Texto | Autor del proyecto | Escrito para este proyecto | Todos los derechos reservados | No | Historial de git | 2026-10 |
| `art/**` (rigs, clips, escenas, SVG, PNG, GIF) | Arte vectorial | Autor del proyecto, con código escrito con asistencia de IA bajo su dirección | Generado por `tools/art/*.py` en este repositorio | Todos los derechos reservados; ver nota de autoría en [docs/11 §6](docs/11-pipeline-de-arte-por-codigo.md) | No | Historial de git (especificaciones y generadores versionados) | 2026-10 |
| Roboto (fuente por defecto de Material) | Fuente | Google | Incluida con el SDK de Flutter | Apache-2.0 | Aviso de licencia (Flutter lo agrega a la pantalla de licencias) | `showLicensePage` de Flutter | 2026-10 |
| Material Icons | Iconos | Google | Incluida con el SDK de Flutter | Apache-2.0 | Igual que la fuente | `showLicensePage` de Flutter | 2026-10 |

## Estado

- Arte vectorial: generado por código (ver fila de `art/medieval`). **Imágenes de terceros: ninguna.** Las referencias de estilo que aportó el dueño del proyecto **no están ni deben estar** en el repositorio.
- Animaciones: son matemática sobre los huesos de los rigs (sin assets externos).
- Música, efectos de sonido y voces: **ninguno todavía** (llegan en las versiones 0.3–0.4).
- Antes de añadir uno, verificar que la licencia permite uso **comercial** y en **apps de pago/freemium**
  (excluye CC-BY-NC, CC-BY-SA y «uso personal»).
