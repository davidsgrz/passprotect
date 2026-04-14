#!/bin/bash
set -euo pipefail

LOG="/root/logs/informe.log"
mkdir -p /root/logs

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Dashboard PassProtect ===" >> "$LOG"

bash /root/admin/ubseguridad/start.sh &
sleep 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dashboard activo en puerto 3000" >> "$LOG"

exec nginx -g "daemon off;"
