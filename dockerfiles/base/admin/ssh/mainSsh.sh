#!/bin/bash
# Hardening SSH completo — puerto custom, solo pubkey, sin root

make_ssh() {
    local USUARIO="${USUARIO:-david}"

    # Hardening sshd_config
    # Puerto 45678 (no 22): security through obscurity para reducir ruido de bots.
    # Validado en pentest: 11 baneos fail2ban en 20 min de exposicion del puerto 22 publico
    sed -i 's/#Port 22/Port 45678/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    # PasswordAuthentication no + Pubkey yes = solo login por clave privada autorizada
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    # ClientAlive 300x2 = corta sesiones idle a los 10 min sin tocar nada
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
