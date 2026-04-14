# Arquitectura — PassProtect

## Diagrama general

```
Cliente ─HTTPS─▶ Ingress Nginx ─▶ Vaultwarden ─▶ MariaDB-VW
                      │              │
                      └─▶ Keycloak ──┴─ OIDC (SSO)
                            │
                            └─▶ FreeIPA (LDAP federation, READ-ONLY)
                            │
                            └─▶ MariaDB-KC
```

## Capas Docker

```
ubuntu:22.04
  └── ubbase              (SSH hardening, gestion usuarios, sudo)
       └── ubseguridad    (auditoria puertos, log rotation, fail2ban-ready)
            ├── vaultwarden-corp:1.0.0  (multi-stage: vaultwarden/server:1.32.5)
            ├── keycloak-corp:1.0.0     (multi-stage: quay.io/keycloak/keycloak:24.0)
            ├── mariadb-corp:1.0.0      (multi-stage: mariadb:11.2)
            └── nginx-proxy-corp:1.0.0  (Nginx + ModSecurity + OWASP CRS)
```

## Namespaces Kubernetes

| Namespace | Componentes | Pod Security |
|---|---|---|
| vaultwarden | Vaultwarden, MariaDB-VW | restricted |
| auth | Keycloak, MariaDB-KC, FreeIPA | baseline |
| monitoring | CronJobs (audit, backup) | restricted |

## Flujo de autenticacion

1. Usuario accede a Vaultwarden
2. Vaultwarden redirige a Keycloak (OIDC)
3. Keycloak autentica contra FreeIPA (LDAP)
4. Usuario introduce 2FA (TOTP)
5. Keycloak emite token OIDC
6. Vaultwarden valida token y da acceso

## Red

- **frontend**: Nginx (unico punto de entrada)
- **backend**: Vaultwarden, Keycloak (comunicacion interna)
- **database**: MariaDB (internal: true, no accesible desde fuera)

## Almacenamiento

| PVC | Tamaño | Uso |
|---|---|---|
| vaultwarden-data | 5Gi | Datos y attachments |
| mariadb-vw | 10Gi | Base de datos VW |
| mariadb-kc | 5Gi | Base de datos KC |
| freeipa-data | 5Gi | Datos LDAP |
| backup-storage | 20Gi | Backups diarios |
