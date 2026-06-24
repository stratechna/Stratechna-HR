#!/bin/bash
# Stratechna HR — DNS add
FQDN="${2:-}"
IP="95.217.8.239"
[ -z "$FQDN" ] && echo "Uso: $0 <subdomain> <fqdn>" && exit 1
sqlite3 /var/lib/powerdns/pdns.sqlite3 \
    "INSERT OR IGNORE INTO records (domain_id, name, type, content, ttl)
     SELECT id, '${FQDN}.', 'A', '${IP}', 3600
     FROM domains WHERE name='stratechna.com';" 2>/dev/null \
    && pdns_control reload 2>/dev/null \
    && echo "Ok" \
    || echo "Adicionar DNS manualmente: ${FQDN} A ${IP}"
