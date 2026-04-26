#!/bin/bash
# configure-keycloak.sh - Configura Keycloak via API REST de forma idempotente.
#
# Crea/actualiza:
#   - Realm "corporativo" con bruteForceProtected y password policy
#   - Cliente OIDC "vaultwarden" con PKCE S256
#   - LDAP federation contra OpenLDAP (READ_ONLY, bind como svc-keycloak-bind)
#   - Group LDAP mapper (groupOfNames -> grupos Keycloak)
#   - Sync de usuarios + grupos
#   - 2FA TOTP obligatorio (CONFIGURE_TOTP defaultAction + Browser flow OTP REQUIRED)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config.env"

[ -f "$CONFIG_FILE" ] || { echo "ERROR: No existe $CONFIG_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

KC_URL="${KC_URL:-https://auth.passprotect.es}"
REALM="corporativo"

# LDAP federation: bind con cuenta de servicio dedicada (least privilege).
# Password = TempPass123! (post-install reset) - rotar en produccion.
LDAP_URL="ldap://openldap.auth.svc.cluster.local:389"
LDAP_BIND_DN="uid=svc-keycloak-bind,ou=services,dc=corp,dc=local"
LDAP_BIND_PASS="${LDAP_BIND_PASSWORD:-TempPass123!}"
LDAP_USERS_DN="ou=people,dc=corp,dc=local"
LDAP_GROUPS_DN="ou=groups,dc=corp,dc=local"

VW_REDIRECT="${VW_DOMAIN}/identity/connect/oidc-signin"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "ERROR: $*" >&2; exit 1; }

TOKEN=""
get_token() {
  # IMPORTANTE: --data-urlencode (no -d) porque el password puede contener
  # caracteres como '+' o '=' (base64) que en application/x-www-form-urlencoded
  # se reinterpretan como espacios -> "Invalid user credentials" silencioso.
  TOKEN=$(curl -sk -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "username=${KC_ADMIN}" \
    --data-urlencode "password=${KC_ADMIN_PASSWORD}" \
    --data-urlencode "grant_type=password" | jq -r '.access_token')
  [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || err "No se pudo obtener token admin"
}

# api METHOD PATH [JSON_BODY]
api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sk -X "$method" "${KC_URL}/admin${path}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -sk -X "$method" "${KC_URL}/admin${path}" \
      -H "Authorization: Bearer ${TOKEN}"
  fi
}

# api_status METHOD PATH [JSON_BODY] -> imprime HTTP status code
api_status() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sk -o /dev/null -w "%{http_code}" -X "$method" "${KC_URL}/admin${path}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -sk -o /dev/null -w "%{http_code}" -X "$method" "${KC_URL}/admin${path}" \
      -H "Authorization: Bearer ${TOKEN}"
  fi
}

# === 1. Realm corporativo ===
create_realm() {
  log "[1/6] Realm '$REALM'"
  local code
  code=$(api_status GET "/realms/${REALM}")
  local payload
  payload=$(cat <<JSON
{
  "realm": "${REALM}",
  "enabled": true,
  "displayName": "PassProtect",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "rememberMe": true,
  "verifyEmail": false,
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 5,
  "passwordPolicy": "length(12) and digits(1) and upperCase(1) and lowerCase(1) and specialChars(1) and notUsername and passwordHistory(3)",
  "otpPolicyType": "totp",
  "otpPolicyAlgorithm": "HmacSHA1",
  "otpPolicyDigits": 6,
  "otpPolicyPeriod": 30,
  "otpPolicyLookAheadWindow": 1,
  "sslRequired": "external",
  "defaultLocale": "es",
  "internationalizationEnabled": true,
  "supportedLocales": ["es", "en"]
}
JSON
)
  if [ "$code" = "200" ]; then
    log "  Existe -> PUT (idempotente)"
    api PUT "/realms/${REALM}" "$payload" >/dev/null
  else
    log "  No existe -> POST"
    code=$(api_status POST "/realms" "$payload")
    [ "$code" = "201" ] || err "Crear realm devolvio HTTP $code"
  fi
}

