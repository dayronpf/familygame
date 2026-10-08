#!/usr/bin/env bash
# Copia a la app los packs y el arte que lleva incluidos (la fuente de verdad está fuera de app/).
# Uso: tools/sync_assets.sh         → sincroniza
#      tools/sync_assets.sh --check → falla si hay diferencias (para CI)
set -euo pipefail
cd "$(dirname "$0")/.."

PACKS=(demo)  # packs de contenido embebidos en la app
check=false; [[ "${1:-}" == "--check" ]] && check=true

fail() { echo "$1 desincronizado (ejecuta tools/sync_assets.sh)"; exit 1; }

# --- packs de contenido
for pack in "${PACKS[@]}"; do
  src="content/packs/$pack"; dst="app/assets/packs/$pack"
  if $check; then diff -r "$src" "$dst" >/dev/null || fail "$dst"
  else rm -rf "$dst"; mkdir -p "$(dirname "$dst")"; cp -r "$src" "$dst"; fi
done

# --- arte (rigs, escenas, índice y clips; no las vistas previas ni las especificaciones)
dst=app/assets/art
if $check; then
  diff -r art/medieval/rigs "$dst/medieval/rigs" >/dev/null || fail "$dst/medieval/rigs"
  diff -r art/medieval/scenes "$dst/medieval/scenes" >/dev/null || fail "$dst/medieval/scenes"
  diff art/medieval/index.json "$dst/medieval/index.json" >/dev/null || fail "$dst/medieval/index.json"
  diff -r art/clips "$dst/clips" >/dev/null || fail "$dst/clips"
else
  rm -rf "$dst"; mkdir -p "$dst/medieval"
  cp -r art/medieval/rigs art/medieval/scenes "$dst/medieval/"
  cp art/medieval/index.json "$dst/medieval/"
  cp -r art/clips "$dst/clips"
fi
echo "assets OK"
