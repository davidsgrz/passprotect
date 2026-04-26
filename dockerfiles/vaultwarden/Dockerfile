FROM timshel/vaultwarden:1.34.1-6 AS vw-source

FROM dsegura97/ubseguridadd:latest

LABEL description="Vaultwarden corporativo con capa seguridad (Timshel SSO fork)"
LABEL version="1.0.4"

ENV DEBIAN_FRONTEND=noninteractive

# libpq5 + libmariadb3 son AMBOS requeridos por el binario vaultwarden (compilado
# con backends mariadb y postgres dynamically linked). Sin uno de los dos:
# 'libpq.so.5: cannot open shared object file' o 'libmariadb.so.3: ...'
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libpq5 \
    libmariadb3 \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && test -f /usr/lib/x86_64-linux-gnu/libpq.so.5 \
    && test -f /usr/lib/x86_64-linux-gnu/libmariadb.so.3 \
    && ldconfig

# Copiar binarios desde la imagen Timshel.
# Timshel publica el binario en /vaultwarden (igual que upstream) pero el web-vault
# está en /web-vault_button (UI con boton "Enterprise SSO") y /web-vault_override
# (overrides más invasivos). Usamos _button por ser el patch mínimo necesario para
# habilitar el flow SSO en la pantalla de login.
COPY --from=vw-source /vaultwarden /usr/local/bin/vaultwarden
COPY --from=vw-source /web-vault_button /web-vault

# Hardening: usuario no root para ejecutar Vaultwarden
RUN groupadd -r vaultwarden && useradd -r -g vaultwarden -d /data vaultwarden
RUN mkdir -p /data && chown vaultwarden:vaultwarden /data

ENV ROCKET_PORT=80
ENV DATA_FOLDER=/data
ENV WEB_VAULT_FOLDER=/web-vault
ENV LOG_FILE=/data/vaultwarden.log
ENV EXTENDED_LOGGING=true
ENV LOG_LEVEL=info
# ROCKET_LIMITS eliminado: la sintaxis JSON string es válida en Rocket 0.4 pero
# Rocket 0.5 (Vaultwarden 1.32+) espera un map. El default de Vaultwarden ya
# limita correctamente (10MB JSON). Si en el futuro se necesita ajustar:
# ENV ROCKET_LIMITS={json=10485760,form=10485760}

VOLUME /data

RUN mkdir -p /root/admin/vaultwarden
COPY dockerfiles/vaultwarden/admin/start.sh /root/admin/vaultwarden/
RUN chmod +x /root/admin/vaultwarden/start.sh

EXPOSE 80 3012

ENTRYPOINT ["/root/admin/vaultwarden/start.sh"]