# === 2. Cliente OIDC vaultwarden ===
create_client() {
  log "[2/6] Cliente OIDC '${SSO_CLIENT_ID}'"
  local existing
  existing=$(api GET "/realms/${REALM}/clients?clientId=${SSO_CLIENT_ID}" | jq -r '.[0].id // empty')
  local payload
  payload=$(cat <<JSON
{
  "clientId": "${SSO_CLIENT_ID}",
  "name": "Vaultwarden Password Manager",
  "description": "Cliente OIDC para Vaultwarden con PKCE",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": false,
  "secret": "${SSO_CLIENT_SECRET}",
  "redirectUris": ["${VW_REDIRECT}", "${VW_DOMAIN}/*"],
  "webOrigins": ["${VW_DOMAIN}"],
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "frontchannelLogout": true,
  "fullScopeAllowed": true,
  "attributes": {
    "pkce.code.challenge.method": "S256",
    "post.logout.redirect.uris": "+",
    "access.token.lifespan": "3600",
    "client.session.idle.timeout": "1800"
  }
}
JSON
)
  if [ -n "$existing" ]; then
    log "  Existe (id=$existing) -> PUT"
    api PUT "/realms/${REALM}/clients/${existing}" "$payload" >/dev/null
  else
    log "  No existe -> POST"
    local code
    code=$(api_status POST "/realms/${REALM}/clients" "$payload")
    [ "$code" = "201" ] || err "Crear cliente devolvio HTTP $code"
  fi
}

# === 2b. Cliente OIDC dashboard (oauth2-proxy) ===
# Cliente confidential con PKCE para que oauth2-proxy proteja el dashboard.
# Skip si no esta definido DASHBOARD_SSO_CLIENT_SECRET (oauth2Proxy desactivado).
create_dashboard_client() {
  if [ -z "${DASHBOARD_SSO_CLIENT_SECRET:-}" ]; then
    log "[2b/6] Cliente 'dashboard' SKIPPED (DASHBOARD_SSO_CLIENT_SECRET no definido)"
    return 0
  fi
  local DASH_DOMAIN="${DASHBOARD_DOMAIN:-https://dashboard.passprotect.es}"
  # Asegurar prefijo https://
  case "$DASH_DOMAIN" in
    https://*) ;;
    http://*) ;;
    *) DASH_DOMAIN="https://${DASH_DOMAIN}" ;;
  esac
  log "[2b/6] Cliente OIDC 'dashboard' (oauth2-proxy)"
  local existing
  existing=$(api GET "/realms/${REALM}/clients?clientId=dashboard" | jq -r '.[0].id // empty')
  local payload
  payload=$(cat <<JSON
{
  "clientId": "dashboard",
  "name": "Dashboard PassProtect (oauth2-proxy)",
  "description": "Cliente OIDC para proteger el dashboard via oauth2-proxy",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": false,
  "secret": "${DASHBOARD_SSO_CLIENT_SECRET}",
  "redirectUris": ["${DASH_DOMAIN}/oauth2/callback"],
  "webOrigins": ["${DASH_DOMAIN}"],
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "frontchannelLogout": true,
  "fullScopeAllowed": true,
  "attributes": {
    "pkce.code.challenge.method": "S256",
    "post.logout.redirect.uris": "+",
    "access.token.lifespan": "3600",
    "client.session.idle.timeout": "1800"
  }
}
JSON
)
  local client_uuid
  if [ -n "$existing" ]; then
    log "  Existe (id=$existing) -> PUT"
    api PUT "/realms/${REALM}/clients/${existing}" "$payload" >/dev/null
    client_uuid="$existing"
  else
    log "  No existe -> POST"
    local code
    code=$(api_status POST "/realms/${REALM}/clients" "$payload")
    [ "$code" = "201" ] || err "Crear cliente dashboard devolvio HTTP $code"
    client_uuid=$(api GET "/realms/${REALM}/clients?clientId=dashboard" | jq -r '.[0].id // empty')
  fi

  # Audience Mapper: por default Keycloak emite aud=[account] en el ID token,
  # pero oauth2-proxy valida que aud contenga su propio client_id (dashboard).
  # Sin este mapper -> "audience from claim aud does not match" -> HTTP 500
  # en /oauth2/callback.
  log "  Audience Mapper (aud: dashboard)"
  local mapper_existing
  mapper_existing=$(api GET "/realms/${REALM}/clients/${client_uuid}/protocol-mappers/models" \
    | jq -r '.[] | select(.name=="dashboard-audience") | .id // empty')
  local mapper_payload
  mapper_payload=$(cat <<JSON
{
  "name": "dashboard-audience",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-audience-mapper",
  "config": {
    "included.client.audience": "dashboard",
    "id.token.claim": "true",
    "access.token.claim": "true",
    "introspection.token.claim": "true"
  }
}
JSON
)
  if [ -n "$mapper_existing" ]; then
    log "    mapper existe -> PUT"
    api PUT "/realms/${REALM}/clients/${client_uuid}/protocol-mappers/models/${mapper_existing}" "$mapper_payload" >/dev/null
  else
    log "    mapper no existe -> POST"
    local mc
    mc=$(api_status POST "/realms/${REALM}/clients/${client_uuid}/protocol-mappers/models" "$mapper_payload")
    [ "$mc" = "201" ] || err "Crear audience mapper devolvio HTTP $mc"
  fi
}

