FROM python:3.12-slim

LABEL org.opencontainers.image.title="Stratechna HR"
LABEL org.opencontainers.image.vendor="Stratechna"
LABEL org.opencontainers.image.source="https://github.com/stratechna/Stratechna-HR"

# Dependencias de sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    postgresql-client \
    libpq-dev \
    gcc \
    g++ \
    libcairo2-dev \
    pkg-config \
    gettext \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clonar Horilla
RUN git clone --depth=1 https://github.com/horilla-opensource/horilla.git .

# Instalar dependencias Python
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir gunicorn psycopg2-binary

# Copiar assets de branding
COPY branding/patch.py /tmp/patch.py

# Activar WHITE_LABEL
RUN python3 /tmp/patch.py

# Copiar entrypoint personalizado
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
