# Capstones 5 and 6 — Production-Ready Compose Setup (Block 5 + Block 6)

Full instructions: **Participant Workbook, Block 5 (Capstone 5, Parts 1–3) and Block 6 (Capstone 6, Parts 1–3)**. Reference solution: `../solution/`.

| Path | Status | What it is |
|---|---|---|
| `compose.yaml` | TODO | Add `msr-2`, `loadbalancer`, `apigw-store`, `apigateway` |
| `compose.prod.yaml` | TODO | Secrets, prod properties + entrypoint mounts, limits, restart policy, graceful shutdown |
| `compose.logging.yaml` | provided | Graylog + Fluent Bit sidecar |
| `msr/Containerfile` | provided | Multi-stage build (compiles the package in a builder stage) |
| `config/application.properties` | provided | Same `$env{}` file for all nodes |
| `config/application.prod.properties` | provided | Production variant (same `$env{}` names, larger JDBC pool, 14 days audit logs); `compose.prod.yaml` mounts it over the base file |
| `nginx/nginx.conf`, `nginx/upstream.conf` | provided | Round-robin over `msr-1:5555`, `msr-2:5555` |
| `apigw/register-api.sh` | provided | Imports + activates `SwisscomLabOrders` on API Gateway |
| `graylog/create-gelf-input.sh` | provided | Creates the GELF UDP input in Graylog |
| `scripts/make-secrets.sh` | provided | Writes `secrets/*.txt` |
| `scripts/secrets-entrypoint.sh` | provided | Exports `/run/secrets/*` into the process environment |
| `scripts/curl-loop.sh` | provided | Request loop for the rolling-update exercise |
| `scripts/check_msr.sh` | provided | Nagios/OP5-style check (stretch goal) |

## Ports on your laptop

| Port | Service |
|---|---|
| 8080 | nginx load balancer (non-prod only) |
| 9072 | API Gateway UI |
| 5556 | API Gateway runtime (`/gateway/SwisscomLabOrders/1.0/...`) |
| 9010 | Graylog UI (logging overlay) |

## Memory

The full stack (2 × MSR, UM, PostgreSQL, API Gateway, 2 × OpenSearch, Graylog) needs about
**8–9 GB** for the container engine. On Podman Desktop give the machine ≥ 10 GB
(`podman machine set --memory 10240`), or run the logging overlay without API Gateway.
