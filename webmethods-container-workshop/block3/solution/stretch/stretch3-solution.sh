#!/usr/bin/env bash
# =====================================================================
# Block 3 capstone - STRETCH GOALS (reference solution), run in order:
#   1. change one line in server.js, up -d --build: which steps are cached?
#   2. drop "condition: service_healthy", down -v + up -d, curl immediately
#   3. the nginx web service from Exercise 3.7 in the same file
#
#   ./stretch3-solution.sh             # creates .env from .env.example if missing
#   ./stretch3-solution.sh cleanup     # podman-compose down -v
#
# Goal 1 edits a temporary COPY of ../../capstone/api, never your own files.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"
read -ra COMPOSE <<< "${COMPOSE:-podman-compose}"

step() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
api() { curl -sS -m 3 http://localhost:3000 2>&1 || true; }

if [ "${1:-}" = "cleanup" ]; then
  "${COMPOSE[@]}" -f compose.yaml down -v
  exit 0
fi
[ -f .env ] || cp .env.example .env

API_DIR=$(mktemp -d)/api
cp -R ../../capstone/api "$API_DIR"
export API_DIR
trap 'rm -rf "$(dirname "$API_DIR")"' EXIT

step "Baseline: build and start db + api + web"
"${COMPOSE[@]}" -f compose.yaml up -d --build >/dev/null 2>&1
until curl -fs -o /dev/null http://localhost:3000; do sleep 1; done
api

step "Stretch 1 - change ONE line in server.js, rebuild"
EDIT="edited $(date +%H:%M:%S)"     # unique text, so the layer is never in the cache yet
sed -i.bak "s/API listening on :3000/API listening on :3000 ($EDIT)/" "$API_DIR/server.js" && rm "$API_DIR/server.js.bak"
"${COMPOSE[@]}" -f compose.yaml up -d --build 2>&1 | grep -E '^STEP|Using cache|^COMMIT' || true
echo "FROM, WORKDIR, COPY package.json and RUN npm install come from the cache;"
echo "only COPY server.js and the steps after it run again. That's why the Containerfile"
echo "copies the dependency manifest first and the code last."
printf 'running api says: '; "${COMPOSE[@]}" -f compose.yaml logs api 2>&1 | grep 'listening' | tail -n1
echo "...still the OLD text: podman-compose 1.6 re-creates a container only when its"
echo "compose config changed, not when the image behind the tag did. Force it:"
"${COMPOSE[@]}" -f compose.yaml up -d --force-recreate api >/dev/null 2>&1
until curl -fs -o /dev/null http://localhost:3000; do sleep 1; done
printf 'after --force-recreate: '; "${COMPOSE[@]}" -f compose.yaml logs api 2>&1 | grep 'listening' | tail -n1
echo "(Docker Compose re-creates on an image change by itself.)"

step "Stretch 2 - no healthy-wait: down -v, up -d, curl immediately"
"${COMPOSE[@]}" -f compose.yaml down -v >/dev/null 2>&1
"${COMPOSE[@]}" -f compose.yaml -f compose.no-wait.yaml up -d >/dev/null 2>&1
for t in 0 3 6; do sleep $((t ? 3 : 0)); printf 't+%ss: ' "$t"; api; done
"${COMPOSE[@]}" -f compose.yaml ps --format '{{.Names}}  {{.Status}}' 2>/dev/null | grep -E '_(db|api)_'
echo "-- api logs:"
"${COMPOSE[@]}" -f compose.yaml logs api 2>&1 | grep -E 'Error|ECONNREFUSED|starting up' | head -n2
echo "api started while PostgreSQL was still initialising. Its first query failed"
echo "(ECONNREFUSED), the unhandled rejection killed node, and with no restart policy the"
echo "container stays Exited, even after db turns healthy a few seconds later."
"${COMPOSE[@]}" -f compose.yaml start api >/dev/null 2>&1
until curl -fs -o /dev/null http://localhost:3000; do sleep 1; done
printf 'after "start api": '; api
echo "condition: service_healthy prevents this. Retrying in the app is the other half (Block 4)."

step "Stretch 3 - the web service from Exercise 3.7 in the same file"
"${COMPOSE[@]}" -f compose.yaml up -d >/dev/null 2>&1
curl -fsS http://localhost:8080 | grep '<h1>'
"${COMPOSE[@]}" -f compose.yaml ps --format '{{.Names}}  {{.Networks}}  {{.Ports}}' 2>/dev/null

printf '\n\033[1;32mStretch goals complete. Clean up with: %s cleanup\033[0m\n' "$0"
