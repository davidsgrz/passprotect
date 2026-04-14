FROM vaultwarden/server:1.32.5 AS vw-source

FROM dsegura97/ubseguridad:latest

LABEL description="Vaultwarden corporativo con capa seguridad"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libmariadb3 \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copiar binarios desde la imagen oficial
COPY --from=vw-source /vaultwarden /usr/local/bin/vaultwarden
COPY --from=vw-source /web-vault /web-vault

# Hardening: usuario no root para ejecutar Vaultwarden
RUN groupadd -r vaultwarden && useradd -r -g vaultwarden -d /data vaultwarden
RUN mkdir -p /data && chown vaultwarden:vaultwarden /data

ENV ROCKET_PORT=80
ENV DATA_FOLDER=/data
ENV WEB_VAULT_FOLDER=/web-vault
ENV LOG_FILE=/data/vaultwarden.log
ENV EXTENDED_LOGGING=true
ENV LOG_LEVEL=info

# Hardening Rocket (web server de Vaultwarden) — limite 10MB JSON payload
ENV ROCKET_LIMITS='{"json":10485760}'

VOLUME /data

RUN mkdir -p /root/admin/vaultwarden
COPY docker/kube/vaultwarden/admin/start.sh /root/admin/vaultwarden/
RUN chmod +x /root/admin/vaultwarden/start.sh

EXPOSE 80 3012

ENTRYPOINT ["/root/admin/vaultwarden/start.sh"]
