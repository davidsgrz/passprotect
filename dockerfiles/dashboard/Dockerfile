FROM dsegura97/ubseguridadd:latest

LABEL description="Dashboard PassProtect — panel de gestion para expo"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Eliminar config default de nginx
RUN rm -f /etc/nginx/sites-enabled/default

# Copiar la app del dashboard
COPY dockerfiles/dashboard/src/ /var/www/dashboard/
COPY dockerfiles/dashboard/admin/nginx.conf /etc/nginx/sites-enabled/dashboard.conf
COPY dockerfiles/dashboard/admin/start.sh /root/admin/dashboard/

RUN chmod +x /root/admin/dashboard/start.sh

EXPOSE 3000

ENTRYPOINT ["/root/admin/dashboard/start.sh"]
