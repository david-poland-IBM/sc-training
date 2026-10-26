# Day 2 — Reference Solution (Capstone 4)

```bash
cp .env.example .env
podman-compose config -q && podman-compose up -d --build
./scripts/verify.sh                 # ENGINE=podman ./scripts/verify.sh for Podman
podman-compose down -v              # clean up (deletes the volumes!)
```

| File | Notes |
|---|---|
| `compose.yaml` | Healthcheck-gated `depends_on`, service names in all URLs, MSR readiness probe |
| `msr/Containerfile` | Base MSR 12.1 + PostgreSQL JDBC driver + driver alias + SwisscomLab package |
| `config/application.properties` | Admin password, global variables, JDBC pool, UM messaging, JNDI + JMS alias |
| `scripts/verify.sh` | Health, config, JDBC insert/select, JMS send/receive, UM queue listing |

## Part 6 — what you should observe

| Scenario | Readiness | Behaviour |
|---|---|---|
| MSR started alone (`up -d --no-deps msr`) | **503** | DB call: `The connection attempt failed`; JMS: `alias LAB_UM_JMS is disabled` |
| Then `postgres` and `um` started, **without** restarting MSR | **200** | JDBC works again, but the JMS alias **stays disabled** and is no longer reported in readiness — a *silent* failure |
| UM stopped while everything runs | **503** (liveness stays 200) | UMAliases/JMS DOWN; recovers by itself ~15–30 s after UM is back |
| Normal start with `condition: service_healthy` | 200 | Everything connected at first start |

The second row is why `depends_on: condition: service_healthy` matters even though MSR
retries connections. An alias that fails during startup is not retried.
