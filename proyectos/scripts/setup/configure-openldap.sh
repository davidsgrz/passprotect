#!/bin/bash
# configure-openldap.sh — Aplica los LDIFs de bootstrap y verifica el arbol LDAP
# Sustituye a configure-freeipa.sh (ya no usamos ipa-* ni kinit/krb5)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"
LDIF_FILE="$PROJECT_DIR/dockerfiles/openldap/bootstrap/01-users.ldif"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra $CONFIG_FILE"
    echo "Ejecuta primero: bash $SCRIPT_DIR/generate-secrets.sh"
    exit 1
fi

if [ ! -f "$LDIF_FILE" ]; then
    echo "ERROR: No se encuentra $LDIF_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Namespace y Pod del OpenLDAP
NAMESPACE="auth"
BASE_DN="dc=corp,dc=local"
BIND_DN="cn=admin,${BASE_DN}"

echo "=== PassProtect — Configuracion de OpenLDAP ==="
echo "Base DN: ${BASE_DN}"
echo "Bind DN: ${BIND_DN}"

# Comprobar kubectl (acepta kubectl o microk8s.kubectl)
KUBECTL=$(command -v kubectl || command -v microk8s.kubectl || true)
if [ -z "$KUBECTL" ]; then
    echo "ERROR: No se encuentra kubectl ni microk8s.kubectl"
    exit 1
fi

# Localizar el pod de OpenLDAP
echo "[1/5] Buscando pod de OpenLDAP..."
POD=$("$KUBECTL" get pods -n "$NAMESPACE" -l app=openldap -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$POD" ]; then
    echo "ERROR: No hay pod de OpenLDAP en namespace $NAMESPACE"
    echo "       Comprueba: $KUBECTL get pods -n $NAMESPACE"
    exit 1
fi
echo "Pod encontrado: $POD"

# Esperar a que el pod este Ready
echo "[2/5] Esperando a que OpenLDAP este Ready..."
"$KUBECTL" wait --for=condition=Ready "pod/$POD" -n "$NAMESPACE" --timeout=180s

# Copiar el LDIF al pod
echo "[3/5] Copiando LDIF de bootstrap al pod..."
"$KUBECTL" cp "$LDIF_FILE" "$NAMESPACE/$POD:/tmp/01-users.ldif"

# Aplicar el LDIF con ldapadd
# NOTA: si los LDIFs ya se cargaron automaticamente en el primer arranque
# (via /container/service/slapd/assets/config/bootstrap/ldif/custom/),
# ldapadd devolvera "Already exists" (codigo 68) — lo ignoramos.
echo "[4/5] Aplicando LDIF de bootstrap..."
"$KUBECTL" exec -n "$NAMESPACE" "$POD" -- bash -c "
    ldapadd -x -H ldap://localhost:389 \
        -D '${BIND_DN}' \
        -w '${LDAP_ADMIN_PASSWORD}' \
        -f /tmp/01-users.ldif -c 2>&1 | grep -v 'Already exists' || true
"

# Verificar con ldapsearch
echo "[5/5] Verificando arbol LDAP..."
echo ""
echo "─── Usuarios en ou=people ───"
"$KUBECTL" exec -n "$NAMESPACE" "$POD" -- \
    ldapsearch -x -H ldap://localhost:389 \
        -D "${BIND_DN}" \
        -w "${LDAP_ADMIN_PASSWORD}" \
        -b "ou=people,${BASE_DN}" \
        -s one \
        "(objectClass=inetOrgPerson)" \
        uid cn mail | grep -E "^uid:|^cn:|^mail:" || true

echo ""
echo "─── Grupos en ou=groups ───"
"$KUBECTL" exec -n "$NAMESPACE" "$POD" -- \
    ldapsearch -x -H ldap://localhost:389 \
        -D "${BIND_DN}" \
        -w "${LDAP_ADMIN_PASSWORD}" \
        -b "ou=groups,${BASE_DN}" \
        -s one \
        "(objectClass=groupOfNames)" \
        cn description | grep -E "^cn:|^description:" || true

echo ""
echo "─── Cuentas de servicio en ou=services ───"
"$KUBECTL" exec -n "$NAMESPACE" "$POD" -- \
    ldapsearch -x -H ldap://localhost:389 \
        -D "${BIND_DN}" \
        -w "${LDAP_ADMIN_PASSWORD}" \
        -b "ou=services,${BASE_DN}" \
        -s one \
        "(objectClass=inetOrgPerson)" \
        uid cn | grep -E "^uid:|^cn:" || true

echo ""
echo "=== OpenLDAP configurado ==="
echo "Base DN:  ${BASE_DN}"
echo "Admin:    ${BIND_DN}"
echo "Password: (almacenado en secret openldap-secrets)"
echo ""
echo "Pass temporal de los usuarios: TempPass123!"
echo "(cambiala en primera sesion via Keycloak)"
echo ""
echo "Siguiente paso: bash $SCRIPT_DIR/verify-deployment.sh"
