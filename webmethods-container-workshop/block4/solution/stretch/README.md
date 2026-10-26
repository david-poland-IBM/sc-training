# Capstone 4 — Stretch Goals (Reference Solution)

| File | Stretch goal |
|---|---|
| `stretch4-solution.sh` | Runs all three against the stack in `block4/solution/` |
| `compose.networks.yaml` | Overlay: second network `frontend`, postgres + um on `backend` only (goal 2) |

```bash
cd block4/solution
./stretch/stretch4-solution.sh            # creates .env from .env.example if missing
./stretch/stretch4-solution.sh cleanup    # down -v (base file + overlay)
```

## 1. Three messages nobody receives

```bash
for i in 1 2 3; do
  curl -fsS -u "Administrator:$ADMIN_PASSWORD" -H "Accept: application/json" \
    "http://localhost:5555/invoke/swisscom.lab.jms/sendOrder?message=stretch-$i"; echo
done
```

The queue depth is in **`MonitorChannels`** (`Events`). `PeekQueue` shows the waiting
messages without consuming them:

```bash
podman-compose exec -T um timeout 10 runUMTool.sh MonitorChannels \
  -rname=nsp://localhost:9000 -channelname=LabOrders -format=plaintext | grep -m1 '^Events'
podman-compose exec -T um timeout 10 runUMTool.sh PeekQueue \
  -rname=nsp://localhost:9000 -queuename=LabOrders | grep 'Event data'
```

```text
Events                : 3
Event data : stretch-1
Event data : stretch-2
Event data : stretch-3
```

`timeout` is needed because both tools keep running until they get Enter.

**Why not `GetQueueInfo`?** It sounds right, but it only prints the queue's **attributes**
(type, TTL, capacity, storage), not how many events are waiting. It also takes `-qname=`,
while `PeekQueue` and `CreateQueue` take `-queuename=`.

After three `receiveOrder` calls, `Events : 0`. The messages survived in UM even though no
consumer was there, which is the point of a queue. They also survive an MSR restart.

## 2. A second network

`compose.networks.yaml` adds a `frontend` network that only `msr` joins. `postgres` and `um`
stay on `backend`.

```bash
podman-compose -f compose.yaml -f stretch/compose.networks.yaml down
podman-compose -f compose.yaml -f stretch/compose.networks.yaml up -d
podman run --rm --network wm-block4_frontend docker.io/library/postgres:16 pg_isready -h postgres -t 3
```

```text
frontend  -> postgres   postgres:5432 - no response
frontend  -> 10.89.0.2  10.89.0.2:5432 - no response
backend   -> postgres   postgres:5432 - accepting connections
frontend  -> msr        msr:5555 - open
```

**Name vs. IP:** without extra options, Podman routes between bridge networks through the
host. `postgres` can't be *resolved* from `frontend`, but `pg_isready -h <postgres IP>`
still answers **accepting connections**. Separate networks give you separate DNS, not a
firewall. The overlay therefore sets `driver_opts: { isolate: "true" }` (netavark) on both
networks, which drops traffic between them. Network options apply only when the network is
created, hence `down` first. Docker isolates bridge networks from each other by default.

`msr` is on both networks, so it still reaches its database (`listOrders` works) and is the
only door from `frontend` into `backend`. Block 5 builds the same shape: API Gateway and nginx
in front, data services behind.

## 3. Used heap in `/metrics`

```bash
curl -s http://localhost:5555/metrics | grep -E '^sag_is_(used|max|free)_memory_bytes'
```

```text
sag_is_max_memory_bytes{host="1a9fa0cb59b0"} 1073741824 1792572668852
sag_is_free_memory_bytes{host="1a9fa0cb59b0"} 334415872 1792572668852
sag_is_used_memory_bytes{host="1a9fa0cb59b0"} 202455040 1792572668852
used heap: 196 MiB of 1024 MiB (19%)
```

The format is Prometheus: `name{labels} value timestamp`. `max` is `JAVA_MAX_MEM` (1024M).
`check_msr.sh` in Block 6 computes `used / max` from exactly these two lines.
Don't confuse it with `sag_is_server_used_memory_mbytes`, which is the **host's** (Podman
machine's) memory, not the JVM heap.
