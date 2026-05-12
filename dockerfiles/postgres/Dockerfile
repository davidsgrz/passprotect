# postgres:16-alpine (no debian): imagen ~80 MB vs 240 MB. Menos paquetes = menos CVEs.
# NO hereda de ubseguridadd porque el entrypoint oficial de postgres maneja
# initdb/permisos del data dir; envolverlo romperia el bootstrap
FROM postgres:16-alpine

LABEL maintainer="David Segura & Francisco Parra"
LABEL description="PostgreSQL corporativo hardened (sustituye a mariadb-corp)"
LABEL version="1.0.0"

# Config hardening (tuned para VPS 4GB con 2 instancias postgres)
COPY dockerfiles/postgres/hardening/postgresql.conf /etc/postgresql/postgresql.conf

# Inicializacion de seguridad
# Cualquier .sql, .sh o .sql.gz colocado en /docker-entrypoint-initdb.d/ se
# ejecuta UNA VEZ al inicializar el cluster (cuando $PGDATA esta vacio).
# Los ficheros se ejecutan en orden alfabetico, por eso usamos prefijo "99-"
# para que se ejecute despues de las inits oficiales de la imagen
COPY dockerfiles/postgres/hardening/init-security.sql /docker-entrypoint-initdb.d/99-security.sql

# Wrapper con log corporativo (mantiene el patron de start.sh de ubseguridadd)
COPY dockerfiles/postgres/admin/start.sh /usr/local/bin/corp-start.sh
RUN chmod +x /usr/local/bin/corp-start.sh

# scram-sha-256 es el default en Postgres 14+, forzamos explicito
ENV POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256 --auth-local=scram-sha-256"
# PGDATA en subdirectorio (no en raiz del volumen): algunos drivers de almacenamiento
# crean lost+found en la raiz que rompe initdb con "data directory is not empty"
ENV PGDATA=/var/lib/postgresql/data/pgdata

EXPOSE 5432

# ENTRYPOINT corp-start.sh = nuestro wrapper de logging.
# CMD = comando que recibe el wrapper como $@. El wrapper hace exec hacia
# docker-entrypoint.sh con esos args, que termina lanzando 'postgres -c ...'
# Asi mantenemos el flow oficial de la imagen pero con un log de arranque propio
ENTRYPOINT ["/usr/local/bin/corp-start.sh"]
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
