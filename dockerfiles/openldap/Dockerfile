# ============================================================
# PassProtect — OpenLDAP (servidor de identidad)
# ============================================================
#
# NOTA DE DISEÑO:
# NO heredamos de dsegura97/ubseguridadd porque osixia/openldap
# usa su propio init system (confd + run.sh) que gestiona:
#   - Generacion de slapd.conf / cn=config dinamico
#   - Arranque de slapd con los TLS certs auto-firmados
#   - Carga de LDIFs de /container/service/slapd/assets/config/bootstrap/
#
# Envolver osixia con nuestro start.sh de ubseguridadd rompe el
# ENTRYPOINT /container/tool/run de osixia. Por eso heredamos
# directamente de osixia/openldap:1.5.0 y solo anadimos:
#   - LDIFs de bootstrap (usuarios + grupos PassProtect)
#   - Labels del proyecto
#
# La imagen se publica como dsegura97/openldap-corp:1.0.0
# ============================================================

FROM osixia/openldap:1.5.0

LABEL maintainer="David Segura & Francisco Parra"
LABEL description="OpenLDAP con bootstrap PassProtect Corp (dc=corp,dc=local)"
LABEL version="1.0.0"

# ---------- Bootstrap LDIFs ----------
# osixia/openldap carga automaticamente cualquier .ldif que se
# encuentre en /container/service/slapd/assets/config/bootstrap/ldif/custom/
# en el primer arranque (cuando /var/lib/ldap esta vacio).
COPY dockerfiles/openldap/bootstrap/01-users.ldif \
     /container/service/slapd/assets/config/bootstrap/ldif/custom/01-users.ldif

# ---------- Variables por defecto ----------
# Estas se sobreescriben en docker-compose y en el Deployment de K8s.
ENV LDAP_ORGANISATION="PassProtect Corp" \
    LDAP_DOMAIN="corp.local" \
    LDAP_BASE_DN="dc=corp,dc=local" \
    LDAP_TLS="true" \
    LDAP_TLS_VERIFY_CLIENT="never" \
    LDAP_RFC2307BIS_SCHEMA="false" \
    LDAP_BACKEND="mdb" \
    LDAP_LOG_LEVEL="256"

EXPOSE 389 636

# El ENTRYPOINT lo hereda de osixia (no tocamos).
# CMD ["--copy-service"] asegura que los LDIFs custom se copien dentro del contenedor
# y se apliquen en el bootstrap inicial.
CMD ["--copy-service"]
