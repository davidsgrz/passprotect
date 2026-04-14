FROM dsegura97/ubseguridad:latest

LABEL description="Nginx reverse proxy con ModSecurity + OWASP CRS"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    libnginx-mod-http-modsecurity \
    modsecurity-crs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Eliminar configuracion default
RUN rm -f /etc/nginx/sites-enabled/default

# Crear directorio para ModSecurity
RUN mkdir -p /etc/nginx/modsec

COPY docker/kube/nginx-proxy/conf.d/ /etc/nginx/conf.d/
COPY docker/kube/nginx-proxy/modsec/modsecurity.conf /etc/nginx/modsec/

# ModSecurity activado
RUN echo 'load_module modules/ngx_http_modsecurity_module.so;' > /etc/nginx/modules-enabled/50-mod-http-modsecurity.conf

# Directorio para certificados autofirmados
RUN mkdir -p /etc/letsencrypt/live/selfsigned

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
