FROM quay.io/keycloak/keycloak:24.0 AS kc-source

FROM dsegura97/ubseguridadd:latest

LABEL description="Keycloak corporativo con capa seguridad"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=kc-source /opt/keycloak /opt/keycloak

RUN groupadd -r keycloak && useradd -r -g keycloak -d /opt/keycloak keycloak \
    && chown -R keycloak:keycloak /opt/keycloak

ENV PATH="/opt/keycloak/bin:${PATH}"
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Hardening: heap JVM ajustado para VPS 4GB (1024->768MB, suficiente <100 usuarios)
ENV JAVA_OPTS="-Xms384m -Xmx768m -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=192m -Djava.awt.headless=true -Dfile.encoding=UTF-8"

RUN mkdir -p /opt/keycloak/admin /opt/keycloak/logs \
    && chown -R keycloak:keycloak /opt/keycloak/admin /opt/keycloak/logs \
    && chmod 0775 /opt/keycloak/logs
COPY --chmod=0755 --chown=keycloak:keycloak dockerfiles/keycloak/admin/start.sh /opt/keycloak/admin/start.sh

EXPOSE 8080 9000

ENTRYPOINT ["/opt/keycloak/admin/start.sh"]
