# Capstone 2 — First Microservices Runtime Container (Day 1, 2h)

Full step-by-step instructions: **Participant Workbook, Block 2: Capstone 2**.

## What is in this folder

| File | Purpose |
|---|---|
| `application.properties` | Starter configuration file with three TODOs (Part 5) |
| `../../packages/SwisscomLab` | Pre-built sample package, bind-mounted into the container in Part 5 |

## Image used

```
ibmwebmethods.azurecr.io/webmethods-microservicesruntime:12.1.0.3
```

Log in once per machine with the IBMid and the registry token from
<https://containers.webmethods.io>:

```bash
podman login ibmwebmethods.azurecr.io      # Docker: docker login …
```

## Key facts about the MSR image

| Item | Value |
|---|---|
| Install directory | `/opt/webmethods/IntegrationServer` (no `instances/default` in MSR) |
| Runs as | `sagadmin`, UID/GID `1724` |
| Java | IBM Semeru Runtime 21 (OpenJ9), full JDK incl. `javac` in `/opt/webmethods/jvm/jvm` |
| Ports | `5555` HTTP, `5543` HTTPS, `9999` diagnostic |
| Health | `/health`, `/health/liveness`, `/health/readiness` (anonymous) |
| Metrics | `/metrics` (Prometheus format, anonymous) |
| Config file | `/opt/webmethods/IntegrationServer/application.properties` |
| Logs | `/opt/webmethods/IntegrationServer/logs` (server log also goes to stdout) |

Reference solution: `../solution/`.
