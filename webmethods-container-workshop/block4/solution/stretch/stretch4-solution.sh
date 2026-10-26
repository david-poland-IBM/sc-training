#!/usr/bin/env bash
# =====================================================================
# Capstone 4 - STRETCH GOALS (reference solution)
#   1. send 3 messages without receiving them, then look at the queue in UM
#   2. a second network: postgres and um on backend only, proven unreachable
#      from a throw-away container on the other network
#   3. the used-heap metric in /metrics
#
# Uses the stack in block4/solution (creates .env from .env.example if missing):
#   ./stretch/stretch4-solution.sh
#   ./stretch/stretch4-solution.sh cleanup      # down -v, incl. the frontend network
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || cp .env.example .env
set -a && . ./.env && set +a

ENGINE="${ENGINE:-podman}"
read -ra COMPOSE <<< "${COMPOSE:-podman-compose}"
COMPOSE+=(-f compose.yaml -f stretch/compose.networks.yaml)
PROJECT="${COMPOSE_PROJECT_NAME:-wm-block4}"
PG_IMAGE="${POSTGRES_IMAGE:-docker.io/library/postgres:16}"
MSR_URL=http://localhost:5555
AUTH="Administrator:${ADMIN_PASSWORD:?ADMIN_PASSWORD not set}"
RNAME=nsp://localhost:9000

step() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
invoke() { curl -fsS -u "$AUTH" -H "Accept: application/json" "$MSR_URL/invoke/$1"; echo; }
um() { "${COMPOSE[@]}" exec -T um timeout 15 runUMTool.sh "$@" -rname=$RNAME 2>&1 || true; }
queue_depth() { um MonitorChannels -channelname=LabOrders -format=plaintext | grep -m1 -E '^Events +:' ; }
wait_ready() {
  printf 'waiting for MSR readiness '
  for _ in $(seq 1 60); do
    if curl -fs -o /dev/null "$MSR_URL/health/readiness"; then echo " -> OK"; return 0; fi
    printf '.'; sleep 3
  done
  echo " -> TIMEOUT"; return 1
}
pg_from() {   # pg_isready from a throw-away container on network $1 against host $2
  printf '%-9s -> %-15s ' "$1" "$2"
  $ENGINE run --rm --network "${PROJECT}_$1" "$PG_IMAGE" pg_isready -h "$2" -t 3 || true
}

if [ "${1:-}" = "cleanup" ]; then
  "${COMPOSE[@]}" down -v
  exit 0
fi

step "Start: base file + network overlay (down first, so the networks are re-created)"
"${COMPOSE[@]}" down >/dev/null 2>&1 || true
"${COMPOSE[@]}" up -d --build >/dev/null 2>&1
wait_ready

step "Stretch 1 - 3 messages in, none out: the queue holds them"
for _ in $(seq 1 20); do                               # start from an empty queue
  invoke "swisscom.lab.jms/receiveOrder?timeoutMs=1000" | grep -q '"received":"true"' || break
done
for i in 1 2 3; do invoke "swisscom.lab.jms/sendOrder?message=stretch-$i"; done
queue_depth
echo "-- the waiting messages (PeekQueue does not consume them):"
um PeekQueue -queuename=LabOrders | grep 'Event data'
echo "GetQueueInfo (note: -qname=) shows only the queue's attributes, no depth:"
um GetQueueInfo -qname=LabOrders | grep -E '^(Name|Type|Capacity) '
echo "-- receive all three, then the depth is back to 0:"
for _ in 1 2 3; do invoke "swisscom.lab.jms/receiveOrder?timeoutMs=5000"; done
queue_depth

step "Stretch 2 - postgres and um on backend only"
$ENGINE ps --filter "label=com.docker.compose.project=$PROJECT" --format '{{.Names}}  {{.Networks}}'
PG_IP=$($ENGINE inspect "${PROJECT}_postgres_1" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
pg_from frontend postgres
pg_from frontend "$PG_IP"
pg_from backend postgres
printf '%-9s -> %-15s ' frontend msr
$ENGINE run --rm --network "${PROJECT}_frontend" "$PG_IMAGE" \
  bash -c 'timeout 3 bash -c "</dev/tcp/msr/5555" && echo "msr:5555 - open"' || echo "msr:5555 - no response"
echo "frontend reaches msr, but not postgres by name OR by IP (isolate=true)."
echo "msr bridges both networks and still has its database:"
invoke "swisscom.lab.db/listOrders?limit=1"

step "Stretch 3 - used heap in /metrics"
curl -fsS "$MSR_URL/metrics" | grep -E '^sag_is_(used|max|free)_memory_bytes'
curl -fsS "$MSR_URL/metrics" | awk '/^sag_is_used_memory_bytes/{u=$2} /^sag_is_max_memory_bytes/{m=$2}
  END { if (m) printf "used heap: %.0f MiB of %.0f MiB (%d%%)  - max = JAVA_MAX_MEM=1024M\n", u/1048576, m/1048576, u*100/m }'
echo "Trap: sag_is_server_used_memory_mbytes is the HOST's (Podman machine's) memory, not the heap."

printf '\n\033[1;32mStretch goals complete. Clean up with: %s cleanup\033[0m\n' "$0"