# === 3. LDAP federation ===
# Devuelve el ID del componente de federation por stdout.
create_ldap_federation() {
  # IMPORTANTE: TODOS los logs aqui van a stderr (>&2) porque el stdout
  # de esta funcion captura el UUID del componente para el caller.
  log "[3/6] LDAP federation -> $LDAP_URL" >&2
  local existing
  existing=$(api GET "/realms/${REALM}/components?type=org.keycloak.storage.UserStorageProvider" \
    | jq -r '.[] | select(.name=="openldap-federation") | .id // empty' )
  local payload
  payload=$(cat <<JSON
{
  "name": "openldap-federation",
  "providerId": "ldap",
  "providerType": "org.keycloak.storage.UserStorageProvider",
  "config": {
    "vendor": ["other"],
    "connectionUrl": ["${LDAP_URL}"],
    "bindDn": ["${LDAP_BIND_DN}"],
    "bindCredential": ["${LDAP_BIND_PASS}"],
    "usersDn": ["${LDAP_USERS_DN}"],
    "userObjectClasses": ["inetOrgPerson, organizationalPerson"],
    "usernameLDAPAttribute": ["uid"],
    "rdnLDAPAttribute": ["uid"],
    "uuidLDAPAttribute": ["entryUUID"],
    "editMode": ["READ_ONLY"],
    "importEnabled": ["true"],
    "syncRegistrations": ["false"],
    "searchScope": ["1"],
    "useTruststoreSpi": ["ldapsOnly"],
    "connectionPooling": ["true"],
    "pagination": ["true"],
    "fullSyncPeriod": ["3600"],
    "changedSyncPeriod": ["300"],
    "cachePolicy": ["DEFAULT"],
    "trustEmail": ["true"],
    "enabled": ["true"],
    "batchSizeForSync": ["1000"]
  }
}
JSON
)
  if [ -n "$existing" ]; then
    log "  Existe (id=$existing) -> PUT" >&2
    api PUT "/realms/${REALM}/components/${existing}" "$payload" >/dev/null
    echo "$existing"
  else
    log "  No existe -> POST" >&2
    local code
    code=$(api_status POST "/realms/${REALM}/components" "$payload")
    [ "$code" = "201" ] || err "Crear federation devolvio HTTP $code"
    sleep 1
    api GET "/realms/${REALM}/components?type=org.keycloak.storage.UserStorageProvider" \
      | jq -r '.[] | select(.name=="openldap-federation") | .id'
  fi
}

# === 4. Group LDAP mapper ===
create_group_mapper() {
  local fed_id="$1"
  log "[4/6] Group LDAP mapper"
  local existing
  existing=$(api GET "/realms/${REALM}/components?parent=${fed_id}" \
    | jq -r '.[] | select(.name=="group-mapper") | .id // empty' )
  local payload
  payload=$(cat <<JSON
{
  "name": "group-mapper",
  "providerId": "group-ldap-mapper",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "parentId": "${fed_id}",
  "config": {
    "groups.dn": ["${LDAP_GROUPS_DN}"],
    "group.name.ldap.attribute": ["cn"],
    "group.object.classes": ["groupOfNames"],
    "preserve.group.inheritance": ["false"],
    "membership.ldap.attribute": ["member"],
    "membership.attribute.type": ["DN"],
    "membership.user.ldap.attribute": ["uid"],
    "groups.ldap.filter": [""],
    "mode": ["READ_ONLY"],
    "user.roles.retrieve.strategy": ["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"],
    "drop.non.existing.groups.during.sync": ["false"],
    "groups.path": ["/"],
    "memberof.ldap.attribute": ["memberOf"]
  }
}
JSON
)
  if [ -n "$existing" ]; then
    log "  Existe (id=$existing) -> PUT"
    api PUT "/realms/${REALM}/components/${existing}" "$payload" >/dev/null
  else
    log "  No existe -> POST"
    local code
    code=$(api_status POST "/realms/${REALM}/components" "$payload")
    [ "$code" = "201" ] || err "Crear group mapper devolvio HTTP $code"
  fi
}

