#!/bin/bash
set -euo pipefail

# Capa de seguridad — auditoria de puertos y conexiones cada 5 minutos
# Bug corregido: intervalo de 30s generaba logs infinitos, ahora 300s + rotacion

LOG_FILE="/root/logs/security_audit.log"
MAX_LOG_SIZE=5242880  # 5MB
SCAN_INTERVAL=300     # 5 minutos (no 30s)

mkdir -p /root/logs
touch "$LOG_FILE"

load_base_layer() {
    bash /root/admin/base/start.sh
}

rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ]; then
        local size
        size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotado (${size} bytes)" > "$LOG_FILE"
        fi
    fi
}

security_audit() {
    {
        echo "=== SECURITY AUDIT $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Hostname: $(hostname)"
        echo ""
        echo "--- Listening ports (ss -tulnp) ---"
        ss -tulnp 2>/dev/null || echo "ss not available"
        echo ""
        echo "--- Active connections ---"
        ss -tn state established 2>/dev/null | head -20
        echo ""
        echo "--- Top 5 memory consumers ---"
        ps aux --sort=-%mem 2>/dev/null | head -6
        echo ""
        echo "--- Disk usage ---"
        df -h / 2>/dev/null
        echo ""
        echo "--- Failed login attempts (last 10) ---"
        grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 || echo "No auth log"
        echo ""
        echo "=== END AUDIT ==="
        echo ""
    } >> "$LOG_FILE"
}

audit_loop() {
    while true; do
        rotate_log_if_needed
        security_audit
        sleep "$SCAN_INTERVAL"
    done
}

main() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando capa seguridad" >> "$LOG_FILE"
    load_base_layer
    audit_loop &
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Capa seguridad activa (scan cada ${SCAN_INTERVAL}s)" >> "$LOG_FILE"
}

main
