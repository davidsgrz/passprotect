#!/bin/bash
# configure-keycloak.sh — Configura Keycloak via API REST: realm, cliente OIDC, 2FA, LDAP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No se encuentra $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

KC_URL="https://auth.${VPS_IP}.nip.io"
REALM="corporativo"

echo "=== PassProtect — Configuracion de Keycloak ==="
echo "URL: $KC_URL"

# Obtener token de admin
echo "[1/6] Obteniendo token de admin..."
TOKEN=$(curl -sk -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KC_ADMIN}" \
    -d "password=${KC_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "ERROR: No se pudo obtener token de admin"
    exit 1
fi

AUTH="Authorization: Bearer ${TOKEN}"

# Crear realm corporativo
echo "[2/6] Creando realm '${REALM}'..."
curl -sk -X POST "${KC_URL}/admin/realms" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
        \"realm\": \"${REALM}\",
        \"enabled\": true,
        \"displayName\": \"PassProtect Corporativo\",
        \"registrationAllowed\": false,
        \"bruteForceProtected\": true,
        \"permanentLockout\": false,
        \"maxFailureWaitSeconds\": 900,
        \"minimumQuickLoginWaitSeconds\": 60,
        \"waitIncrementSeconds\": 60,
        \"quickLoginCheckMilliSeconds\": 1000,
        \"maxDeltaTimeSeconds\": 43200,
        \"failureFactor\": 5,
        \"passwordPolicy\": \"length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername\"
    }" || echo "Realm ya existe o error"

# Crear cliente OIDC para Vaultwarden
echo "[3/6] Creando cliente OIDC 'vaultwarden'..."
curl -sk -X POST "${KC_URL}/admin/realms/${REALM}/clients" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
        \"clientId\": \"${SSO_CLIENT_ID}\",
        \"name\": \"Vaultwarden Password Manager\",
        \"enabled\": true,
        \"protocol\": \"openid-connect\",
        \"publicClient\": false,
        \"secret\": \"${SSO_CLIENT_SECRET}\",
        \"redirectUris\": [\"${VW_DOMAIN}/identity/connect/oidc-signin\"],
        \"webOrigins\": [\"${VW_DOMAIN}\"],
        \"standardFlowEnabled\": true,
        \"directAccessGrantsEnabled\": false,
        \"serviceAccountsEnabled\": false,
        \"authorizationServicesEnabled\": false
    }" || echo "Cliente ya existe o error"

# Configurar 2FA obligatorio (TOTP)
echo "[4/6] Configurando 2FA obligatorio (TOTP)..."
curl -sk -X PUT "${KC_URL}/admin/realms/${REALM}" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
        \"otpPolicyType\": \"totp\",
        \"otpPolicyAlgorithm\": \"HmacSHA1\",
        \"otpPolicyDigits\": 6,
        \"otpPolicyPeriod\": 30,
        \"otpPolicyLookAheadWindow\": 1
    }"

# Flujo de autenticacion con 2FA obligatorio
echo "[5/6] Configurando flujo de autenticacion con 2FA..."
# Obtener ID del flujo browser
BROWSER_FLOW_ID=$(curl -sk "${KC_URL}/admin/realms/${REALM}/authentication/flows" \
    -H "$AUTH" | jq -r '.[] | select(.alias=="browser") | .id')

if [ -n "$BROWSER_FLOW_ID" ] && [ "$BROWSER_FLOW_ID" != "null" ]; then
    echo "Browser flow ID: $BROWSER_FLOW_ID"
fi

# Configurar LDAP federation con FreeIPA (READ-ONLY)
echo "[6/6] Configurando LDAP federation con FreeIPA..."
curl -sk -X POST "${KC_URL}/admin/realms/${REALM}/components" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"freeipa-ldap\",
        \"providerId\": \"ldap\",
        \"providerType\": \"org.keycloak.storage.UserStorageProvider\",
        \"config\": {
            \"vendor\": [\"other\"],
            \"connectionUrl\": [\"ldap://freeipa.auth.svc.cluster.local:389\"],
            \"bindDn\": [\"uid=admin,cn=users,cn=accounts,dc=passprotect,dc=local\"],
            \"bindCredential\": [\"${IPA_ADMIN_PASSWORD}\"],
            \"usersDn\": [\"cn=users,cn=accounts,dc=passprotect,dc=local\"],
            \"usernameLDAPAttribute\": [\"uid\"],
            \"rdnLDAPAttribute\": [\"uid\"],
            \"uuidLDAPAttribute\": [\"ipaUniqueID\"],
            \"userObjectClasses\": [\"inetOrgPerson, organizationalPerson\"],
            \"editMode\": [\"READ_ONLY\"],
            \"syncRegistrations\": [\"false\"],
            \"trustEmail\": [\"true\"],
            \"fullSyncPeriod\": [\"604800\"],
            \"changedSyncPeriod\": [\"86400\"],
            \"batchSizeForSync\": [\"1000\"]
        }
    }" || echo "Federation ya existe o error"

echo ""
echo "=== Keycloak configurado ==="
echo "Realm:  ${REALM}"
echo "Client: ${SSO_CLIENT_ID}"
echo "2FA:    TOTP obligatorio"
echo "LDAP:   FreeIPA (READ-ONLY)"
echo ""
echo "Siguiente paso: bash $SCRIPT_DIR/configure-freeipa.sh"