# === 5. Sync usuarios + grupos ===
sync_ldap() {
  local fed_id="$1"
  log "[5/6] Sync LDAP"

  log "  triggerFullSync usuarios..."
  api POST "/realms/${REALM}/user-storage/${fed_id}/sync?action=triggerFullSync" "" >/dev/null
  sleep 2

  local mapper_id
  mapper_id=$(api GET "/realms/${REALM}/components?parent=${fed_id}" \
    | jq -r '.[] | select(.name=="group-mapper") | .id' )
  if [ -n "$mapper_id" ]; then
    log "  sync group-mapper (fedToKeycloak)..."
    api POST "/realms/${REALM}/user-storage/${fed_id}/mappers/${mapper_id}/sync?direction=fedToKeycloak" "" >/dev/null
    sleep 2
  fi

  local count groups
  count=$(api GET "/realms/${REALM}/users/count")
  groups=$(api GET "/realms/${REALM}/groups" | jq -r '[.[].name] | join(", ")')
  log "  Usuarios importados: $count"
  log "  Grupos: $groups"
}

# === 6. Forzar 2FA TOTP en TODOS los usuarios ===
# Estrategia:
#   a) CONFIGURE_TOTP como defaultAction -> nuevos usuarios sin TOTP configuran
#      en primer login.
#   b) Buscar la execution OTP del browser flow y marcarla REQUIRED.
enforce_2fa() {
  log "[6/6] 2FA TOTP obligatorio"

  # a) CONFIGURE_TOTP defaultAction
  log "  CONFIGURE_TOTP defaultAction=true"
  api PUT "/realms/${REALM}/authentication/required-actions/CONFIGURE_TOTP" '{
    "alias": "CONFIGURE_TOTP",
    "name": "Configure OTP",
    "providerId": "CONFIGURE_TOTP",
    "enabled": true,
    "defaultAction": true,
    "priority": 10
  }' >/dev/null

  # b) Browser flow: marcar la execution con providerId auth-otp-form como REQUIRED
  local executions otp_json otp_id
  executions=$(api GET "/realms/${REALM}/authentication/flows/browser/executions")
  otp_json=$(echo "$executions" | jq '.[] | select(.providerId=="auth-otp-form")')
  otp_id=$(echo "$otp_json" | jq -r '.id // empty')

  if [ -n "$otp_id" ]; then
    log "  auth-otp-form encontrado, requirement=REQUIRED"
    local updated
    updated=$(echo "$otp_json" | jq '.requirement = "REQUIRED"')
    api PUT "/realms/${REALM}/authentication/flows/browser/executions" "$updated" >/dev/null
  else
    log "  WARN: no se encontro auth-otp-form en flow browser"
    log "  Buscar a mano si Keycloak >24 cambio el alias"
  fi
}

main() {
  log "=== configure-keycloak.sh ==="
  log "URL    : $KC_URL"
  log "Realm  : $REALM"
  log "Client : $SSO_CLIENT_ID"
  log "LDAP   : $LDAP_URL"
  log "BindDN : $LDAP_BIND_DN"
  echo ""

  curl -sk "${KC_URL}/realms/master/.well-known/openid-configuration" >/dev/null \
    || err "Keycloak no responde en $KC_URL"

  get_token
  log "Token admin OK"
  echo ""

  create_realm
  create_client
  create_dashboard_client
  local fed_id
  fed_id=$(create_ldap_federation)
  log "  Federation ID: $fed_id"
  create_group_mapper "$fed_id"
  sync_ldap "$fed_id"
  enforce_2fa

  echo ""
  log "=== Configurado ==="
  log "Realm:    ${KC_URL}/realms/${REALM}"
  log "Console:  ${KC_URL}/admin/${REALM}/console/"
  log "OIDC:     ${KC_URL}/realms/${REALM}/.well-known/openid-configuration"
}

main "$@"
