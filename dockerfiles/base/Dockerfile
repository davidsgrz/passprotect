FROM ubuntu:24.04

LABEL maintainer="David Segura & Francisco Parra"
LABEL description="Capa base: SSH hardening + gestion usuarios"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

# Paquetes minimos con pinning de versiones cuando es posible
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    git \
    curl \
    wget \
    iputils-ping \
    net-tools \
    iproute2 \
    dnsutils \
    sudo \
    openssh-server \
    ca-certificates \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* /var/tmp/*

# Hardening del sistema base
# umask 027: ficheros nuevos sin acceso "other" (group: read, other: ninguno)
# /root 700: solo root puede listar su home
# /etc/shadow 600: el default de Ubuntu ya es 640 con grupo shadow, lo bajamos
RUN echo "umask 027" >> /etc/profile \
    && chmod 700 /root \
    && chmod 644 /etc/passwd \
    && chmod 600 /etc/shadow

RUN mkdir -p /root/admin/base /root/logs /var/run/sshd

WORKDIR /root/admin/base

COPY dockerfiles/base/admin/ .
COPY common/id_rsa.pub ./common/id_rsa.pub

RUN find /root/admin -name "*.sh" -exec chmod +x {} \;

# EXPOSE 22 es declarativo (no abre nada). El SSH real escucha en 45678 (mainSsh.sh)
EXPOSE 22

ENTRYPOINT ["./start.sh"]
