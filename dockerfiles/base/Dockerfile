FROM ubuntu:22.04

LABEL maintainer="David Segura & Francisco Parra"
LABEL description="Capa base: SSH hardening + gestion usuarios"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

# Paquetes minimos con pinning de versiones cuando es posible
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano=7.* \
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
RUN echo "umask 027" >> /etc/profile \
    && chmod 700 /root \
    && chmod 644 /etc/passwd \
    && chmod 600 /etc/shadow

RUN mkdir -p /root/admin/base /root/logs /var/run/sshd

WORKDIR /root/admin/base

COPY dockerfiles/base/admin/ .
COPY common/id_rsa.pub ./common/id_rsa.pub

RUN find /root/admin -name "*.sh" -exec chmod +x {} \;

EXPOSE 22

ENTRYPOINT ["./start.sh"]
