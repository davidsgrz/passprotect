#!/bin/bash
# configure-freeipa.sh — Configura FreeIPA: usuarios y grupos iniciales
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

echo "=== PassProtect — Configuracion de FreeIPA ==="

# Obtener el pod de FreeIPA
IPA_POD=$(kubectl get pods -n auth -l app=freeipa -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$IPA_POD" ]; then
    echo "ERROR: Pod de FreeIPA no encontrado"
    exit 1
fi

echo "Pod FreeIPA: $IPA_POD"

# Funcion para ejecutar comandos en el pod FreeIPA
ipa_exec() {
    kubectl exec -n auth "$IPA_POD" -- bash -c "$1"
}

# Obtener ticket Kerberos
echo "[1/4] Autenticando con Kerberos..."
ipa_exec "echo '${IPA_ADMIN_PASSWORD}' | kinit admin"

# Crear grupos
echo "[2/4] Creando grupos..."
ipa_exec "ipa group-add passprotect-admins --desc='Administradores PassProtect'" || echo "Grupo ya existe"
ipa_exec "ipa group-add passprotect-users --desc='Usuarios PassProtect'" || echo "Grupo ya existe"
ipa_exec "ipa group-add passprotect-readonly --desc='Usuarios solo lectura'" || echo "Grupo ya existe"

# Crear usuarios de ejemplo
echo "[3/4] Creando usuarios de ejemplo..."
ipa_exec "ipa user-add dsegura --first=David --last=Segura --email=dsegura@passprotect.local --password <<< $'Passw0rd!2026\nPassw0rd!2026'" || echo "Usuario ya existe"
ipa_exec "ipa user-add fparra --first=Francisco --last=Parra --email=fparra@passprotect.local --password <<< $'Passw0rd!2026\nPassw0rd!2026'" || echo "Usuario ya existe"

# Asignar usuarios a grupos
echo "[4/4] Asignando usuarios a grupos..."
ipa_exec "ipa group-add-member passprotect-admins --users=dsegura" || true
ipa_exec "ipa group-add-member passprotect-admins --users=fparra" || true
ipa_exec "ipa group-add-member passprotect-users --users=dsegura" || true
ipa_exec "ipa group-add-member passprotect-users --users=fparra" || true

echo ""
echo "=== FreeIPA configurado ==="
echo "Grupos: passprotect-admins, passprotect-users, passprotect-readonly"
echo "Usuarios: dsegura, fparra"
echo ""
echo "Siguiente paso: bash $SCRIPT_DIR/verify-deployment.sh"
