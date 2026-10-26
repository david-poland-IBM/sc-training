#!/usr/bin/env bash
# Creates the global "GELF UDP" input (port 12201) in Graylog through its REST API.
# Run once after "compose ... -f compose.logging.yaml up -d" - inputs are stored in
# MongoDB, so they survive restarts as long as the graylog-mongo volume exists.
#   GRAYLOG_PASSWORD=admin ./graylog/create-gelf-input.sh
set -euo pipefail
GL="${GRAYLOG_URL:-http://localhost:9010}"
AUTH="admin:${GRAYLOG_PASSWORD:-admin}"

printf 'waiting for Graylog API '
for _ in $(seq 1 60); do
  curl -fs -o /dev/null -u "$AUTH" "$GL/api/system/lbstatus" && break
  printf '.'; sleep 5
done; echo

if curl -fs -u "$AUTH" "$GL/api/system/inputs" | grep -q '"title":"GELF UDP"'; then
  echo "GELF UDP input already exists"; exit 0
fi

curl -fsS -u "$AUTH" -H 'X-Requested-By: workshop' -H 'Content-Type: application/json' \
  -X POST "$GL/api/system/inputs" -d '{
    "title": "GELF UDP",
    "type": "org.graylog2.inputs.gelf.udp.GELFUDPInput",
    "global": true,
    "configuration": {
      "bind_address": "0.0.0.0",
      "port": 12201,
      "recv_buffer_size": 262144,
      "decompress_size_limit": 8388608
    }
  }'
echo; echo "GELF UDP input created. Search in Graylog for:  source:msr-1  or  logtype:security"
