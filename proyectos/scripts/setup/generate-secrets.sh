#!/bin/bash
# generate-secrets.sh — Genera todos los passwords con openssl rand
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"

echo "=== PassProtect — Generacion de secretos ==="

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra $CONFIG_FILE"
    exit 1
fi

# Generar passwords seguros
VW_ADMIN_TOKEN=$(openssl rand -base64 48)
DB_VW_ROOT_PASSWORD=$(openssl rand -base64 32)
DB_VW_PASSWORD=$(openssl rand -base64 32)
KC_ADMIN_PASSWORD=$(openssl rand -base64 32)
DB_KC_ROOT_PASSWORD=$(openssl rand -base64 32)
DB_KC_PASSWORD=$(openssl rand -base64 32)
SSO_CLIENT_SECRET=$(openssl rand -hex 32)
LDAP_ADMIN_PASSWORD=$(openssl rand -base64 24)
LDAP_CONFIG_PASSWORD=$(openssl rand -base64 24)
# Dashboard oauth2-proxy (SSO via Keycloak):
# - DASHBOARD_SSO_CLIENT_SECRET: secret del cliente OIDC "dashboard" en Keycloak
# - DASHBOARD_OAUTH2_COOKIE_SECRET: clave AES-256 (32 bytes) para cifrar cookie de sesion
DASHBOARD_SSO_CLIENT_SECRET=$(openssl rand -hex 32)
DASHBOARD_OAUTH2_COOKIE_SECRET=$(openssl rand -base64 32 | tr -d '\n=' | head -c 32)

# Reemplazar placeholders en config.env
sed -i "s|VW_ADMIN_TOKEN=.*|VW_ADMIN_TOKEN=${VW_ADMIN_TOKEN}|" "$CONFIG_FILE"
sed -i "s|DB_VW_ROOT_PASSWORD=.*|DB_VW_ROOT_PASSWORD=${DB_VW_ROOT_PASSWORD}|" "$CONFIG_FILE"
sed -i "s|DB_VW_PASSWORD=.*|DB_VW_PASSWORD=${DB_VW_PASSWORD}|" "$CONFIG_FILE"
sed -i "s|KC_ADMIN_PASSWORD=.*|KC_ADMIN_PASSWORD=${KC_ADMIN_PASSWORD}|" "$CONFIG_FILE"
sed -i "s|DB_KC_ROOT_PASSWORD=.*|DB_KC_ROOT_PASSWORD=${DB_KC_ROOT_PASSWORD}|" "$CONFIG_FILE"
sed -i "s|DB_KC_PASSWORD=.*|DB_KC_PASSWORD=${DB_KC_PASSWORD}|" "$CONFIG_FILE"
sed -i "s|SSO_CLIENT_SECRET=.*|SSO_CLIENT_SECRET=${SSO_CLIENT_SECRET}|" "$CONFIG_FILE"
sed -i "s|LDAP_ADMIN_PASSWORD=.*|LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD}|" "$CONFIG_FILE"
sed -i "s|LDAP_CONFIG_PASSWORD=.*|LDAP_CONFIG_PASSWORD=${LDAP_CONFIG_PASSWORD}|" "$CONFIG_FILE"
# Append-or-replace para las nuevas vars (compatibilidad con config.env preexistente)
if grep -q "^DASHBOARD_SSO_CLIENT_SECRET=" "$CONFIG_FILE"; then
    sed -i "s|DASHBOARD_SSO_CLIENT_SECRET=.*|DASHBOARD_SSO_CLIENT_SECRET=${DASHBOARD_SSO_CLIENT_SECRET}|" "$CONFIG_FILE"
else
    echo "DASHBOARD_SSO_CLIENT_SECRET=${DASHBOARD_SSO_CLIENT_SECRET}" >> "$CONFIG_FILE"
fi
if grep -q "^DASHBOARD_OAUTH2_COOKIE_SECRET=" "$CONFIG_FILE"; then
    sed -i "s|DASHBOARD_OAUTH2_COOKIE_SECRET=.*|DASHBOARD_OAUTH2_COOKIE_SECRET=${DASHBOARD_OAUTH2_COOKIE_SECRET}|" "$CONFIG_FILE"
else
    echo "DASHBOARD_OAUTH2_COOKIE_SECRET=${DASHBOARD_OAUTH2_COOKIE_SECRET}" >> "$CONFIG_FILE"
fi

# Generar .env para docker-compose
COMPOSE_DIR="$PROJECT_DIR/proyectos/docker-compose"
cp "$CONFIG_FILE" "$COMPOSE_DIR/.env"

echo ""
echo "=== Secretos generados y escritos en ==="
echo "  - $CONFIG_FILE"
echo "  - $COMPOSE_DIR/.env"
echo ""
echo "IMPORTANTE: No commitear estos ficheros a git"
echo "Siguiente paso: bash $SCRIPT_DIR/build-images.sh"
