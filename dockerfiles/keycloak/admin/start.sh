#!/bin/bash
# Wrapper corporativo Keycloak: registra arranque y delega al kc.sh oficial
# pasando TODOS los args (permite "start", "start --optimized", "start-dev", etc.)
set -euo pipefail

LOG="/opt/keycloak/logs/informe.log"
mkdir -p /opt/keycloak/logs 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Keycloak Corporativo === args=$*" >> "$LOG" 2>/dev/null || true

exec /opt/keycloak/bin/kc.sh "$@"
