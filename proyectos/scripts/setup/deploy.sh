#!/bin/bash
# deploy.sh — Genera values-prod.yaml desde config.env y despliega con Helm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"
HELM_DIR="$PROJECT_DIR/proyectos/helm/passprotect"
VALUES_PROD="$HELM_DIR/values-prod.yaml"

echo "=== PassProtect — Despliegue en Kubernetes ==="

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra $CONFIG_FILE"
    echo "Ejecuta primero: bash $SCRIPT_DIR/generate-secrets.sh"
    exit 1
fi

source "$CONFIG_FILE"

# Verificar que VPS_IP esta configurado
if [ "$VPS_IP" = "TU_IP_VPS" ]; then
    echo "ERROR: Configura VPS_IP en $CONFIG_FILE"
    exit 1
fi

# Generar values-prod.yaml
echo "[1/3] Generando values-prod.yaml..."
cat > "$VALUES_PROD" <<EOF
# Generado automaticamente por deploy.sh — NO commitear
global:
  vpsIp: "${VPS_IP}"
  imageRegistry: "dsegura97"

vaultwarden:
  domain: "https://vault.passprotect.es"
  adminToken: "${VW_ADMIN_TOKEN}"
  sso:
    enabled: "true"
    clientId: "${SSO_CLIENT_ID}"
    clientSecret: "${SSO_CLIENT_SECRET}"
    authority: "https://auth.passprotect.es/realms/corporativo"

mariadbVw:
  rootPassword: "${DB_VW_ROOT_PASSWORD}"
  password: "${DB_VW_PASSWORD}"

keycloak:
  hostname: "auth.passprotect.es"
  adminPassword: "${KC_ADMIN_PASSWORD}"

mariadbKc:
  rootPassword: "${DB_KC_ROOT_PASSWORD}"
  password: "${DB_KC_PASSWORD}"

openldap:
  adminPassword: "${LDAP_ADMIN_PASSWORD}"
  configPassword: "${LDAP_CONFIG_PASSWORD}"
EOF

echo "[2/3] Desplegando con Helm..."
helm upgrade --install passprotect "$HELM_DIR" \
    -f "$VALUES_PROD" \
    --create-namespace \
    --wait --timeout 10m

echo "[3/3] Verificando pods..."
kubectl get pods -n vaultwarden
kubectl get pods -n auth
kubectl get pods -n monitoring

echo ""
echo "=== Despliegue completado ==="
echo "Vaultwarden: https://vault.${VPS_IP}.nip.io"
echo "Keycloak:    https://auth.${VPS_IP}.nip.io"
echo ""
echo "Siguiente paso: bash $SCRIPT_DIR/configure-keycloak.sh"
