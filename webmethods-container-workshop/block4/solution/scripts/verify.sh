#!/usr/bin/env bash
# Capstone 4 verification: health, JDBC (MSR -> PostgreSQL) and JMS (MSR -> UM -> MSR).
# Usage: ./scripts/verify.sh                 (reads ADMIN_PASSWORD from .env)
#        COMPOSE="docker compose" ./scripts/verify.sh   (default: podman-compose)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

MSR_URL="${MSR_URL:-http://localhost:5555}"
AUTH="Administrator:${ADMIN_PASSWORD:?ADMIN_PASSWORD not set}"
COMPOSE="${COMPOSE:-podman-compose}"

step() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
# invoke <folder/service?query> - prints JSON, exits non-zero on HTTP errors
invoke() { curl -fsS -u "$AUTH" -H "Accept: application/json" "$MSR_URL/invoke/$1"; echo; }

step "1. MSR readiness ($MSR_URL/health/readiness)"
curl -fsS -o /dev/null -w "HTTP %{http_code}\n" "$MSR_URL/health/readiness"

step "2. Configuration from application.properties (swisscom.lab.health:info)"
invoke "swisscom.lab.health/info"

step "3. JDBC: insert + query through the MSR (swisscom.lab.db)"
invoke "swisscom.lab.db/createOrder?customer=verify.sh&amount=19.90"
invoke "swisscom.lab.db/listOrders?limit=3"

step "4. JMS: send to UM queue LabOrders, then receive it back"
invoke "swisscom.lab.jms/sendOrder?message=hello-from-verify"
invoke "swisscom.lab.jms/receiveOrder?timeoutMs=5000"

step "5. UM side: channels and queues known to the realm"
$COMPOSE exec -T um runUMTool.sh ListChannels -rname=nsp://localhost:9000 | grep -v "^We have" || true

printf '\n\033[1;32mAll checks passed.\033[0m\n'
