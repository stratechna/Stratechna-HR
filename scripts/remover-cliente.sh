#!/bin/bash
# =============================================================
# Stratechna HR — Remover instância
#
# Uso:
#   bash remover-cliente.sh <slug> [--apagar-dados]
# =============================================================

set -e

SLUG="${1:-}"
APAGAR=false

[ -z "$SLUG" ] && echo "Uso: $0 <slug> [--apagar-dados]" && exit 1

for arg in "$@"; do
    [ "$arg" = "--apagar-dados" ] && APAGAR=true
done

INSTANCE_DIR="/opt/stratechna/hr/clientes/$SLUG"
LOG_DIR="/opt/stratechna/logs/provisioning"
LOG_FILE="${LOG_DIR}/hr-remover-${SLUG}.log"

mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== INÍCIO REMOÇÃO HR: ${SLUG} (apagar-dados: ${APAGAR}) ==="

if [ ! -d "$INSTANCE_DIR" ]; then
    log "ERRO: instância '${SLUG}' não encontrada em ${INSTANCE_DIR}"
    exit 1
fi

cd "$INSTANCE_DIR"

log "A parar containers..."
if [ -f "docker-compose.yml" ]; then
    docker compose stop 2>&1 | tee -a "$LOG_FILE" || true
    log "Containers parados"
else
    docker stop "hr-${SLUG}-web" 2>/dev/null || true
    docker stop "hr-${SLUG}-db"  2>/dev/null || true
    log "Containers parados por nome"
fi

if [ "$APAGAR" = "true" ]; then
    log "A remover containers, volumes e directório..."
    docker compose down -v 2>&1 | tee -a "$LOG_FILE" || true
    cd /
    rm -rf "$INSTANCE_DIR"
    log "Directório ${INSTANCE_DIR} removido"
    log "=== CONCLUIDO COM SUCESSO (dados apagados) ==="
else
    log "Instância suspensa (containers parados, dados mantidos)"
    log "=== CONCLUIDO COM SUCESSO (suspenso) ==="
fi
