#!/bin/bash
# init-vps.sh — Prepara un VPS Ubuntu 24.04 con MicroK8s y dependencias
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"

echo "=== PassProtect — Inicializacion VPS ==="
echo "Directorio del proyecto: $PROJECT_DIR"

# Verificar que estamos en Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo "ERROR: Este script requiere Ubuntu 24.04 LTS"
    exit 1
fi

# Actualizar sistema
echo "[1/8] Actualizando sistema..."
apt-get update && apt-get upgrade -y

# Instalar dependencias base
echo "[2/8] Instalando dependencias..."
apt-get install -y \
    curl wget git jq openssl \
    apt-transport-https ca-certificates \
    gnupg lsb-release fail2ban ufw

# Instalar Docker
echo "[3/8] Instalando Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "$USER"
fi

# Instalar MicroK8s
echo "[4/8] Instalando MicroK8s 1.30..."
if ! command -v microk8s &>/dev/null; then
    snap install microk8s --classic --channel=1.30/stable
    usermod -aG microk8s "$USER"
    microk8s status --wait-ready
fi

# Habilitar addons
echo "[5/8] Habilitando addons de MicroK8s..."
microk8s enable dns
microk8s enable ingress
microk8s enable storage
microk8s enable helm3
microk8s enable metrics-server

# Alias kubectl y helm
echo "[6/8] Configurando aliases..."
snap alias microk8s.kubectl kubectl
snap alias microk8s.helm3 helm

# Generar certificados autofirmados
echo "[7/8] Generando certificados TLS autofirmados..."
CERT_DIR="/etc/letsencrypt/live/selfsigned"
mkdir -p "$CERT_DIR"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
VPS_IP="${VPS_IP:-127.0.0.1}"

openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -subj "/CN=*.${VPS_IP}.nip.io" \
    -addext "subjectAltName=DNS:vault.${VPS_IP}.nip.io,DNS:auth.${VPS_IP}.nip.io"

# Crear secrets TLS en K8s
microk8s kubectl create namespace vaultwarden --dry-run=client -o yaml | microk8s kubectl apply -f -
microk8s kubectl create namespace auth --dry-run=client -o yaml | microk8s kubectl apply -f -
microk8s kubectl create namespace monitoring --dry-run=client -o yaml | microk8s kubectl apply -f -

microk8s kubectl create secret tls vaultwarden-tls \
    --cert="$CERT_DIR/fullchain.pem" \
    --key="$CERT_DIR/privkey.pem" \
    -n vaultwarden --dry-run=client -o yaml | microk8s kubectl apply -f -

microk8s kubectl create secret tls keycloak-tls \
    --cert="$CERT_DIR/fullchain.pem" \
    --key="$CERT_DIR/privkey.pem" \
    -n auth --dry-run=client -o yaml | microk8s kubectl apply -f -

# Firewall basico
echo "[8/8] Configurando UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 45678/tcp  # SSH custom de contenedores
ufw allow 16443/tcp  # MicroK8s API
ufw --force enable

echo ""
echo "=== VPS inicializado correctamente ==="
echo "MicroK8s: $(microk8s version)"
echo "Docker: $(docker --version)"
echo "Siguiente paso: bash $SCRIPT_DIR/generate-secrets.sh"
