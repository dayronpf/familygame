#!/bin/zsh
# Publicación automática de los cuentos del panel (docs/37). La lanza launchd cada 10 minutos
# (~/Library/LaunchAgents/com.mininoches.publicar.plist). Si la cola está vacía, termina en un segundo.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG="es_ES.UTF-8"
cd "$(dirname "$0")/../.." || exit 1
echo "=== $(date '+%Y-%m-%d %H:%M:%S')"
exec /usr/bin/python3 tools/content/publish_panel.py "$@"
