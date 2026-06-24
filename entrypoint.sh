#!/bin/bash
# =============================================================
# Stratechna HR — Entrypoint
# Baseado no entrypoint original do Horilla com ajustes para
# multi-tenant SaaS (sem dados demo, sem interactividade)
# =============================================================

set -e

echo "[Stratechna HR] A iniciar..."

# Aguardar BD
echo "[Stratechna HR] A aguardar PostgreSQL..."
until pg_isready -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" 2>/dev/null; do
    sleep 2
done
echo "[Stratechna HR] PostgreSQL pronto"

# Migrações
echo "[Stratechna HR] A correr migrações..."
python3 manage.py makemigrations --noinput 2>/dev/null || true
python3 manage.py migrate --noinput

# Ficheiros estáticos
echo "[Stratechna HR] A recolher ficheiros estáticos..."
python3 manage.py collectstatic --noinput --clear 2>/dev/null || \
python3 manage.py collectstatic --noinput

# Compilar traduções (ignorar erros)
python3 manage.py compilemessages 2>/dev/null || true

# Criar superuser automático se não existir
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "[Stratechna HR] A criar utilizador admin..."
    python3 manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    u = User.objects.create_superuser('admin', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')
    print('Admin criado: admin / $ADMIN_EMAIL')
else:
    print('Admin já existe')
" 2>/dev/null || true
fi

echo "[Stratechna HR] A iniciar servidor..."

# Arrancar com gunicorn
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers "${GUNICORN_WORKERS:-2}" \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    horilla.wsgi:application
