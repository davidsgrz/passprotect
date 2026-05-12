#!/bin/bash
# Configuracion sudo — privilegios limitados (principio de minimo privilegio)

# Crea un fichero en /etc/sudoers.d/<usuario> con los comandos permitidos via sudo.
# La gracia de /etc/sudoers.d/ frente a editar /etc/sudoers directamente: cada
# usuario tiene su fichero propio, mas facil de auditar/quitar
make_sudo() {
    local USUARIO="${USUARIO:-david}"
    # NOPASSWD limitado a 3 comandos concretos, NO 'ALL'.
    # Principio de minimo privilegio: si el usuario es comprometido, NO puede
    # privilegiarse a root para nada que no sea reiniciar sshd o actualizar paquetes
    cat > "/etc/sudoers.d/${USUARIO}" <<EOF
${USUARIO} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart sshd, /usr/bin/apt update, /usr/bin/apt upgrade
EOF
    # 0440: el sudoers spec exige read-only para owner+group, ningun other
    chmod 0440 "/etc/sudoers.d/${USUARIO}"
    echo "Sudo configurado con privilegios limitados para ${USUARIO}" >> /root/logs/informe.log
}
