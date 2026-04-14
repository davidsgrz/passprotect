#!/bin/bash
set -euo pipefail

LOG_FILE="/root/logs/informe.log"
mkdir -p /root/logs
touch "$LOG_FILE"

source /root/admin/base/usuarios/mainUsuarios.sh
source /root/admin/base/ssh/mainSsh.sh
source /root/admin/base/sudo/mainSudo.sh

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

main() {
    log "=== Iniciando capa base ==="

    if newUser; then
        make_ssh
        make_sudo
        log "Capa base configurada correctamente"
    else
        log "ERROR en la creacion de usuario"
        exit 1
    fi
}

main
