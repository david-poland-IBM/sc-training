#!/usr/bin/env bash
# =====================================================================
# Block 1 capstone - "A database stack by hand" (reference solution)
#
#   ./capstone1-solution.sh            # run every step
#   ./capstone1-solution.sh cleanup    # remove everything it created
#
# Block 3 replaces all of this with one compose.yaml.
# =====================================================================
set -euo pipefail
ENGINE="${ENGINE:-podman}"
PG_IMAGE=docker.io/library/postgres:16
PW=Shop-Secret-2026

if [ "${1:-}" = "cleanup" ]; then
  $ENGINE rm -f shop-db 2>/dev/null || true
  $ENGINE volume rm -f shop-data 2>/dev/null || true
  $ENGINE network rm -f shop-net 2>/dev/null || true
  exit 0
fi

psql() {   # throw-away client container on the same network
  $ENGINE run --rm --network shop-net -e PGPASSWORD="$PW" "$PG_IMAGE" \
    psql -h shop-db -U shop -d shop -tA -c "$1"
}
start_db() {
  $ENGINE run -d --name shop-db --network shop-net \
    -e POSTGRES_USER=shop -e POSTGRES_PASSWORD="$PW" -e POSTGRES_DB=shop \
    -v shop-data:/var/lib/postgresql/data \
    --memory 512m --cpus 1 \
    --health-cmd 'pg_isready -U shop -d shop' --health-interval 5s --health-retries 10 \
    "$PG_IMAGE" >/dev/null
  printf 'waiting for shop-db '
  until [ "$($ENGINE inspect -f '{{.State.Health.Status}}' shop-db)" = healthy ]; do printf '.'; sleep 2; done
  echo ' healthy'
}

echo "== 1. network + volume"
$ENGINE network create shop-net >/dev/null
$ENGINE volume create shop-data >/dev/null

echo "== 2. database with limits and a healthcheck"
start_db

echo "== 3. write data from a second container, by NAME"
psql "CREATE TABLE orders (id serial PRIMARY KEY, item text, created timestamptz DEFAULT now());"
psql "INSERT INTO orders (item) VALUES ('router'), ('switch');"
psql "SELECT id, item FROM orders;"

echo "== 4. destroy the database container and re-create it"
$ENGINE rm -f shop-db >/dev/null
start_db
echo "rows after re-create: $(psql 'SELECT count(*) FROM orders;')   (expect 2)"

echo "== 5. limits as the engine sees them"
$ENGINE inspect shop-db --format 'memory={{.HostConfig.Memory}} nanoCPUs={{.HostConfig.NanoCpus}}'
$ENGINE stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}' shop-db
