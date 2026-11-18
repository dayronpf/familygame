#!/usr/bin/env bash
# Sube a GitHub (secretos de Actions) las claves que necesita el despliegue del servidor, leyéndolas de
# credenciales/.env. Los valores no se muestran. Uso: bash tools/subir_secretos.sh
set -euo pipefail
cd "$(dirname "$0")/.."
f=credenciales/.env
val() { grep -E "^$1=" "$f" | head -1 | cut -d= -f2-; }
for k in FTP_SERVER FTP_USERNAME FTP_PASSWORD DEPLOY_TOKEN; do
  v="$(val "$k")"
  [ -n "$v" ] || { echo "Falta $k en $f"; exit 1; }
  printf '%s' "$v" | gh secret set "$k" --repo dayronpf/familygame
  echo "✓ $k"
done
gh api -X PUT repos/dayronpf/familygame/environments/produccion >/dev/null && echo "✓ entorno «produccion»"
echo "Listo. Para publicar el servidor: gh workflow run server-deploy.yml --ref servidor"
