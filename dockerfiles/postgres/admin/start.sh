#!/bin/sh
# Wrapper corporativo: registra evento y encadena al entrypoint oficial.
set -eu

LOG_DIR="${PGDATA:-/var/lib/postgresql/data}/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="$LOG_DIR/informe.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === PostgreSQL Corp ===" >> "$LOG_FILE" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB=${POSTGRES_DB:-unset} User=${POSTGRES_USER:-unset}" >> "$LOG_FILE" 2>/dev/null || true

exec docker-entrypoint.sh "$@"
