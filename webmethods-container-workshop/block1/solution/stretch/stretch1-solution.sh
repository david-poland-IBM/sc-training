#!/usr/bin/env bash
# =====================================================================
# Block 1 capstone - STRETCH GOAL (reference solution)
#   nginx serving block1/exercises/site on shop-net, and the database
#   reached by name from inside it with "getent hosts shop-db".
#
#   ../capstone1-solution.sh          # first: shop-net + shop-db must exist
#   ./stretch1-solution.sh            # then the stretch goal
#   ./stretch1-solution.sh cleanup    # remove only what this script created
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"
ENGINE="${ENGINE:-podman}"
NGINX_IMAGE=docker.io/library/nginx:1.27-alpine
SITE="$(cd ../../exercises/site && pwd)"

if [ "${1:-}" = "cleanup" ]; then
  $ENGINE rm -f shop-web 2>/dev/null || true
  exit 0
fi

$ENGINE network exists shop-net && $ENGINE container exists shop-db || {
  echo "shop-net / shop-db not found - run ../capstone1-solution.sh first"; exit 1; }

echo "== 1. nginx on the SAME user-defined network as the database"
$ENGINE rm -f shop-web 2>/dev/null || true
$ENGINE run -d --name shop-web --network shop-net -p 8081:80 \
  -v "$SITE:/usr/share/nginx/html:ro" \
  "$NGINX_IMAGE" >/dev/null
sleep 2
curl -fsS http://localhost:8081 | grep '<h1>'

echo "== 2. name resolution from inside the web container"
$ENGINE exec shop-web getent hosts shop-db
echo "   (shop-db's IP on shop-net - resolved by the network's DNS, not /etc/hosts)"

echo "== 3. reachable, not just resolvable: TCP connect to PostgreSQL's port"
$ENGINE exec shop-web nc -z -w 3 shop-db 5432 && echo "   shop-db:5432 open"

echo "== 4. counter-check: a container on the DEFAULT network cannot resolve shop-db"
$ENGINE run --rm "$NGINX_IMAGE" getent hosts shop-db \
  || echo "   no answer (exit $?) - the default network has no DNS for container names"
