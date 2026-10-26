# Capstone 2 — Stretch Goals (Reference Solution)

```bash
../capstone2-solution.sh           # msr-capstone2 must be running (Part 5 state)
./stretch2-solution.sh             # NAME=<container> to point it at another first MSR
./stretch2-solution.sh cleanup     # removes msr-capstone2-b only
```

## 1. A second MSR on host port 15555

```bash
podman run -d --name msr-capstone2-b -p 15555:5555 \
  -e SAG_IS_ADMIN_PASSWORD='Init1al!Change' \
  ibmwebmethods.azurecr.io/webmethods-microservicesruntime:12.1.0.3
```

```text
msr-capstone2    0.0.0.0:5555->5555/tcp, 5543/tcp, 9999/tcp
msr-capstone2-b  0.0.0.0:15555->5555/tcp, 5543/tcp, 9999/tcp
localhost:5555/health/readiness  -> HTTP 200
localhost:15555/health/readiness -> HTTP 200
```

**Why does the container port stay 5555?** Each container has its own network namespace,
so both MSRs can listen on 5555 *inside* without conflict. Only the **host** has one port 5555.
`-p HOST:CONTAINER` maps a free host port onto the unchanged container port. The image, its
configuration and the health check URL inside the container never change. This is how you
run several environments side by side on one host.

## 2. `LOG_FORMAT=json`

Environment variables are fixed when a container is **created**. `podman restart` can't
add one, so the container has to be removed and run again with `-e LOG_FORMAT=json`.

Default format:

```text
ISSERVER|| 2026-10-21 10:36:32 CEST [ISS.0014.0002I] (tid=24) Initialization completed in 21,595 milliseconds.
```

`LOG_FORMAT=json`, one JSON object per line:

```json
{
  "accid": "",
  "envname": "600501b06a2e",
  "id": "PIE",
  "file": "server.log",
  "timestamp": "2026-10-21T10:39:12.534+02:00",
  "level": "INFO",
  "logger": "[IS.SERVER.ISS.0014]",
  "thread": "24",
  "message": "[ISS.0014.0002I] Initialization completed in 21,583 milliseconds. "
}
```

A log shipper (Fluent Bit → Graylog in Block 6) can index `level`, `logger` and `timestamp`
directly, with no regex parsing. `envname` is the container hostname, which tells you which
node a line came from. `file` tells you which IS log the line belongs to.

## 3. The password in `podman inspect`

```bash
podman inspect msr-capstone2 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -i password
```

```text
ADMIN_PASSWORD=Init1al!Change
```

Every `-e` value is stored in the container's configuration in plain text. Anyone who can
run `podman inspect` sees it, and so does anyone reading shell history or a compose file.
Block 6 mounts the password as a **secret file** under `/run/secrets/`, which doesn't appear
in `Config.Env`.
