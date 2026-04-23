#!/bin/bash
set -euo pipefail

LOG="/opt/keycloak/logs/informe.log"
mkdir -p /opt/keycloak/logs

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Keycloak Corporativo ===" >> "$LOG"

KC_MODE="${1:-start-dev}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Modo: ${KC_MODE}" >> "$LOG"

exec /opt/keycloak/bin/kc.sh "${KC_MODE}"
