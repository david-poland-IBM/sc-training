#!/usr/bin/env bash
# =====================================================================
# Capstone 2 - STRETCH GOALS (reference solution)
#   1. a second MSR on host port 15555 next to msr-capstone2
#   2. LOG_FORMAT=json - compare the podman logs output
#   3. find the Administrator password in plain text in podman inspect
#
#   ../capstone2-solution.sh           # first: msr-capstone2 must be running
#   ./stretch2-solution.sh
#   ./stretch2-solution.sh cleanup     # removes msr-capstone2-b only
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

ENGINE="${ENGINE:-podman}"
IMAGE="ibmwebmethods.azurecr.io/webmethods-microservicesruntime:12.1.0.3"
NAME="${NAME:-msr-capstone2}"
SECOND="msr-capstone2-b"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Init1al!Change}"

step() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
wait_ready() {
  printf 'waiting for %s ' "$1"
  for _ in $(seq 1 60); do
    if curl -fs -o /dev/null "$1"; then echo " -> OK"; return 0; fi
    printf '.'; sleep 3
  done
  echo " -> TIMEOUT"; return 1
}
run_second() {   # same image, same CONTAINER port 5555, different HOST port
  $ENGINE rm -f "$SECOND" >/dev/null 2>&1 || true
  $ENGINE run -d --name "$SECOND" -p 15555:5555 \
    -e SAG_IS_ADMIN_PASSWORD="$ADMIN_PASSWORD" -e TZ=Europe/Zurich "$@" \
    "$IMAGE" >/dev/null
  wait_ready http://localhost:15555/health/readiness
}

if [ "${1:-}" = "cleanup" ]; then
  $ENGINE rm -f "$SECOND" 2>/dev/null || true
  exit 0
fi

$ENGINE container exists "$NAME" || { echo "$NAME not found - run ../capstone2-solution.sh first"; exit 1; }

step "Stretch 1 - a second MSR on host port 15555 at the same time"
run_second
$ENGINE ps --filter "name=^$NAME\$" --filter "name=^$SECOND\$" --format '{{.Names}}  {{.Ports}}'
for p in 5555 15555; do
  curl -fsS -o /dev/null -w "localhost:$p/health/readiness -> HTTP %{http_code}\n" "http://localhost:$p/health/readiness"
done
echo "Both containers listen on 5555 INSIDE their own network namespace; -p HOST:CONTAINER"
echo "only picks the host side. Two processes can't share a host port, so only that side changes."

step "Stretch 2 - LOG_FORMAT=json (env is fixed at creation: re-create, a restart is not enough)"
run_second -e LOG_FORMAT=json
echo "-- $NAME (default format):"
$ENGINE logs --tail 3 "$NAME" 2>&1
echo "-- $SECOND (LOG_FORMAT=json):"
$ENGINE logs --tail 3 "$SECOND" 2>&1
echo "-- one JSON line, pretty-printed (fields a log shipper can index without regex):"
line=$($ENGINE logs "$SECOND" 2>&1 | grep 'ISS.0014.0002I' | tail -n1)
printf '%s\n' "$line" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$line"

step "Stretch 3 - the password in plain text in podman inspect"
$ENGINE inspect "$NAME" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -i password
echo "Anyone who can run 'podman inspect' (or read the compose file / shell history) sees it."
echo "Block 6 moves it into a secret file mounted at /run/secrets/ - not part of Config.Env."

printf '\n\033[1;32mStretch goals complete. Clean up with: %s cleanup\033[0m\n' "$0"
