# Threat Model y Mitigaciones — PassProtect

## Vectores de ataque considerados

### 1. SQL Injection
**Mitigaciones**:
- MariaDB en modo STRICT con sql_mode hardened
- `local_infile=0` (bloquea file reads)
- ModSecurity + OWASP CRS en Nginx
- Detector Python (`sql-injection-detector.py`) analiza logs
- Fail2ban jail que banea IPs con intentos SQLi (1 intento = 24h ban)
- Privilegios minimos para usuarios de aplicacion (REVOKE FILE, SUPER, PROCESS)
- Charset UTF8MB4 (evita bugs de encoding)
- `skip_federated` en MariaDB (previene SSRF via SQL)

### 2. XSS (Cross-Site Scripting)
**Mitigaciones**:
- CSP restrictivo en headers Nginx
- X-XSS-Protection header
- X-Content-Type-Options: nosniff
- Vaultwarden ya tiene CSP propio

### 3. CSRF (Cross-Site Request Forgery)
**Mitigaciones**:
- Vaultwarden usa tokens CSRF nativos
- SameSite=Strict en cookies
- Referrer-Policy strict-origin-when-cross-origin

### 4. SSRF (Server-Side Request Forgery)
**Mitigaciones**:
- NetworkPolicies K8s restringen egress
- `skip_federated` en MariaDB
- Nginx no permite `proxy_pass` dinamico

### 5. Path Traversal
**Mitigaciones**:
- ModSecurity CRS rules 930xxx
- `readOnlyRootFilesystem: true` en K8s
- Nginx bloquea paths sensibles (`.env`, `.git`, etc.)

### 6. Command Injection
**Mitigaciones**:
- ModSecurity CRS rules 932xxx
- Vaultwarden no ejecuta comandos shell con input del usuario
- `allowPrivilegeEscalation: false` en todos los pods

### 7. Brute Force
**Mitigaciones**:
- Rate limiting Nginx (5 req/s login, 2 req/s admin)
- Fail2ban (5 intentos / 1h ban)
- Keycloak bruteForceProtected=true (5 fallos = lockout)
- 2FA obligatorio (TOTP) en Keycloak

### 8. Credential Stuffing
**Mitigaciones**:
- Detector en `audit.py` (>=5 usuarios distintos desde misma IP = alerta HIGH)
- Politica de contraseñas Keycloak (12 chars + complejidad)

### 9. DoS / Resource Exhaustion
**Mitigaciones**:
- ResourceQuotas K8s por namespace
- LimitRanges en pods
- Rate limiting Nginx
- MariaDB max_connections limitado (200 global, 50 por usuario)
- JVM heap limitado en Keycloak (-Xmx1024m)
- client_max_body_size 128M en Nginx

### 10. Privilege Escalation
**Mitigaciones**:
- Pod Security Standards (restricted/baseline)
- `runAsNonRoot: true`
- `capabilities: drop: [ALL]`
- `allowPrivilegeEscalation: false`
- seccompProfile: RuntimeDefault
- RBAC con ServiceAccounts sin permisos elevados (automountServiceAccountToken: false)
- NetworkPolicies deny-all por defecto + allow especifico

### 11. Supply Chain Attacks
**Mitigaciones**:
- Imagenes con pinning de version (no `latest` en produccion)
- Trivy scan en CI (script `security-audit.sh`)
- Multi-stage builds para minimizar superficie de ataque
- Usuarios no-root en todas las imagenes custom

### 12. Data Exfiltration
**Mitigaciones**:
- NetworkPolicies K8s egress filtering
- Backup diario a las 3 AM con retencion 30 dias
- Logs centralizados en /root/logs con rotacion 5MB
- Auditoria Python detecta horarios anomalos (00:00-06:00)

## Arquitectura de seguridad por capas

```
Capa 1 (Red):      UFW + NetworkPolicies K8s
Capa 2 (WAF):      Nginx + ModSecurity + OWASP CRS
Capa 3 (Rate):     Rate limiting Nginx + Fail2ban
Capa 4 (Auth):     Keycloak OIDC + 2FA TOTP + OpenLDAP (READ-ONLY)
Capa 5 (App):      Vaultwarden (signups disabled, admin token)
Capa 6 (DB):       MariaDB hardened (STRICT mode, local_infile=0)
Capa 7 (Container):Pod Security Standards + non-root + read-only FS
Capa 8 (Audit):    Logs + audit.py + sql-injection-detector.py
```

## Herramientas de auditoria incluidas

| Herramienta | Proposito | Ubicacion |
|---|---|---|
| audit.py | Detecta brute force, credential stuffing, horarios anomalos | scripts/audit/ |
| sql-injection-detector.py | Analiza logs MariaDB buscando patrones SQLi | scripts/audit/ |
| security-audit.sh | Ejecuta Trivy, kube-bench y Polaris | scripts/setup/ |
| Fail2ban | Banea IPs automaticamente | fail2ban/ |
| ModSecurity | WAF con reglas OWASP CRS | docker/kube/nginx-proxy/modsec/ |

## Reduccion de superficie: migracion FreeIPA -> OpenLDAP

La sustitucion de FreeIPA por OpenLDAP reduce la superficie de ataque en el
namespace `auth`:

| Vector | FreeIPA | OpenLDAP |
|---|---|---|
| Privileged container | Si (requerido) | No |
| Capabilities elevadas | SYS_ADMIN, NET_ADMIN, SYS_TIME | Solo CHOWN, DAC_OVERRIDE, NET_BIND_SERVICE |
| Puertos expuestos | 80, 443, 389, 636, 88 (Kerberos), 464 | 389, 636 |
| Servicios internos | slapd + KDC + BIND + Dogtag CA + httpd | slapd |
| systemd en contenedor | Si | No |
| Pod Security Standard | No soporta `baseline` | Compatible con `baseline` |

Ver `docs/ARCHITECTURE.md` seccion "Identidad" para la justificacion completa.
