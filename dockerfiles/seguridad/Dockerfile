FROM dsegura97/ubbasse:latest

LABEL maintainer="David Segura & Francisco Parra"
LABEL description="Capa seguridad: auditoria puertos, hardening kernel"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    tcpdump \
    nmap \
    lynis \
    rkhunter \
    aide \
    logrotate \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configuracion de logrotate para logs de seguridad
RUN cat > /etc/logrotate.d/security <<'EOF'
/root/logs/*.log {
    size 5M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
EOF

RUN mkdir -p /root/admin/ubseguridadd

WORKDIR /root/admin/ubseguridadd

COPY dockerfiles/seguridad/admin/start.sh .
RUN chmod +x ./start.sh

ENTRYPOINT ["./start.sh"]
