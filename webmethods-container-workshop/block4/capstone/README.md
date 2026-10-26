# Capstone 4 — Multi-Container Environment (Day 2, 3h)

Full instructions: **Participant Workbook, Block 4: Capstone 4**. Reference solution: `../solution/`.

| Path | Status | What it is |
|---|---|---|
| `compose.yaml` | TODO | PostgreSQL provided; UM and MSR services to complete |
| `msr/Containerfile` | TODO | Custom MSR image: JDBC driver + driver alias + SwisscomLab package |
| `msr/jdbc/PostgreSQL_JDBC_Driver.xml` | provided | JDBC driver alias definition |
| `config/application.properties` | TODO | JDBC pool, UM and JMS configuration |
| `db/init.sql` | provided | Creates the `orders` table on first start |
| `.env.example` | provided | Copy to `.env` (never commit `.env`) |
| `scripts/verify.sh` | provided | Checks health, JDBC and JMS end to end |

## Images

| Service | Image |
|---|---|
| MSR (base) | `ibmwebmethods.azurecr.io/webmethods-microservicesruntime:12.1.0.3` |
| Universal Messaging | `ibmwebmethods.azurecr.io/universalmessaging-server:12.1.0.0` |
| PostgreSQL | `docker.io/library/postgres:16` |
| JDBC driver | `org.postgresql:postgresql:42.7.4` (Maven Central) |

## Done when

`./scripts/verify.sh` (or `ENGINE=podman ./scripts/verify.sh`) ends with **All checks passed.**
