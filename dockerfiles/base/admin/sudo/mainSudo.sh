#!/bin/bash
# Configuracion sudo — privilegios limitados (principio de minimo privilegio)

make_sudo() {
    local USUARIO="${USUARIO:-david}"
    # NOPASSWD limitado a comandos especificos (no ALL)
    cat > "/etc/sudoers.d/${USUARIO}" <<EOF
${USUARIO} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart sshd, /usr/bin/apt update, /usr/bin/apt upgrade
EOF
    chmod 0440 "/etc/sudoers.d/${USUARIO}"
    echo "Sudo configurado con privilegios limitados para ${USUARIO}" >> /root/logs/informe.log
}
