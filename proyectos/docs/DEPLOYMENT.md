# Guia de Despliegue — PassProtect

## Requisitos

- VPS: Contabo VPS S (4 vCPU, 8 GB RAM)
- SO: Ubuntu 24.04 LTS
- Docker 24+
- MicroK8s 1.30
- Helm 3

## Pasos de despliegue

### 1. Preparar el VPS

```bash
# Clonar repositorio
git clone https://github.com/dsegura97/passprotect.git
cd passprotect

# Configurar IP del VPS
nano config.env  # Cambiar VPS_IP

# Inicializar VPS (Docker, MicroK8s, UFW, certs)
sudo bash proyectos/passprotect/scripts/setup/init-vps.sh
```

### 2. Generar secretos

```bash
bash proyectos/passprotect/scripts/setup/generate-secrets.sh
```

### 3. Construir y publicar imagenes

```bash
bash proyectos/passprotect/scripts/setup/build-images.sh
```

### 4. Desplegar en Kubernetes

```bash
bash proyectos/passprotect/scripts/setup/deploy.sh
```

### 5. Configurar Keycloak

```bash
bash proyectos/passprotect/scripts/setup/configure-keycloak.sh
```

### 6. Configurar OpenLDAP

```bash
bash proyectos/passprotect/scripts/setup/configure-openldap.sh
```

Este script carga los LDIFs de `dockerfiles/openldap/bootstrap/01-users.ldif`
(usuarios `admin.vault`, `david.segura`, `fran.parra`, `user.demo` y grupos
`vw-admins`, `vw-users`, `it-dept`) sobre `dc=corp,dc=local`. La contraseña
temporal de los usuarios es `TempPass123!` — cambiala en primera sesion via
Keycloak.

### 7. Verificar

```bash
bash proyectos/passprotect/scripts/setup/verify-deployment.sh
```

## URLs de acceso

- **Vaultwarden**: `https://vault.<IP>.nip.io`
- **Keycloak**: `https://auth.<IP>.nip.io`

## Orden de build de imagenes Docker

```
1. dsegura97/ubbase:latest          (docker/kube/base/)
2. dsegura97/ubseguridad:latest     (docker/kube/seguridad/)
3. dsegura97/vaultwarden-corp:1.0.0 (docker/kube/vaultwarden/)
4. dsegura97/keycloak-corp:1.0.0    (docker/kube/keycloak/)
5. dsegura97/mariadb-corp:1.0.0     (docker/kube/mariadb/)
6. dsegura97/nginx-proxy-corp:1.0.0 (docker/kube/nginx-proxy/)
```
