# PassProtect — Plataforma Corporativa de Gestion de Contraseñas

**Proyecto intermodular ASIR 2025-2026**

**Autores**: Francisco Parra Caparros & David Segura Rodriguez

## Descripcion

Plataforma de gestion de contraseñas corporativa basada en Vaultwarden con
autenticacion centralizada (Keycloak + FreeIPA), desplegada sobre Kubernetes
(MicroK8s) en un VPS Contabo con hardening completo.

## Arquitectura

```
Cliente ─HTTPS─▶ Ingress Nginx ─▶ Vaultwarden ─▶ MariaDB
                      │              │
                      └─▶ Keycloak ──┴─ OIDC
                            │
                            └─▶ FreeIPA (LDAP federation, READ-ONLY)
```

## Capas Docker

```
ubuntu:22.04
  └── ubbase              (SSH hardening, gestion usuarios, sudo)
       └── ubseguridad    (auditoria puertos, log rotation, fail2ban-ready)
            ├── vaultwarden-corp:1.0.0
            ├── keycloak-corp:1.0.0
            ├── mariadb-corp:1.0.0   (hardened anti-SQLi)
            └── nginx-proxy-corp:1.0.0 (ModSecurity + OWASP CRS)
```

## Estructura del repositorio

- `docker/kube/` — Dockerfiles e imagenes custom (patron HLC_kubernetes)
- `proyectos/passprotect/` — Despliegue: compose, k8s, helm, scripts, docs
- `config.env` — Variables centrales (no se commitea)

## Despliegue rapido

```bash
# 1. Configurar variables
cp config.env.example config.env
nano config.env

# 2. Generar secretos
bash proyectos/passprotect/scripts/setup/generate-secrets.sh

# 3. Construir y publicar imagenes
bash proyectos/passprotect/scripts/setup/build-images.sh

# 4. Desplegar en Kubernetes
bash proyectos/passprotect/scripts/setup/deploy.sh

# 5. Configurar Keycloak + FreeIPA
bash proyectos/passprotect/scripts/setup/configure-keycloak.sh
bash proyectos/passprotect/scripts/setup/configure-freeipa.sh

# 6. Verificar
bash proyectos/passprotect/scripts/setup/verify-deployment.sh
```

## Seguridad

Ver [docs/SECURITY.md](proyectos/passprotect/docs/SECURITY.md) para el threat
model completo con mitigaciones contra SQLi, XSS, CSRF, SSRF, path traversal,
brute force, privilege escalation y mas.

## Tecnologias

| Componente | Version |
|---|---|
| Vaultwarden | 1.32.5 |
| Keycloak | 24.0 |
| MariaDB | 11.2 |
| FreeIPA | Latest |
| MicroK8s | 1.30 |
| Ubuntu base | 22.04 |
| VPS SO | Ubuntu 24.04 LTS |
