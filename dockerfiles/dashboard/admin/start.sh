#!/bin/bash
set -euo pipefail

LOG="/root/logs/informe.log"
mkdir -p /root/logs

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Dashboard PassProtect ===" >> "$LOG"

bash /root/admin/ubseguridadd/start.sh &
sleep 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dashboard activo en puerto 3000" >> "$LOG"

# daemon off: nginx en foreground para que el kubelet lo gestione (sin esto,
# nginx forkea y el container muere apenas arranca)
exec nginx -g "daemon off;"
