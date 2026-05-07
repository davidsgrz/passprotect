# Threat Model y Mitigaciones — PassProtect

## Vectores de ataque considerados

### 1. SQL Injection
**Mitigaciones**:
- PostgreSQL 16 con `password_encryption=scram-sha-256`
- `REVOKE ALL ON DATABASE postgres FROM PUBLIC` (init-security.sql)
- `REVOKE CREATE ON SCHEMA public FROM PUBLIC` (privilegio minimo)
- ModSecurity + OWASP CRS en nginx-ingress (reglas 942xxx)
- Fail2ban jail planeado para nginx-modsec (24h ban tras 3 disparos)
- Vaultwarden y Keycloak usan ORM/queries parametrizadas (no concatenacion)

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
- PostgreSQL max_connections=40 (postgresql.conf hardened para VPS 4GB)
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
Capa 6 (DB):       PostgreSQL 16 hardened (SCRAM-SHA-256, schema public revoked)
Capa 7 (Container):Pod Security Standards + non-root + read-only FS
Capa 8 (Audit):    Logs + Keycloak Events (User+Admin) + dashboard SOC + Trivy
```

## Herramientas de auditoria incluidas

| Herramienta | Proposito | Ubicacion |
|---|---|---|
| security-audit.sh | Ejecuta Trivy, kube-bench y Polaris | scripts/setup/ |
| Fail2ban | Banea IPs automaticamente (jail sshd activo en host) | host VPS |
| ModSecurity + OWASP CRS | WAF en nginx-ingress (modo DetectionOnly) | nginx-ingress controller |
| Dashboard SOC | Panel consolidado de pentesting | dashboard.passprotect.es |

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
