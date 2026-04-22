# PassProtect — Plataforma Corporativa de Gestion de Contraseñas

**Proyecto intermodular ASIR 2025-2026**

**Autores**: Francisco Parra Caparros & David Segura Rodriguez

## Descripcion

Plataforma de gestion de contraseñas corporativa basada en Vaultwarden con
autenticacion centralizada (Keycloak + OpenLDAP), desplegada sobre Kubernetes
(MicroK8s) en un VPS Contabo con hardening completo.

## Arquitectura

```
Cliente ─HTTPS─▶ Ingress Nginx ─▶ Vaultwarden ─▶ MariaDB
                      │              │
                      └─▶ Keycloak ──┴─ OIDC
                            │
                            └─▶ OpenLDAP (LDAP federation, READ-ONLY)
                                dc=corp,dc=local
```

## Capas Docker

```
ubuntu:24.04
  └── ubbase              (SSH hardening, gestion usuarios, sudo)
       └── ubseguridad    (auditoria puertos, log rotation, fail2ban-ready)
            ├── vaultwarden-corp:1.0.0
            ├── keycloak-corp:1.0.0
            ├── mariadb-corp:1.0.0   (hardened anti-SQLi)
            ├── nginx-proxy-corp:1.0.0 (ModSecurity + OWASP CRS)
            └── dashboard-corp:1.0.0   (panel de gestion)
```

## Estructura del repositorio

- `dockerfiles/` — Dockerfiles e imagenes custom
- `common/` — Recursos compartidos (claves SSH)
- `proyectos/` — Despliegue: compose, k8s, helm, scripts, docs
- `config.env` — Variables centrales (no se commitea)

## Despliegue rapido

```bash
# 1. Configurar variables
cp config.env.example config.env
nano config.env

# 2. Generar secretos
bash proyectos/scripts/setup/generate-secrets.sh

# 3. Construir y publicar imagenes
bash proyectos/scripts/setup/build-images.sh

# 4. Desplegar en Kubernetes
bash proyectos/scripts/setup/deploy.sh

# 5. Configurar Keycloak + OpenLDAP
bash proyectos/scripts/setup/configure-keycloak.sh
bash proyectos/scripts/setup/configure-openldap.sh

# 6. Verificar
bash proyectos/scripts/setup/verify-deployment.sh
```

## Seguridad

Ver [docs/SECURITY.md](proyectos/docs/SECURITY.md) para el threat model
completo con mitigaciones contra SQLi, XSS, CSRF, SSRF, path traversal,
brute force, privilege escalation y mas.

## Tecnologias

| Componente | Version |
|---|---|
| Vaultwarden | 1.32.5 |
| Keycloak | 24.0 |
| MariaDB | 11.2 |
| OpenLDAP | 1.5.0 (osixia) |
| MicroK8s | 1.30 |
| Ubuntu base | 24.04 |
| VPS SO | Ubuntu 24.04 LTS |
