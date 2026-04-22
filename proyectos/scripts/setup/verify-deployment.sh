#!/bin/bash
# verify-deployment.sh — Healthchecks de todos los componentes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    printf "%-35s" "  $name..."
    if eval "$cmd" &>/dev/null; then
        echo "OK"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== PassProtect — Verificacion de despliegue ==="
echo ""

# Kubernetes pods
echo "[Kubernetes Pods]"
check "Vaultwarden pod" "kubectl get pods -n vaultwarden -l app=vaultwarden -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "MariaDB-VW pod" "kubectl get pods -n vaultwarden -l app=mariadb-vw -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "Keycloak pod" "kubectl get pods -n auth -l app=keycloak -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "MariaDB-KC pod" "kubectl get pods -n auth -l app=mariadb-kc -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "OpenLDAP pod" "kubectl get pods -n auth -l app=openldap -o jsonpath='{.items[0].status.phase}' | grep -q Running"
echo ""

# Servicios
echo "[Kubernetes Services]"
check "Vaultwarden svc" "kubectl get svc -n vaultwarden vaultwarden"
check "MariaDB-VW svc" "kubectl get svc -n vaultwarden mariadb-vw"
check "Keycloak svc" "kubectl get svc -n auth keycloak"
check "MariaDB-KC svc" "kubectl get svc -n auth mariadb-kc"
check "OpenLDAP svc" "kubectl get svc -n auth openldap"
echo ""

# Ingress
echo "[Ingress]"
check "Vaultwarden ingress" "kubectl get ingress -n vaultwarden vaultwarden-ingress"
check "Keycloak ingress" "kubectl get ingress -n auth keycloak-ingress"
echo ""

# HTTP healthchecks
echo "[HTTP Healthchecks]"
check "Vaultwarden /alive" "curl -sk https://vault.${VPS_IP}.nip.io/alive"
check "Keycloak /health/ready" "curl -sk https://auth.${VPS_IP}.nip.io/health/ready"
echo ""

# PVCs
echo "[Persistent Volumes]"
check "vaultwarden-data PVC" "kubectl get pvc -n vaultwarden vaultwarden-data -o jsonpath='{.status.phase}' | grep -q Bound"
check "mariadb-vw PVC" "kubectl get pvc -n vaultwarden mariadb-vw -o jsonpath='{.status.phase}' | grep -q Bound"
check "mariadb-kc PVC" "kubectl get pvc -n auth mariadb-kc -o jsonpath='{.status.phase}' | grep -q Bound"
echo ""

# Network Policies
echo "[Network Policies]"
check "VW deny-all" "kubectl get networkpolicy -n vaultwarden default-deny-all"
check "Auth deny-all" "kubectl get networkpolicy -n auth default-deny-all"
echo ""

# Resumen
echo "========================================="
echo "  PASS: ${PASS}  |  FAIL: ${FAIL}"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
    echo "ATENCION: Hay ${FAIL} checks fallidos. Revisa los componentes."
    exit 1
fi

echo "Todos los checks pasaron correctamente."
