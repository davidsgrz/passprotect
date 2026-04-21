#!/bin/bash
set -euo pipefail

LOG="/root/logs/informe.log"
mkdir -p /root/logs /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Vaultwarden Corporativo ===" >> "$LOG"

# Ejecutar capa de seguridad en background (audit loop)
bash /root/admin/ubseguridadd/start.sh &
sleep 2

# Verificacion de entorno obligatoria
[ -n "${DOMAIN:-}" ] || { echo "ERROR: DOMAIN no configurado"; exit 1; }
[ -n "${DATABASE_URL:-}" ] || { echo "ERROR: DATABASE_URL no configurado"; exit 1; }
[ -n "${ADMIN_TOKEN:-}" ] || { echo "ERROR: ADMIN_TOKEN no configurado"; exit 1; }

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Domain: ${DOMAIN}" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSO enabled: ${SSO_ENABLED:-false}" >> "$LOG"

# Ejecutar como usuario no-root
exec su -s /bin/bash vaultwarden -c "/usr/local/bin/vaultwarden"
