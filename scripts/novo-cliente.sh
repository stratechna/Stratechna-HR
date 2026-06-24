#!/bin/bash
# =============================================================
# Stratechna HR — Provisionar nova instância (Horilla HRMS)
#
# Uso:
#   bash novo-cliente.sh <slug> <email-admin> [empresa] [dominio-proprio]
# =============================================================

set -e

SLUG="${1:-}"
EMAIL="${2:-}"
EMPRESA="${3:-$SLUG}"
DOMINIO_PROPRIO="${4:-}"

[ -z "$SLUG" ] || [ -z "$EMAIL" ] && echo "Uso: $0 <slug> <email-admin> [empresa] [dominio-proprio]" && exit 1

TEMPLATE_DIR="/opt/stratechna/hr/template"
CLIENTES_DIR="/opt/stratechna/hr/clientes"
INSTANCE_DIR="${CLIENTES_DIR}/${SLUG}"
SCRIPTS_DIR="/opt/stratechna/hr/scripts"
LOG_DIR="/opt/stratechna/logs/provisioning"
LOG_FILE="${LOG_DIR}/hr-${SLUG}.log"

mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== INÍCIO PROVISIONING HR: ${SLUG} ==="
log "Empresa: ${EMPRESA} | Email: ${EMAIL}"

if [ -f "${INSTANCE_DIR}/.env" ]; then
    log "ERRO: instância '${SLUG}' já existe (.env encontrado)"
    exit 1
fi

# --- Passo 1/6: Credenciais ---
log "--- Passo 1/6: Gerar credenciais ---"
SECRET_KEY=$(openssl rand -hex 32)
DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
INIT_PASS=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
mkdir -p "$INSTANCE_DIR"
log "Credenciais geradas"

# --- Passo 2/6: URLs ---
log "--- Passo 2/6: Configurar URLs ---"
if [ -n "$DOMINIO_PROPRIO" ]; then
    APP_URL="https://hr.${DOMINIO_PROPRIO}"
    EXTRA_HOSTS_RULE=" || Host(\`hr.${DOMINIO_PROPRIO}\`)"
else
    APP_URL="https://hr.${SLUG}.stratechna.com"
    EXTRA_HOSTS_RULE=""
fi
log "URL: ${APP_URL}"

# --- Passo 3/6: .env e docker-compose ---
log "--- Passo 3/6: Criar ficheiros de configuração ---"

cat > "${INSTANCE_DIR}/.env" << ENV
SLUG=${SLUG}
EMPRESA=${EMPRESA}
EMAIL=${EMAIL}
APP_URL=${APP_URL}
SECRET_KEY=${SECRET_KEY}
DB_PASS=${DB_PASS}
INIT_PASS=${INIT_PASS}
ADMIN_PASS=${ADMIN_PASS}
DOMINIO_PROPRIO=${DOMINIO_PROPRIO}
ENV

chmod 600 "${INSTANCE_DIR}/.env"

if [ ! -f "${TEMPLATE_DIR}/docker-compose.yml" ]; then
    log "ERRO: template não encontrado em ${TEMPLATE_DIR}/docker-compose.yml"
    exit 1
fi

sed \
    -e "s/CLIENTE/${SLUG}/g" \
    -e "s/HR_SECRET/${SECRET_KEY}/g" \
    -e "s/HR_DB_PASS/${DB_PASS}/g" \
    -e "s/HR_INIT_PASS/${INIT_PASS}/g" \
    -e "s/HR_ADMIN_EMAIL/${EMAIL}/g" \
    -e "s/HR_ADMIN_PASSWORD/${ADMIN_PASS}/g" \
    -e "s|EXTRA_HOSTS_RULE|${EXTRA_HOSTS_RULE}|g" \
    "${TEMPLATE_DIR}/docker-compose.yml" > "${INSTANCE_DIR}/docker-compose.yml"

log "Ficheiros criados"

# --- Passo 4/6: DNS ---
log "--- Passo 4/6: Registar DNS ---"
sqlite3 /var/lib/powerdns/pdns.sqlite3 \
    "INSERT OR IGNORE INTO records (domain_id, name, type, content, ttl)
     SELECT id, 'hr.${SLUG}.stratechna.com.', 'A', '95.217.8.239', 3600
     FROM domains WHERE name='stratechna.com';" 2>/dev/null \
    && pdns_control reload 2>/dev/null \
    && log "DNS registado: hr.${SLUG}.stratechna.com" \
    || log "AVISO: DNS falhou — adicionar manualmente"

# --- Passo 5/6: Arrancar containers ---
log "--- Passo 5/6: Arrancar containers ---"
cd "${INSTANCE_DIR}"

docker compose pull --quiet 2>&1 | tail -3 | tee -a "$LOG_FILE" || true
docker compose up -d 2>&1 | tee -a "$LOG_FILE"

log "Containers a arrancar (aguardar ~60s para migrações)..."
sleep 30

# Aguardar web estar pronto (max 3 min)
TIMEOUT=180
ELAPSED=0
while true; do
    STATUS=$(docker exec "hr-${SLUG}-web" curl -sf -o /dev/null -w "%{http_code}" http://localhost:8000 2>/dev/null || echo "000")
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ] || [ "$STATUS" = "301" ]; then
        log "Servidor pronto (HTTP ${STATUS})"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        log "AVISO: servidor ainda não responde ao fim de ${TIMEOUT}s"
        break
    fi
    log "A aguardar... (${ELAPSED}s/${TIMEOUT}s) — status: ${STATUS}"
done

# --- Passo 6/6: Setup inicial via management command ---
log "--- Passo 6/6: Inicializar base de dados ---"

# Inicializar empresa e admin via DB_INIT_PASSWORD
docker exec "hr-${SLUG}-web" sh -c "
echo '{\"company_name\": \"${EMPRESA}\", \"username\": \"admin\", \"password\": \"${ADMIN_PASS}\", \"email\": \"${EMAIL}\"}' | \
python3 manage.py shell -c \"
import sys, json
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', '${EMAIL}', '${ADMIN_PASS}')
    print('Admin criado')
else:
    print('Admin já existe')
\" 2>/dev/null
" 2>&1 | tee -a "$LOG_FILE" || log "Setup manual necessário em ${APP_URL}"

log "=== CONCLUIDO COM SUCESSO ==="
log ""
log "╔══════════════════════════════════════════════╗"
log "║       STRATECHNA HR — ${SLUG}"
log "╠══════════════════════════════════════════════╣"
log "║ URL:         ${APP_URL}"
log "║ Utilizador:  admin"
log "║ Password:    ${ADMIN_PASS}"
log "║ Email:       ${EMAIL}"
log "║"
log "║ Setup inicial: ${APP_URL}/initialize-db"
log "║ Init Password: ${INIT_PASS}"
log "╚══════════════════════════════════════════════╝"
