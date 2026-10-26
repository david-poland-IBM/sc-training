# secrets/

Holds the Compose secret files used by `compose.prod.yaml`. **Never commit the `*.txt` files**
(they are excluded by `.gitignore`).

```bash
./scripts/make-secrets.sh --from-env   # reuse passwords from .env (existing postgres volume)
./scripts/make-secrets.sh              # random passwords (fresh volumes only)
```

| File | Used by |
|---|---|
| `admin_password.txt` | MSR Administrator (`$env{ADMIN_PASSWORD}` via `secrets-entrypoint.sh`) |
| `db_password.txt` | PostgreSQL (`POSTGRES_PASSWORD_FILE`) and MSR (`$env{DB_PASSWORD}`) |
| `apigw_admin_password.txt` | API Gateway Administrator (`SAG_IS_ADMIN_PASSWORD`) |

Files are bind-mounted at `/run/secrets/<name>`; they must be readable by UID 1724 (`chmod 644`).
In real environments use the enterprise vault (HashiCorp Vault / CyberArk) instead of files.
