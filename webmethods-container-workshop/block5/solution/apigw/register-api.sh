#!/usr/bin/env bash
# Registers and activates the SwisscomLabOrders API on API Gateway via its REST API.
# Usage: ./apigw/register-api.sh          (reads APIGW_ADMIN_PASSWORD from .env)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

GW="${GW_URL:-http://localhost:5556}"
AUTH="Administrator:${APIGW_ADMIN_PASSWORD:?APIGW_ADMIN_PASSWORD not set}"
SPEC=apigw/orders-api.openapi.json

echo "== Importing $SPEC"
RESP=$(curl -fsS -u "$AUTH" -H "Accept: application/json" \
  -F "type=openapi" -F "apiName=SwisscomLabOrders" -F "apiVersion=1.0" \
  -F "file=@${SPEC};type=application/json" \
  "$GW/rest/apigateway/apis")
API_ID=$(printf '%s' "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["apiResponse"]["api"]["id"])')
echo "   API id: $API_ID"

echo "== Activating"
curl -fsS -u "$AUTH" -H "Accept: application/json" -X PUT \
  "$GW/rest/apigateway/apis/$API_ID/activate" >/dev/null
echo "   active"

echo "== Test call through the gateway"
echo "   $GW/gateway/SwisscomLabOrders/1.0/swisscom.lab.health/info"
curl -fsS -u "Administrator:${ADMIN_PASSWORD:-}" -H "Accept: application/json" \
  "$GW/gateway/SwisscomLabOrders/1.0/swisscom.lab.health/info"; echo
