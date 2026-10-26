#!/usr/bin/env bash
# Calls the workshop API once per INTERVAL seconds and prints status, node and version.
# Run it in a second terminal during the rolling update; Ctrl+C prints a summary.
#
#   ./scripts/curl-loop.sh                      # through API Gateway (default)
#   TARGET=lb ./scripts/curl-loop.sh            # directly through nginx (non-prod only)
#   DURATION=300 ./scripts/curl-loop.sh         # stop automatically after 300s
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

if [ -f secrets/admin_password.txt ]; then PW=$(cat secrets/admin_password.txt); else PW="${ADMIN_PASSWORD:-}"; fi
case "${TARGET:-gw}" in
  lb) URL="http://localhost:8080/invoke/swisscom.lab.health/info" ;;
  *)  URL="http://localhost:5556/gateway/SwisscomLabOrders/1.0/swisscom.lab.health/info" ;;
esac
INTERVAL="${INTERVAL:-0.5}"
DURATION="${DURATION:-0}"

ok=0; fail=0; start=$(date +%s)
summary() { echo; echo "requests: $((ok+fail))  ok: $ok  failed: $fail"; exit 0; }
trap summary INT TERM

echo "target: $URL"
while :; do
  out=$(curl -s -m 10 -u "Administrator:$PW" -H "Accept: application/json" -w '\n%{http_code}' "$URL")
  code=$(printf '%s' "$out" | tail -n1)
  body=$(printf '%s' "$out" | sed '$d')
  if [ "$code" = "200" ]; then
    ok=$((ok+1))
    node=$(printf '%s' "$body" | sed -n 's/.*"hostname":"\([^"]*\)".*/\1/p')
    ver=$(printf '%s' "$body" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
    printf '%s  200  %-6s v%s\n' "$(date +%H:%M:%S)" "$node" "$ver"
  else
    fail=$((fail+1))
    printf '%s  %s  FAILED\n' "$(date +%H:%M:%S)" "$code"
  fi
  if [ "$DURATION" -gt 0 ] && [ $(( $(date +%s) - start )) -ge "$DURATION" ]; then summary; fi
  sleep "$INTERVAL"
done
