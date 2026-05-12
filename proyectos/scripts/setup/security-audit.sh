#!/bin/bash
# security-audit.sh — Audita la seguridad del cluster y las imagenes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=== PassProtect — Auditoria de Seguridad ==="
echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Trivy scan de imagenes
# Filtrado HIGH,CRITICAL: ignoramos LOW/MEDIUM porque la base Debian/Alpine
# arrastra cientos de CVEs por libs no usadas, ruido informativo
echo "=== [1/3] Trivy scan de imagenes ==="
IMAGES=(
    "dsegura97/ubbasse:latest"
    "dsegura97/ubseguridadd:latest"
    "dsegura97/vaultwarden-corp:1.0.0"
    "dsegura97/keycloak-corp:1.0.0"
    "dsegura97/postgres-corp:1.0.0"
)

for img in "${IMAGES[@]}"; do
    echo ""
    echo "--- Scanning $img ---"
    # Lanzamos trivy en un container efimero (--rm) montando el socket de Docker
    # para que pueda inspeccionar imagenes locales sin tirarlas a un registry.
    # El scan reporta CVEs HIGH y CRITICAL de cada imagen del proyecto
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy:latest image --severity HIGH,CRITICAL "$img" || echo "WARN: Trivy fallo para $img"
done

# Kube-bench (CIS Kubernetes Benchmark)
# Audita el cluster contra el CIS Kubernetes Benchmark (best practices de la
# Center for Internet Security). Detecta config insegura: API server expuesto,
# kubelet sin auth, etc. --restart=Never = pod efimero que muere al terminar
echo ""
echo "=== [2/3] Kube-bench (CIS Kubernetes Benchmark) ==="
kubectl run --rm -it kube-bench \
    --image=aquasec/kube-bench:latest \
    --restart=Never \
    --namespace=monitoring \
    -- --version 1.24 || echo "WARN: kube-bench fallo o no disponible"

# Polaris (best practices check)
# Polaris (Fairwinds) revisa los manifiestos desplegados contra reglas de best
# practices: limits/requests definidos, runAsNonRoot, readOnlyRootFilesystem, etc.
# Complementa a kube-bench: kube-bench audita el cluster, Polaris audita los workloads
echo ""
echo "=== [3/3] Polaris (best practices check) ==="
kubectl run --rm -it polaris \
    --image=quay.io/fairwinds/polaris:latest \
    --restart=Never \
    --namespace=monitoring \
    -- polaris audit --audit-path / || echo "WARN: Polaris fallo o no disponible"

echo ""
echo "=== Auditoria completada ==="
