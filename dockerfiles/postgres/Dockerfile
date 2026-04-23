FROM postgres:16-alpine

LABEL maintainer="David Segura & Francisco Parra"
LABEL description="PostgreSQL corporativo hardened (sustituye a mariadb-corp)"
LABEL version="1.0.0"

# Config hardening (tuned para VPS 4GB con 2 instancias postgres)
COPY dockerfiles/postgres/hardening/postgresql.conf /etc/postgresql/postgresql.conf

# Inicializacion de seguridad
COPY dockerfiles/postgres/hardening/init-security.sql /docker-entrypoint-initdb.d/99-security.sql

# Wrapper con log corporativo (mantiene el patron de start.sh de ubseguridadd)
COPY dockerfiles/postgres/admin/start.sh /usr/local/bin/corp-start.sh
RUN chmod +x /usr/local/bin/corp-start.sh

# scram-sha-256 es el default en Postgres 14+, forzamos explicito
ENV POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256 --auth-local=scram-sha-256"
ENV PGDATA=/var/lib/postgresql/data/pgdata

EXPOSE 5432

ENTRYPOINT ["/usr/local/bin/corp-start.sh"]
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
