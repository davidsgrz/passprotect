#!/bin/bash
set -euo pipefail

LOG="/root/logs/informe.log"
mkdir -p /root/logs

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Keycloak Corporativo ===" >> "$LOG"

bash /root/admin/ubseguridad/start.sh &
sleep 2

KC_MODE="${1:-start-dev}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Modo: ${KC_MODE}" >> "$LOG"

exec su -s /bin/bash keycloak -c "/opt/keycloak/bin/kc.sh ${KC_MODE}"
