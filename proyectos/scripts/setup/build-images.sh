#!/bin/bash
# ============================================================
# build-images.sh — Build y push capa por capa a Docker Hub
# Orden: ubbasse -> ubseguridadd -> servicios
# ============================================================
set -euo pipefail

REGISTRY="${REGISTRY:-dsegura97}"
VERSION="${VERSION:-1.0.0}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
err()  { echo -e "${RED}[!]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_DIR"

echo ""
echo "=================================================="
echo "  Build + Push - Capa por capa"
echo "  Registry: ${REGISTRY}"
echo "  Version:  ${VERSION}"
echo "  Root:     ${PROJECT_DIR}"
echo "=================================================="
echo ""

command -v docker >/dev/null || err "Docker no esta instalado"
docker info >/dev/null 2>&1 || err "Docker daemon no esta corriendo"

if ! docker info 2>/dev/null | grep -q "Username:"; then
    warn "No hay sesion activa en Docker Hub"
    log "Ejecuta: docker login"
    read -r -p "Continuar intentando login ahora? (y/N): " DO_LOGIN
    if [[ "$DO_LOGIN" =~ ^[Yy]$ ]]; then
        docker login
    else
        err "Necesitas hacer login primero"
    fi
fi
ok "Docker listo, sesion activa"

build_push() {
    local name="$1"
    local dockerfile="$2"

    if [ ! -f "$dockerfile" ]; then
        err "Dockerfile no encontrado: $dockerfile"
    fi

    log "Building ${REGISTRY}/${name}:${VERSION}..."
    docker build \
        -t "${REGISTRY}/${name}:${VERSION}" \
        -t "${REGISTRY}/${name}:latest" \
        -f "$dockerfile" .
    ok "${name} construida"

    log "Pushing ${name}..."
    docker push "${REGISTRY}/${name}:${VERSION}"
    docker push "${REGISTRY}/${name}:latest"
    ok "${name} publicada"
}

echo ""
log "==== FASE 1/3: ubbasse ===="
build_push "ubbasse" "dockerfiles/base/Dockerfile"

echo ""
log "==== FASE 2/3: ubseguridadd ===="
build_push "ubseguridadd" "dockerfiles/seguridad/Dockerfile"

echo ""
log "==== FASE 3/3: Servicios custom ===="

SERVICES=(
    "vaultwarden-corp:dockerfiles/vaultwarden/Dockerfile"
    "keycloak-corp:dockerfiles/keycloak/Dockerfile"
    "postgres-corp:dockerfiles/postgres/Dockerfile"
    "nginx-proxy-corp:dockerfiles/nginx-proxy/Dockerfile"
    "dashboard-corp:dockerfiles/dashboard/Dockerfile"
    "openldap-corp:dockerfiles/openldap/Dockerfile"
)

for svc in "${SERVICES[@]}"; do
    name="${svc%%:*}"
    dockerfile="${svc##*:}"

    if [ ! -f "$dockerfile" ]; then
        warn "Dockerfile no encontrado: $dockerfile (saltando)"
        continue
    fi

    build_push "$name" "$dockerfile"
done

echo ""
echo "=================================================="
echo "  Imagenes publicadas en Docker Hub"
echo "=================================================="
docker images | grep "${REGISTRY}" || true
echo "=================================================="
echo ""
log "Ver online: https://hub.docker.com/u/${REGISTRY}"
log "Siguiente: ./scripts/setup/deploy.sh (en el Contabo)"
