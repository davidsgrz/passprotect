FROM mariadb:11.2 AS mdb-source

FROM dsegura97/ubseguridad:latest

LABEL description="MariaDB hardened con protecciones anti-SQLi"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mdb-source /usr/local/bin/docker-entrypoint.sh /usr/local/bin/
COPY --from=mdb-source /usr/local/bin/healthcheck.sh /usr/local/bin/

# Configuracion hardened anti-SQLi
COPY dockerfiles/mariadb/hardening/my.cnf /etc/mysql/conf.d/99-hardening.cnf
COPY dockerfiles/mariadb/hardening/init-security.sql /docker-entrypoint-initdb.d/99-security.sql

RUN mkdir -p /var/lib/mysql /var/run/mysqld /root/admin/mariadb \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

COPY dockerfiles/mariadb/admin/start.sh /root/admin/mariadb/
RUN chmod +x /root/admin/mariadb/start.sh

VOLUME /var/lib/mysql
EXPOSE 3306

ENTRYPOINT ["/root/admin/mariadb/start.sh"]
