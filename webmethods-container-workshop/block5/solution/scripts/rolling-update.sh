#!/usr/bin/env bash
# =====================================================================
# Rolling update of the two MSR nodes - one node at a time, zero downtime.
# Automates the manual procedure from Capstone 6 Part 2 (see docs/RUNBOOK-rolling-update.md).
#
#   ./scripts/rolling-update.sh 1.1.0                 # base stack
#   PROD=1 ./scripts/rolling-update.sh 1.1.0          # base + prod overlay
#   ENGINE=docker COMPOSE="docker compose" ./scripts/rolling-update.sh 1.1.0
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

NEW_VERSION="${1:?usage: rolling-update.sh <new APP_VERSION>}"
ENGINE="${ENGINE:-podman}"
COMPOSE_CMD="${COMPOSE:-podman-compose}"
FILES=(-f compose.yaml)
[ "${PROD:-0}" = "1" ] && FILES+=(-f compose.prod.yaml)
read -ra COMPOSE <<< "$COMPOSE_CMD"
COMPOSE+=("${FILES[@]}")
PROJECT="${COMPOSE_PROJECT_NAME:-wm-block5}"
UPSTREAM=nginx/upstream.conf
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-240}"      # seconds to wait for a node to become healthy

log() { printf '\033[1;34m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*"; }

# Rewrite upstream.conf IN PLACE (same inode). "sed -i" creates a new file and
# renames it over the old one, which bind mounts / VM file sharing (Podman
# machine, Docker Desktop) can briefly see as "file missing" -> nginx reload fails.
edit_upstream() { local new; new=$(sed -E "$1" "$UPSTREAM"); printf '%s\n' "$new" > "$UPSTREAM"; }
reload_lb() {
  "${COMPOSE[@]}" exec -T loadbalancer nginx -c /etc/nginx/workshop/nginx.conf -s reload \
    || { sleep 2; "${COMPOSE[@]}" exec -T loadbalancer nginx -c /etc/nginx/workshop/nginx.conf -s reload; }
}
drain()   { edit_upstream "s/^([[:space:]]*server $1:5555[^;]*)( down)?;/\1 down;/"; reload_lb; }
undrain() { edit_upstream "s/^([[:space:]]*server $1:5555[^;]*) down;/\1;/";        reload_lb; }

wait_healthy() {
  # look the container up by its compose labels: podman-compose names it
  # <project>_<service>_1, docker compose <project>-<service>-1
  local t=0 h c
  while :; do
    c=$("$ENGINE" ps -q --filter "label=com.docker.compose.project=$PROJECT" \
          --filter "label=com.docker.compose.service=$1" | head -n1)
    h=$([ -n "$c" ] && "$ENGINE" inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null || echo missing)
    [ "$h" = "healthy" ] && { log "$1 is healthy after ${t}s"; return 0; }
    [ "$t" -ge "$HEALTH_TIMEOUT" ] && { log "$1 NOT healthy after ${HEALTH_TIMEOUT}s (state: $h) - aborting, node stays drained"; return 1; }
    sleep 5; t=$((t+5))
  done
}

log "1/3 Building image version $NEW_VERSION"
APP_VERSION="$NEW_VERSION" "${COMPOSE[@]}" build msr-1

for node in msr-2 msr-1; do
  log "2/3 [$node] draining in nginx"
  drain "$node"
  sleep 2                                         # let in-flight requests finish
  log "2/3 [$node] graceful stop (stop_grace_period applies)"
  s=$(date +%s); "${COMPOSE[@]}" stop "$node" >/dev/null; log "$node stopped in $(( $(date +%s) - s ))s"
  log "2/3 [$node] re-creating with $NEW_VERSION"
  APP_VERSION="$NEW_VERSION" "${COMPOSE[@]}" up -d --no-deps --no-build "$node"
  wait_healthy "$node"
  log "2/3 [$node] back into rotation (nginx reload re-resolves the new container IP)"
  undrain "$node"
done

log "3/3 Done. Remember to set APP_VERSION=$NEW_VERSION in .env so the next 'podman-compose up' keeps it."
