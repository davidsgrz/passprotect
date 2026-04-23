#!/bin/bash
# security-audit.sh — Audita la seguridad del cluster y las imagenes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=== PassProtect — Auditoria de Seguridad ==="
echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Trivy scan de imagenes
echo "=== [1/3] Trivy scan de imagenes ==="
IMAGES=(
    "dsegura97/ubbasse:latest"
    "dsegura97/ubseguridadd:latest"
    "dsegura97/vaultwarden-corp:1.0.0"
    "dsegura97/keycloak-corp:1.0.0"
    "dsegura97/postgres-corp:1.0.0"
    "dsegura97/nginx-proxy-corp:1.0.0"
)

for img in "${IMAGES[@]}"; do
    echo ""
    echo "--- Scanning $img ---"
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy:latest image --severity HIGH,CRITICAL "$img" || echo "WARN: Trivy fallo para $img"
done

# Kube-bench (CIS Kubernetes Benchmark)
echo ""
echo "=== [2/3] Kube-bench (CIS Kubernetes Benchmark) ==="
kubectl run --rm -it kube-bench \
    --image=aquasec/kube-bench:latest \
    --restart=Never \
    --namespace=monitoring \
    -- --version 1.24 || echo "WARN: kube-bench fallo o no disponible"

# Polaris (best practices check)
echo ""
echo "=== [3/3] Polaris (best practices check) ==="
kubectl run --rm -it polaris \
    --image=quay.io/fairwinds/polaris:latest \
    --restart=Never \
    --namespace=monitoring \
    -- polaris audit --audit-path / || echo "WARN: Polaris fallo o no disponible"

echo ""
echo "=== Auditoria completada ==="
