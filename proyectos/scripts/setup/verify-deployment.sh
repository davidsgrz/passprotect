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

# Contadores para el resumen final
PASS=0
FAIL=0

# Funcion generica de check: recibe un nombre legible y un comando bash a ejecutar.
# Imprime el nombre con padding fijo, ejecuta el comando silenciado (&>/dev/null)
# y pinta OK/FAIL segun el exit code. Asi cada check es una linea limpia
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
# Para cada componente sacamos el .status.phase del primer pod con la label app=<nombre>
# y comprobamos que sea "Running". Si esta Pending/CrashLoopBackOff/Error -> FAIL
echo "[Kubernetes Pods]"
check "Vaultwarden pod" "kubectl get pods -n vaultwarden -l app=vaultwarden -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "Postgres-VW pod" "kubectl get pods -n vaultwarden -l app=postgres-vw -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "Keycloak pod" "kubectl get pods -n auth -l app=keycloak -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "Postgres-KC pod" "kubectl get pods -n auth -l app=postgres-kc -o jsonpath='{.items[0].status.phase}' | grep -q Running"
check "OpenLDAP pod" "kubectl get pods -n auth -l app=openldap -o jsonpath='{.items[0].status.phase}' | grep -q Running"
echo ""

# Servicios
echo "[Kubernetes Services]"
check "Vaultwarden svc" "kubectl get svc -n vaultwarden vaultwarden"
check "Postgres-VW svc" "kubectl get svc -n vaultwarden postgres-vw"
check "Keycloak svc" "kubectl get svc -n auth keycloak"
check "Postgres-KC svc" "kubectl get svc -n auth postgres-kc"
check "OpenLDAP svc" "kubectl get svc -n auth openldap"
echo ""

# Ingress
echo "[Ingress]"
check "Vaultwarden ingress" "kubectl get ingress -n vaultwarden vaultwarden-ingress"
check "Keycloak ingress" "kubectl get ingress -n auth keycloak-ingress"
echo ""

# HTTP healthchecks
# Verificamos los endpoints publicos a traves del ingress (no del ClusterIP).
# /alive es el liveness propio de Vaultwarden, /health/ready el de Keycloak (Quarkus).
# Esto valida toda la cadena: ingress nginx -> service -> pod -> app responde 200
echo "[HTTP Healthchecks]"
check "Vaultwarden /alive" "curl -sk https://vault.passprotect.es/alive"
check "Keycloak /health/ready" "curl -sk https://auth.passprotect.es/health/ready"
echo ""

# PVCs (StatefulSet PVCs tienen formato data-<sts>-<ordinal>)
# Comprobamos que cada PVC esta Bound (ligado a un PV concreto). Si esta Pending,
# el storageClass no esta funcionando y el pod no podra arrancar.
# Los PVC de StatefulSet (postgres) se llaman data-<sts>-0 (volumeClaimTemplate)
echo "[Persistent Volumes]"
check "vaultwarden-data PVC" "kubectl get pvc -n vaultwarden vaultwarden-data -o jsonpath='{.status.phase}' | grep -q Bound"
check "postgres-vw PVC" "kubectl get pvc -n vaultwarden data-postgres-vw-0 -o jsonpath='{.status.phase}' | grep -q Bound"
check "postgres-kc PVC" "kubectl get pvc -n auth data-postgres-kc-0 -o jsonpath='{.status.phase}' | grep -q Bound"
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
