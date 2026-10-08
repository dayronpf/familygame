#!/usr/bin/env bash
# Copia los packs incluidos en la app desde content/packs (fuente de verdad).
# Uso: tools/sync_assets.sh         → sincroniza
#      tools/sync_assets.sh --check → falla si hay diferencias (para CI)
set -euo pipefail
cd "$(dirname "$0")/.."

PACKS=(demo)  # packs embebidos en la app

for pack in "${PACKS[@]}"; do
  src="content/packs/$pack"
  dst="app/assets/packs/$pack"
  if [[ "${1:-}" == "--check" ]]; then
    diff -r "$src" "$dst" >/dev/null || { echo "app/assets desincronizado con $src (ejecuta tools/sync_assets.sh)"; exit 1; }
  else
    mkdir -p "$dst"
    rsync -a --delete "$src/" "$dst/" 2>/dev/null || { rm -rf "$dst"; cp -r "$src" "$dst"; }
  fi
done
echo "assets OK"
