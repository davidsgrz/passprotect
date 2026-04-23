-- ============================================================
-- PassProtect — PostgreSQL Init Security Baseline
-- Se ejecuta una vez al crear el cluster, tras docker-entrypoint.sh.
-- ============================================================

-- Revoca permisos de creacion en el schema public al rol PUBLIC.
-- Solo el owner de la BD (POSTGRES_USER) podra crear tablas.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Revoca CONNECT por defecto; se concede explicitamente al usuario app.
-- (El entrypoint oficial ya ha creado POSTGRES_USER y su BD)
REVOKE ALL ON DATABASE postgres FROM PUBLIC;
