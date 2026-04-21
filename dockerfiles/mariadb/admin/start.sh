#!/bin/bash
set -euo pipefail

LOG="/root/logs/informe.log"
mkdir -p /root/logs /var/log/mysql
chown mysql:mysql /var/log/mysql

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === MariaDB hardened ===" >> "$LOG"

bash /root/admin/ubseguridadd/start.sh &
sleep 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB: ${MYSQL_DATABASE:-unset}" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] User: ${MYSQL_USER:-unset}" >> "$LOG"

exec docker-entrypoint.sh mariadbd
