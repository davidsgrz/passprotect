# Arquitectura — PassProtect

## Diagrama general

```
Cliente ─HTTPS─▶ Ingress Nginx ─▶ Vaultwarden ─▶ MariaDB-VW
                      │              │
                      └─▶ Keycloak ──┴─ OIDC (SSO)
                            │
                            └─▶ OpenLDAP (LDAP federation, READ-ONLY)
                            │       dc=corp,dc=local
                            │
                            └─▶ MariaDB-KC
```

## Capas Docker

```
ubuntu:24.04
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
| auth | Keycloak, MariaDB-KC, OpenLDAP | baseline |
| monitoring | CronJobs (audit, backup) | restricted |

## Flujo de autenticacion

1. Usuario accede a Vaultwarden
2. Vaultwarden redirige a Keycloak (OIDC)
3. Keycloak autentica contra OpenLDAP (ou=people,dc=corp,dc=local)
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
| openldap-data | 2Gi | Datos LDAP (DIT) |
| openldap-config | 512Mi | Config slapd.d (cn=config) |
| backup-storage | 20Gi | Backups diarios |

## Identidad: por que OpenLDAP y no FreeIPA

En fase de diseño se evaluo FreeIPA (`freeipa/freeipa-server:fedora-40`) como
servidor de identidad. Tras la primera iteracion de despliegue se decidio migrar
a OpenLDAP (`osixia/openldap:1.5.0`) por las siguientes razones:

### Problemas bloqueantes de FreeIPA en Kubernetes

| Requisito FreeIPA | Impacto |
|---|---|
| `privileged: true` | Incompatible con PSS `restricted` y `baseline` |
| `capabilities: [SYS_ADMIN, NET_ADMIN, SYS_TIME]` | Capacidades elevadas no permitidas |
| systemd + D-Bus en el contenedor | Requiere `--cgroupns=host` y init system completo |
| Imagen `fedora-40` | Tags inestables, `unmanifest` tras actualizaciones |
| ipa-server + KDC + BIND + Dogtag CA | Monolito con ~6 servicios acoplados |

### Ventajas de OpenLDAP

| Beneficio | Detalle |
|---|---|
| Compatible con PSS `baseline` | Solo necesita `CHOWN, DAC_OVERRIDE, NET_BIND_SERVICE` |
| Sin systemd | Un solo proceso: `slapd` |
| Menor superficie de ataque | LDAP puro; sin Kerberos, DNS ni CA integrados |
| Imagen estable | `osixia/openldap:1.5.0` con tag pineado |
| Bootstrap declarativo | LDIFs en `dockerfiles/openldap/bootstrap/` |
| TLS nativo | Certificados auto-firmados generados en primer arranque |

### Coste funcional aceptado

- **Kerberos**: No disponible → sustituido por OIDC/TOTP via Keycloak
- **DNS dinamico**: No necesario → MicroK8s usa CoreDNS
- **CA integrada**: No necesaria → cert-manager + Let's Encrypt para el borde

La federation LDAP con Keycloak (READ-ONLY) aporta el mismo valor academico
(cuentas centralizadas, grupos de autorizacion, SSO) con un modelo de despliegue
cloud-native.
