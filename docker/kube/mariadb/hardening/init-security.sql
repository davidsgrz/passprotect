-- Hardening de seguridad inicial para MariaDB
-- Se ejecuta automaticamente en el primer arranque via /docker-entrypoint-initdb.d/

-- Eliminar usuarios anonimos
DELETE FROM mysql.user WHERE User='';

-- Eliminar base de datos test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Deshabilitar login remoto del root
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Privilegios minimos para los usuarios de aplicacion
-- (se crean via variables de entorno, pero les quitamos privilegios peligrosos)
-- Nota: estos REVOKE pueden fallar si el usuario aun no existe; se ignoran errores
REVOKE FILE ON *.* FROM 'vaultwarden'@'%';
REVOKE PROCESS ON *.* FROM 'vaultwarden'@'%';
REVOKE SUPER ON *.* FROM 'vaultwarden'@'%';
REVOKE SHUTDOWN ON *.* FROM 'vaultwarden'@'%';
REVOKE RELOAD ON *.* FROM 'vaultwarden'@'%';
REVOKE CREATE USER ON *.* FROM 'vaultwarden'@'%';

REVOKE FILE ON *.* FROM 'keycloak'@'%';
REVOKE PROCESS ON *.* FROM 'keycloak'@'%';
REVOKE SUPER ON *.* FROM 'keycloak'@'%';

FLUSH PRIVILEGES;
