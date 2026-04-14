FROM quay.io/keycloak/keycloak:24.0 AS kc-source

FROM dsegura97/ubseguridad:latest

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

# Hardening: limite JVM para evitar resource exhaustion
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m -Djava.awt.headless=true -Dfile.encoding=UTF-8"

RUN mkdir -p /root/admin/keycloak
COPY docker/kube/keycloak/admin/start.sh /root/admin/keycloak/
RUN chmod +x /root/admin/keycloak/start.sh

EXPOSE 8080 9000

ENTRYPOINT ["/root/admin/keycloak/start.sh"]
