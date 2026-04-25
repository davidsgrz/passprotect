#!/bin/bash
# Wrapper corporativo postgres-corp:
# - Registra evento de arranque
# - LOG_DIR FUERA de $PGDATA para no contaminar el data dir (initdb requiere
#   $PGDATA vacío en la primera ejecución)
# - Delega al docker-entrypoint.sh oficial sin modificar nada más
set -euo pipefail

LOG_DIR="/var/log/postgres-corp"
LOG_FILE="${LOG_DIR}/informe.log"

mkdir -p "$LOG_DIR" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === PostgreSQL Corp arrancando ===" >> "$LOG_FILE" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB=${POSTGRES_DB:-unset} User=${POSTGRES_USER:-unset}" >> "$LOG_FILE" 2>/dev/null || true

exec docker-entrypoint.sh "$@"
