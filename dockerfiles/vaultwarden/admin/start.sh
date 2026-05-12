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

# Ejecutar como usuario no-root.
# 'su' droppea CAP_NET_BIND_SERVICE -> el binario NO puede bindear a <1024
# aunque el container tenga la cap. Por eso ROCKET_PORT=8080 en el manifest helm.
# exec reemplaza el shell -> vaultwarden recibe SIGTERM directamente del kubelet
exec su -s /bin/bash vaultwarden -c "/usr/local/bin/vaultwarden"
