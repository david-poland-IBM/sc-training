#!/bin/sh
# ---------------------------------------------------------------------
# Compose-secrets wrapper for webMethods containers (MSR, API Gateway).
#
# MSR resolves $env{NAME} in application.properties, but does NOT read
# arbitrary files ($file{...} only applies to vault connection settings).
# This wrapper turns every Compose secret file into an environment variable
# of the running PROCESS only:
#     /run/secrets/admin_password  ->  ADMIN_PASSWORD
#     /run/secrets/db_password     ->  DB_PASSWORD
# The values never appear in the container configuration, so
# "podman inspect" does not show them (unlike "environment:" entries).
#
# "exec" replaces this shell with the product start script, which stays
# PID 1 and therefore still receives SIGTERM for a graceful shutdown.
#
# Usage (compose.prod.yaml):
#   entrypoint: ["/bin/sh", "/opt/workshop/secrets-entrypoint.sh"]
#   command:    ["/opt/webmethods/IntegrationServer/bin/startContainer.sh"]
# ---------------------------------------------------------------------
set -eu

if [ -d /run/secrets ]; then
  for f in /run/secrets/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f" | tr '[:lower:]-.' '[:upper:]__')
    # read the file content verbatim (no trailing newline handling surprises)
    value=$(cat "$f")
    export "$name=$value"
  done
fi

# Optional alias: API Gateway reads its admin password from SAG_IS_ADMIN_PASSWORD
if [ -n "${APIGW_ADMIN_PASSWORD:-}" ] && [ -z "${SAG_IS_ADMIN_PASSWORD:-}" ]; then
  export SAG_IS_ADMIN_PASSWORD="$APIGW_ADMIN_PASSWORD"
fi

exec "$@"
