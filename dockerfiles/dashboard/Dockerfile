# Dashboard = HTML/CSS/JS estatico servido con nginx. No hay backend propio:
# los datos vienen de los .json en src/data/ y la auth la maneja oauth2-proxy
FROM dsegura97/ubseguridadd:latest

LABEL description="Dashboard PassProtect — panel de gestion para expo"
LABEL version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Eliminar config default de nginx
# Si no la quitamos, nginx sirve la pagina default de Ubuntu en lugar de la nuestra
RUN rm -f /etc/nginx/sites-enabled/default

# Copiar la app del dashboard
# - src/   -> /var/www/dashboard/  (estatico que sirve nginx)
# - nginx.conf -> /etc/nginx/sites-enabled/dashboard.conf (server block)
# - start.sh -> wrapper que delega a la capa seguridad y luego nginx
COPY dockerfiles/dashboard/src/ /var/www/dashboard/
COPY dockerfiles/dashboard/admin/nginx.conf /etc/nginx/sites-enabled/dashboard.conf
COPY dockerfiles/dashboard/admin/start.sh /root/admin/dashboard/

RUN chmod +x /root/admin/dashboard/start.sh

EXPOSE 3000

ENTRYPOINT ["/root/admin/dashboard/start.sh"]
