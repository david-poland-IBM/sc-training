# Runbook — Rolling update of the MSR nodes (podman-compose)

**Scope:** two Microservices Runtime nodes (`msr-1`, `msr-2`) behind the nginx
load balancer `loadbalancer`, API Gateway in front. One node is updated at a time;
the other keeps serving.

**Automated version:** `scripts/rolling-update.sh <version>` performs exactly these steps.

## Before you start

| Check | Command | Expected |
|---|---|---|
| Both nodes healthy | `podman-compose ps` | `msr-1`, `msr-2` → `healthy` |
| New image builds | `APP_VERSION=<new> podman-compose build msr-1` | `Successfully tagged …:<new>` |
| Traffic monitor running | `./scripts/curl-loop.sh` (second terminal) | steady `200` lines |

## Per node (start with `msr-2`, then `msr-1`)

1. **Drain** — append ` down` to the node's line in `nginx/upstream.conf`, then  
   `podman-compose exec loadbalancer nginx -c /etc/nginx/workshop/nginx.conf -s reload`  
   *Edit the file in place (editor that keeps the inode, or the script).* `sed -i`
   replaces the file and Podman/Docker Desktop file sharing can briefly show it as
   missing, so the reload fails.
2. **Wait 2–5 s** for in-flight requests to finish.
3. **Graceful stop** — `podman-compose stop msr-2`  
   Measured in the workshop: a clean MSR shutdown takes **~13 s**. With the default
   10 s stop timeout (Podman and Docker) the container is SIGKILLed (exit code **137**). Hence
   `stop_grace_period: 90s` and `SAG_IS_SHUTDOWN_WAIT_TIME=60` in `compose.prod.yaml`.
4. **Re-create with the new version** —  
   `APP_VERSION=<new> podman-compose -f compose.yaml -f compose.prod.yaml up -d --no-deps --no-build msr-2`
5. **Wait for `healthy`** (readiness, not just "Up") — measured: 65–75 s.
6. **Undrain** — remove ` down`, reload nginx. The reload also re-resolves `msr-2`,
   which has a new container IP after re-creation.
7. Watch the curl loop: requests now show `msr-2 v<new>`.

## After both nodes

* Set `APP_VERSION=<new>` in `.env`, otherwise the next `compose up` rolls back.
* Validation result: **0 failed of 161 requests** during the full update.

## Rollback

Run the same procedure with the previous version (the old image tag is still in the
local image store / registry).

## Why this is manual in Compose

Compose has no rolling-update orchestration. A Kubernetes `Deployment` with
`strategy: RollingUpdate`, a `readinessProbe` on `/health/readiness` and
`terminationGracePeriodSeconds` automates every step above.
