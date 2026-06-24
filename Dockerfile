FROM horilla/horilla:latest

LABEL org.opencontainers.image.title="Stratechna HR"
LABEL org.opencontainers.image.vendor="Stratechna"
LABEL org.opencontainers.image.source="https://github.com/stratechna/Stratechna-HR"

# Aplicar branding como root
USER root

# Copiar assets de branding
COPY branding/logo.png /app/static/images/logo.png
COPY branding/favicon.png /app/static/favicons/favicon-32x32.png
COPY branding/favicon.png /app/static/favicons/favicon-16x16.png
COPY branding/favicon.png /app/static/favicons/apple-touch-icon.png

# Activar white label e configurar branding via patch ao horilla_apps.py
COPY branding/patch.py /tmp/patch.py
RUN python3 /tmp/patch.py

# Copiar entrypoint personalizado
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER horilla
