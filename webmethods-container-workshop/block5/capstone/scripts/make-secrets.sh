#!/usr/bin/env bash
# Creates the secret files used by compose.prod.yaml under ./secrets/.
#   ./scripts/make-secrets.sh            # random passwords (use with fresh volumes)
#   ./scripts/make-secrets.sh --from-env # reuse the passwords from .env
#                                        # (needed when the postgres volume already exists,
#                                        #  because postgres only applies a password on first init)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p secrets

if [ "${1:-}" = "--from-env" ]; then
  set -a; . ./.env; set +a
  printf '%s' "$ADMIN_PASSWORD"       > secrets/admin_password.txt
  printf '%s' "$DB_PASSWORD"          > secrets/db_password.txt
  printf '%s' "$APIGW_ADMIN_PASSWORD" > secrets/apigw_admin_password.txt
else
  for s in admin_password db_password apigw_admin_password; do
    # 20 random alphanumerics + a fixed suffix that satisfies IS password rules
    printf '%s' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)#9a" > "secrets/$s.txt"
  done
fi

# Readable by the container user (sagadmin, UID 1724). Compose file secrets
# are plain bind mounts outside Swarm, so the host file mode applies.
chmod 644 secrets/*.txt
ls -l secrets/
