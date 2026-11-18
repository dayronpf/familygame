# 37 · Panel de administración: cuentos, borradores y publicación

> 18-nov-2026. Cómo se manejan los cuentos desde `https://cuentos2.tuvendor.com/admin` y cómo llegan a la app.

## Qué cambia la app al momento y qué hay que publicar

| Acción en el panel | ¿Cuándo lo ve la app? |
|---|---|
| Ocultar / mostrar un cuento, hacerlo gratis o de pago | Al momento: va en el catálogo (`GET /v1/catalog`), que la app consulta una vez al día. |
| Editar el texto, el título, la enseñanza, las edades o el dibujo de una escena | Al publicar. |
| Cuento nuevo | Al publicar. |
| Eliminar un cuento publicado | Se oculta al momento; se quita del pack al publicar. Hasta entonces se puede cancelar. |
| Eliminar un cuento nuevo que nunca se publicó | Al momento (se borra del todo). |

## Editor

- **Datos del cuento:** título, enseñanza (de la lista del pack), frase de la enseñanza y edades.
- **En la app:** si sale en el catálogo de la app, nombre del protagonista, si es niña o niño, y edad. La semilla está en «Avanzado».
- **Escenas:** se pueden reordenar, insertar y quitar (mínimo 3, máximo 20). Cada escena admite varias versiones y tiene su **«Dibujo de la escena»**:
  - lugar, momento del día y ambiente;
  - quién sale y con qué gesto;
  - qué objetos se ven;
  - «Cambia de lugar».
  Una escena nueva copia el dibujo de la anterior.
- **Marcas:** `{hero}`, `{hero.o}`, `{item.un}`… se insertan tocándolas. El panel rechaza marcas que el cuento no tiene.
- **Cuento nuevo:** se parte de uno que existe (mismo mundo, personajes y dibujos) y se cambia el texto.

## Publicar

1. «Guardar y publicar» (o «Publicar cambios» en la lista) pone el cuento **en cola**.
2. En el Mac del proyecto se ejecuta:
   ```
   python3 tools/content/publish_panel.py
   ```
   El programa:
   - lee la cola;
   - aplica cada cambio a `content/packs/*/pack.json` y a `content/catalogo/lanzamiento-es.json`;
   - **valida cada cuento con el motor**. Si el texto y el dibujo no coinciden, deshace solo ese cuento y el panel muestra el error en su ficha.
3. Con los cuentos que pasan, sigue:
   - graba la voz con ElevenLabs. Sin créditos, sigue sin voz y la app usa la del teléfono;
   - publica en R2, y la app los baja sin actualizarse;
   - sube a git: la rama de trabajo y `servidor`.
4. El despliegue vuelve a leer los packs y el panel marca el cuento como publicado.

Opciones:
- `--prueba` aplica y valida sin grabar, sin subir y deshaciendo todo al final.
- `--sin-voz` publica sin grabar.

**Lo que necesita:** dart, ffmpeg, boto3 y `credenciales/.env` con `DEPLOY_TOKEN` (el mismo valor que `MININOCHES_DEPLOY_TOKEN` del servidor), ElevenLabs y R2.

**Servidor:** la cola es `GET /internal/contenido/cola` y los resultados van a `POST /internal/contenido/resultado`. Las dos usan el token del despliegue.

## Pendiente

- Que la publicación corra sola, por ejemplo con una tarea de `launchd` en el Mac cada 10 minutos. Hoy se ejecuta a mano.
- Dibujos nuevos (personajes, fondos u objetos que no existen) siguen necesitando ilustración: el editor solo combina los que hay.
