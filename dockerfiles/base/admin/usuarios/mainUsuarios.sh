#!/bin/bash
# Gestion de usuarios — creacion con permisos restringidos

check_usuario() {
    local USUARIO="${USUARIO:-david}"
    if grep -q "^${USUARIO}:" /etc/passwd; then
        echo "${USUARIO} existe en /etc/passwd" >> /root/logs/informe.log
        return 1
    fi
    return 0
}

check_home() {
    local USUARIO="${USUARIO:-david}"
    if [ -d "/home/${USUARIO}" ]; then
        echo "/home/${USUARIO} ya existe" >> /root/logs/informe.log
        return 1
    fi
    return 0
}

newUser() {
    local USUARIO="${USUARIO:-david}"
    # Password aleatorio si no se inyecta por env: el login es por SSH key, asi
    # que el password queda como "imposible de adivinar" pero presente para sudo
    local PASSWORD="${PASSWORD:-$(openssl rand -base64 16)}"

    if check_usuario && check_home; then
        # -r = system user (UID < 1000). -m crea /home aunque sea system user
        useradd -rm -d "/home/${USUARIO}" -s /bin/bash "${USUARIO}"
        echo "${USUARIO}:${PASSWORD}" | chpasswd

        # Restricciones de permisos
        # 750 (no 755): otros usuarios no pueden listar el home
        chmod 750 "/home/${USUARIO}"
        echo "Bienvenido ${USUARIO}" > "/home/${USUARIO}/bienvenida.txt"

        echo "Usuario ${USUARIO} creado" >> /root/logs/informe.log
        return 0
    fi
    return 1
}
