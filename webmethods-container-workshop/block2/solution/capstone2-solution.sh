#!/usr/bin/env bash
# =====================================================================
# Capstone 2 - reference solution as one runnable script.
# Runs every part of the capstone in order and prints what to look for.
#
#   ./capstone2-solution.sh              # uses podman
#   ENGINE=docker ./capstone2-solution.sh
#   ./capstone2-solution.sh cleanup      # remove everything the capstone created
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

ENGINE="${ENGINE:-podman}"
IMAGE="ibmwebmethods.azurecr.io/webmethods-microservicesruntime:12.1.0.3"
NAME="msr-capstone2"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Init1al!Change}"
REPO_ROOT="$(cd ../.. && pwd)"

step() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
wait_ready() {
  printf 'waiting for %s ' "$1"
  for _ in $(seq 1 60); do
    if curl -fs -o /dev/null "$1"; then echo " -> OK"; return 0; fi
    printf '.'; sleep 3
  done
  echo " -> TIMEOUT"; return 1
}

if [ "${1:-}" = "cleanup" ]; then
  $ENGINE rm -f "$NAME" 2>/dev/null || true
  $ENGINE volume rm -f msr-capstone2-logs 2>/dev/null || true
  rm -rf ./msr-capstone2-logs
  exit 0
fi

step "Part 1 - pull and run (registry login must already be done)"
$ENGINE pull "$IMAGE"
$ENGINE rm -f "$NAME" 2>/dev/null || true
$ENGINE run -d --name "$NAME" \
  -p 5555:5555 -p 5543:5543 \
  -e SAG_IS_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  -e TZ=Europe/Zurich \
  -e JAVA_MIN_MEM=512M -e JAVA_MAX_MEM=1024M \
  --health-cmd='curl -fs http://localhost:5555/health/readiness || exit 1' \
  --health-interval=10s --health-retries=12 --health-start-period=60s \
  "$IMAGE"
$ENGINE ps --filter "name=$NAME"
wait_ready http://localhost:5555/health/readiness

step "Part 2 - Administrator UI and health endpoints"
echo "Open http://localhost:5555  (Administrator / $ADMIN_PASSWORD)"
curl -fsS -o /dev/null -w "liveness  -> HTTP %{http_code}\n" http://localhost:5555/health/liveness
curl -fsS -o /dev/null -w "readiness -> HTTP %{http_code}\n" http://localhost:5555/health/readiness
curl -fsS http://localhost:5555/metrics | grep -m3 '^sag_is_'
curl -fsS -o /dev/null -w "ping as Administrator -> HTTP %{http_code}\n" \
  -u "Administrator:$ADMIN_PASSWORD" http://localhost:5555/invoke/wm.server/ping

step "Part 3 - logs: stdout vs. files"
$ENGINE logs --tail 5 "$NAME"
$ENGINE exec "$NAME" ls -1 /opt/webmethods/IntegrationServer/logs
$ENGINE exec "$NAME" tail -n 5 /opt/webmethods/IntegrationServer/logs/server.log

step "Part 4 - lifecycle: stop / start / restart / rm, then re-create with a logs bind mount"
time $ENGINE stop "$NAME"
$ENGINE start "$NAME" && wait_ready http://localhost:5555/health/readiness
$ENGINE restart "$NAME" && wait_ready http://localhost:5555/health/readiness
$ENGINE rm -f "$NAME"
mkdir -p ./msr-capstone2-logs
$ENGINE run -d --name "$NAME" -p 5555:5555 \
  -e SAG_IS_ADMIN_PASSWORD="$ADMIN_PASSWORD" -e TZ=Europe/Zurich \
  -v "$PWD/msr-capstone2-logs:/opt/webmethods/IntegrationServer/logs" \
  "$IMAGE"
wait_ready http://localhost:5555/health/readiness
ls -1 ./msr-capstone2-logs

step "Part 5 - application.properties + package bind mount"
$ENGINE rm -f "$NAME"
$ENGINE run -d --name "$NAME" -p 5555:5555 \
  -e ADMIN_PASSWORD="$ADMIN_PASSWORD" -e LAB_ENV=capstone2-laptop -e TZ=Europe/Zurich \
  -v "$PWD/application.properties:/opt/webmethods/IntegrationServer/application.properties:ro" \
  -v "$REPO_ROOT/packages/SwisscomLab:/opt/webmethods/IntegrationServer/packages/SwisscomLab" \
  -v "$PWD/msr-capstone2-logs:/opt/webmethods/IntegrationServer/logs" \
  "$IMAGE"
wait_ready http://localhost:5555/health/readiness
$ENGINE logs "$NAME" 2>&1 | grep -m5 'ISS.0028' || true
curl -fsS -u "Administrator:$ADMIN_PASSWORD" -H "Accept: application/json" \
  http://localhost:5555/invoke/swisscom.lab.health/info; echo
$ENGINE exec "$NAME" grep -c "watt.server.audit.logFilesToKeep=7" /opt/webmethods/IntegrationServer/config/server.cnf

printf '\n\033[1;32mCapstone 2 complete. Clean up with: %s cleanup\033[0m\n' "$0"
