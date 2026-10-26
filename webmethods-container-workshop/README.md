# webMethods in Containers — Swisscom 3-Day Hands-On Workshop

Workshop material for the IBM webMethods Expert Labs workshop *webMethods in Containers*
(Podman and podman-compose, Docker-compatible; IBM webMethods Microservices Runtime 12.1).

```
webmethods-container-workshop/
├── packages/SwisscomLab/   sample IS package used by blocks 2–6 (Java services, source included)
├── block1/   Container fundamentals         exercises/  capstone/ (database by hand)        solution/
├── block2/   First webMethods container     exercises/  capstone/ (Capstone 2)                   solution/
├── block3/   Building images & Compose      exercises/  capstone/ (one compose.yaml)        solution/
├── block4/   webMethods stacks              exercises/  capstone/ (Capstone 4: MSR + UM + PG)    solution/
├── block5/   The Swisscom shape             exercises/  capstone/ (Capstones 5 + 6)             solution/ (+ runbook, CI)
└── block6/   Production readiness           exercises/  capstone/ → block5/capstone         solution/ → block5/solution, stretch/
```

Every block folder has a README listing its exercises. Step-by-step instructions: **Participant Workbook**.

## Container images (all public registries)

| Component | Image | Registry access |
|---|---|---|
| Microservices Runtime | `ibmwebmethods.azurecr.io/webmethods-microservicesruntime:12.1.0.3` | IBMid + token from <https://containers.webmethods.io> |
| Universal Messaging | `ibmwebmethods.azurecr.io/universalmessaging-server:12.1.0.0` | same |
| API Gateway | `ibmwebmethods.azurecr.io/apigateway-minimal:11.1.0.14` | same (IBM publishes no 12.1 API Gateway image; 11.1 fronts MSR 12.1 without issues) |
| PostgreSQL | `docker.io/library/postgres:16` | anonymous |
| nginx | `docker.io/library/nginx:1.27-alpine` | anonymous |
| OpenSearch | `docker.io/opensearchproject/opensearch:2.19.4` (API Gateway store), `:2.15.0` (Graylog) | anonymous |
| Graylog / MongoDB | `docker.io/graylog/graylog:6.1`, `docker.io/library/mongo:7.0` | anonymous |
| Fluent Bit | `docker.io/fluent/fluent-bit:3.1` | anonymous |
| Trivy (CI) | `docker.io/aquasec/trivy:0.56.2` | anonymous |

```bash
podman login ibmwebmethods.azurecr.io
```

## Prerequisites

* Podman 5+ (Podman Desktop on macOS/Windows) and podman-compose 1.6+ (`pip install podman-compose` or `brew install podman-compose`);
  give the Podman machine ≥ 10 GB RAM for Capstones 5–6
* All commands use `podman` / `podman-compose`. Docker Desktop with Compose v2.24+ also works:
  substitute `docker` / `docker compose` (scripts: `ENGINE=docker COMPOSE="docker compose"`)
* VS Code + Git Bash (Windows) or a terminal (macOS/Linux)
* `curl`; IBM webMethods Service Designer 11.1 or later (optional, to open `packages/SwisscomLab`)

All capstones were validated end to end with Podman 5 / docker-compose 2.29 on the images above (12.1 re-validation: 2026-10-14).
podman-compose 1.6 re-validation (Podman 6.1, 2026-10-14): Capstone 4 `verify.sh` all checks passed; Capstones 5–6 rolling update
0 failed of 81 requests; prod overlay secrets (0 passwords in `podman inspect`). API Gateway was not re-run under podman-compose.

The 12.1 images install to `/opt/webmethods` (11.1: `/opt/softwareag`) and ship IBM Semeru JDK 21.
API Gateway 11.1 still uses `/opt/softwareag`.

## The SwisscomLab package

| Service | Purpose | Used in |
|---|---|---|
| `swisscom.lab.health:info` | node name, environment, version (from `application.properties`) | Labs 1–3 |
| `swisscom.lab.db:createOrder`, `:listOrders` | JDBC to PostgreSQL | Labs 2–3 |
| `swisscom.lab.jms:sendOrder`, `:receiveOrder` | JMS via Universal Messaging queue `LabOrders` | Labs 2–3 |

Invoke with `curl -u Administrator:<pw> -H "Accept: application/json" http://localhost:5555/invoke/swisscom.lab.health/info`.
Java sources live in `code/source`; Capstone 5's multi-stage build recompiles them.
