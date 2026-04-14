#!/bin/bash
# Hardening SSH completo — puerto custom, solo pubkey, sin root

make_ssh() {
    local USUARIO="${USUARIO:-david}"

    # Hardening sshd_config
    sed -i 's/#Port 22/Port 45678/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
    sed -i 's/#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    sed -i 's/#AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config

    # Limitar a usuario especifico
    echo "AllowUsers ${USUARIO}" >> /etc/ssh/sshd_config

    # authorized_keys
    mkdir -p "/home/${USUARIO}/.ssh"
    if [ -f /root/admin/base/common/id_rsa.pub ]; then
        cat /root/admin/base/common/id_rsa.pub >> "/home/${USUARIO}/.ssh/authorized_keys"
    fi

    chmod 700 "/home/${USUARIO}/.ssh"
    chmod 600 "/home/${USUARIO}/.ssh/authorized_keys" 2>/dev/null || true
    chown -R "${USUARIO}:${USUARIO}" "/home/${USUARIO}/.ssh"

    /usr/sbin/sshd -D &

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH hardened: port 45678, no root, no password, pubkey only" >> /root/logs/informe.log
}
