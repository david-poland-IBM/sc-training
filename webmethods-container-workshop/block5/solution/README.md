# Blocks 5 + 6 — Reference Solution (Capstones 5 and 6)

```bash
cp .env.example .env
podman-compose up -d --build                                  # base stack
./apigw/register-api.sh                                       # API on the gateway
./scripts/make-secrets.sh --from-env                          # prod secrets (reuse .env values)
podman-compose -f compose.yaml -f compose.prod.yaml up -d     # prod overlay
./scripts/curl-loop.sh                                        # terminal 2
PROD=1 ./scripts/rolling-update.sh 1.1.0                      # rolling update
podman-compose -f compose.yaml -f compose.prod.yaml -f compose.logging.yaml up -d
GRAYLOG_PASSWORD=admin ./graylog/create-gelf-input.sh         # Graylog input
```
Use `ENGINE=podman` with the scripts on Podman.

| File | Content |
|---|---|
| `compose.yaml` | 2 × MSR (YAML anchor), nginx, API Gateway + OpenSearch store, UM, PostgreSQL |
| `compose.prod.yaml` | Secrets, `!reset`, limits, heap sizing, `restart`, `stop_grace_period`, no LB port |
| `compose.logging.yaml` | Graylog 6.1 + MongoDB + OpenSearch + Fluent Bit sidecar |
| `msr/Containerfile` | Multi-stage: compile package in builder stage, copy only the result |
| `config/application.properties`, `application.prod.properties` | Same `$env{}` names for both |
| `scripts/secrets-entrypoint.sh` | `/run/secrets/*` → process environment, then `exec` the product start script |
| `scripts/rolling-update.sh` | Automated drain → stop → recreate → wait healthy → undrain |
| `scripts/check_msr.sh` | Nagios/OP5 plugin using `/health/readiness` + `/metrics` |
| `apigw/` | OpenAPI spec + import/activate script |
| `docs/RUNBOOK-rolling-update.md` | Operator runbook (deliverable) |
| `ci/.gitlab-ci.yml` | build → Trivy scan → push → manual deploy-dev |

Capstone 6 stretch goals (test-external overlay, Kubernetes mapping, Nagios/OP5, CI answers): `../../block6/solution/stretch/`.

## Things the validation run proved (and the guide teaches)

* `$file{…}` is **not** resolved by MSR 12.1 in `application.properties`; use `$env{…}` and
  feed it from secret files (wrapper here, `secretKeyRef` in Kubernetes).
* `!reset` does **not** work through a YAML merge key (`<<: *anchor`).
* `/rest/apigateway/health` requires authentication (anonymous → 401).
* API Gateway 11.1 minimal image uses an **OpenSearch 2.19** client: run an external OpenSearch.
* Podman does **not** support the `gelf` log driver; hence the Fluent Bit sidecar.
* `sed -i` on a bind-mounted nginx config can make the reload fail; edit in place.
* Two MSR nodes need different JMS client IDs (`JMS_CLIENT_ID`).
