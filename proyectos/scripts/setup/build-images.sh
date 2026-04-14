#!/bin/bash
# build-images.sh — Construye y publica las imagenes Docker en Docker Hub
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REGISTRY="dsegura97"

echo "=== PassProtect — Build de imagenes Docker ==="
cd "$PROJECT_DIR"

# Verificar que Docker esta disponible
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker no esta instalado"
    exit 1
fi

# Login en Docker Hub
echo "[0/7] Login en Docker Hub..."
docker login -u "$REGISTRY" || { echo "ERROR: Login fallido"; exit 1; }

# Capa 1: ubbase
echo "[1/7] Construyendo ubbase..."
docker build -t "${REGISTRY}/ubbase:latest" -f dockerfiles/base/Dockerfile .
docker push "${REGISTRY}/ubbase:latest"

# Capa 2: ubseguridad
echo "[2/7] Construyendo ubseguridad..."
docker build -t "${REGISTRY}/ubseguridad:latest" -f dockerfiles/seguridad/Dockerfile .
docker push "${REGISTRY}/ubseguridad:latest"

# Capa 3a: vaultwarden-corp
echo "[3/7] Construyendo vaultwarden-corp..."
docker build -t "${REGISTRY}/vaultwarden-corp:1.0.0" -f dockerfiles/vaultwarden/Dockerfile .
docker push "${REGISTRY}/vaultwarden-corp:1.0.0"

# Capa 3b: keycloak-corp
echo "[4/7] Construyendo keycloak-corp..."
docker build -t "${REGISTRY}/keycloak-corp:1.0.0" -f dockerfiles/keycloak/Dockerfile .
docker push "${REGISTRY}/keycloak-corp:1.0.0"

# Capa 3c: mariadb-corp
echo "[5/7] Construyendo mariadb-corp..."
docker build -t "${REGISTRY}/mariadb-corp:1.0.0" -f dockerfiles/mariadb/Dockerfile .
docker push "${REGISTRY}/mariadb-corp:1.0.0"

# Capa 3d: nginx-proxy-corp
echo "[6/7] Construyendo nginx-proxy-corp..."
docker build -t "${REGISTRY}/nginx-proxy-corp:1.0.0" -f dockerfiles/nginx-proxy/Dockerfile .
docker push "${REGISTRY}/nginx-proxy-corp:1.0.0"

# Capa 3e: dashboard-corp
echo "[7/7] Construyendo dashboard-corp..."
docker build -t "${REGISTRY}/dashboard-corp:1.0.0" -f dockerfiles/dashboard/Dockerfile .
docker push "${REGISTRY}/dashboard-corp:1.0.0"

echo ""
echo "=== Imagenes publicadas ==="
echo "  ${REGISTRY}/ubbase:latest"
echo "  ${REGISTRY}/ubseguridad:latest"
echo "  ${REGISTRY}/vaultwarden-corp:1.0.0"
echo "  ${REGISTRY}/keycloak-corp:1.0.0"
echo "  ${REGISTRY}/mariadb-corp:1.0.0"
echo "  ${REGISTRY}/nginx-proxy-corp:1.0.0"
echo "  ${REGISTRY}/dashboard-corp:1.0.0"
echo ""
echo "Siguiente paso: bash $SCRIPT_DIR/deploy.sh"
