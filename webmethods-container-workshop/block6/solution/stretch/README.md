# Capstone 6 — Stretch Goals (Reference Solution)

Capstone 6 runs in `block5/capstone/`, so these stretch goals do too.

| Stretch goal | Solution |
|---|---|
| Monitoring with Nagios / OP5 | `check-nodes.sh` (this folder) + expected output below |
| `compose.test-external.yaml` | [`compose.test-external.yaml`](compose.test-external.yaml) (this folder) |
| Compose → Kubernetes mapping | [`compose-to-kubernetes.md`](compose-to-kubernetes.md) (this folder) |
| Where does CI run what? | Answer below ([`block5/solution/ci/.gitlab-ci.yml`](../../../block5/solution/ci/.gitlab-ci.yml)) |

## Monitoring with Nagios / OP5

```bash
./check-nodes.sh                                    # stack in ../../../block5/capstone, prod overlay
STACK_DIR=../../../block5/solution ./check-nodes.sh
```

It runs `scripts/check_msr.sh` inside each node and provokes every state the plugin returns:

```text
msr-1  (defaults)                   OK - MSR ready, heap 29% | heap_pct=29%;80;90 threads=2
  -> exit=0
msr-1  -w 5                         WARNING - heap 29% | heap_pct=29%;5;90 threads=2
  -> exit=1
msr-1  -w 1 -c 5                    CRITICAL - heap 29% | heap_pct=29%;1;5 threads=2
  -> exit=2
msr-1  -u http://localhost:5599     CRITICAL - http://localhost:5599 not reachable
  -> exit=2
```

A **real** CRITICAL: stop UM, wait ~20 s, check again, then start UM again.

```bash
DC="podman-compose -f compose.yaml -f compose.prod.yaml"     # bash; in zsh use ${=DC}
$DC stop um
$DC exec -T msr-1 bash -s -- -u http://localhost:5555 < scripts/check_msr.sh; echo "exit=$?"
$DC start um
```

```text
CRITICAL - readiness HTTP 503, DOWN: IS_UM_CONNECTION LAB_UM_JMS | heap_pct=20%;80;90 threads=2
exit=2
```

About 10 s after UM is back, the check returns `OK` again with no MSR restart: the UM
connection and JMS alias reconnect on their own. (That works here because they were up at
startup. Block 4's silent failure only happens when they were *down* when MSR started.)

What the output means:

* **Exit code** = state (0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN). OP5 only looks at this.
* **Text before `|`** = the status line OP5 shows and sends in notifications.
* **Perfdata after `|`** = `label=value;warn;crit`. OP5 graphs `heap_pct` and draws the thresholds.
* `/health/readiness` and `/metrics` are anonymous, so the check needs no credentials.

In OP5 the plugin would run either on each container host via the agent
(`podman exec <node> …`, as here) or centrally against each node's URL once nodes are
reachable. Behind nginx, a central check sees only *one* node per call, so check nodes
directly, not the load balancer.

## `compose.test-external.yaml`

Reference: [`compose.test-external.yaml`](compose.test-external.yaml). Run it from `block5/capstone/`:

```bash
podman-compose -f compose.yaml -f ../../block6/solution/stretch/compose.test-external.yaml config   # check the merge first
```

Key points:

* Only what **differs** goes in the overlay: `LAB_ENV`, the load balancer's ports
  (`!reset []`) and the Gateway's ports (`!override` with `8443:5543` only).
* `!reset` removes a value inherited from the base file. `!override` *replaces* the list
  instead of appending to it. Without either, overlay port lists are **merged** and
  nginx's 8080 would stay published.

## Compose → Kubernetes mapping

Reference: [`compose-to-kubernetes.md`](compose-to-kubernetes.md). The short version:

| Compose | Kubernetes |
|---|---|
| `msr-1` + `msr-2` (anchor) | `Deployment`, `replicas: 2` + `Service` |
| `um`, `postgres` (own volume) | `StatefulSet` + `PersistentVolumeClaim` (or managed DB) |
| `application.properties` mount | `ConfigMap` |
| `secrets:` + `secrets-entrypoint.sh` | `Secret` → `env.valueFrom.secretKeyRef` (no wrapper needed) |
| `healthcheck` / `start_period` | `readinessProbe` + `livenessProbe` / `startupProbe` |
| `stop_grace_period: 90s` | `terminationGracePeriodSeconds: 90` |
| nginx + `rolling-update.sh` | `Service`/`Ingress` + `strategy: RollingUpdate` |
| `compose.prod.yaml` | Helm `values-prod.yaml` / Kustomize overlay |

## Where does CI run what? (`block5/solution/ci/.gitlab-ci.yml`)

| Step | Job (stage) | Runs where |
|---|---|---|
| **Build** (multi-stage, Exercise 5.1) | `build-image` (build) | Any GitLab runner able to run Podman (`quay.io/podman/stable`). Logs in to `ibmwebmethods.azurecr.io` with masked CI variables. The image is passed on as a `.tar` artifact, **not** pushed yet |
| **Trivy gate** (Exercise 5.3) | `scan-image` (scan) | Any runner, `aquasec/trivy` image, scans the `.tar`. `--exit-code 1 --ignore-unfixed --severity HIGH,CRITICAL` fails the pipeline, so `push` never runs for a vulnerable image |
| Push | `push-image` (push) | Only on the default branch or a tag. Pushes to the GitLab registry; a Git tag also gets a version tag |
| **Rolling update** (Capstone 6 Part 2) | `deploy-dev` (deploy) | `when: manual` on the default branch, on the **Dev container host** itself (runner tag `swisscom-dev-podman-host`). Runs `PROD=1 ./scripts/rolling-update.sh "$TAG"`: one node at a time, never `compose up` for all |

Things to discuss for Swisscom: scan *before* push, so nothing unscanned reaches the registry.
Test/Prod deploy jobs would copy `deploy-dev` with their own runner tag, a protected
environment and approval. The stock 12.1 base image currently **fails** the Trivy gate
(fixable CRITICALs, Oct 2026), so expect to need a `.trivyignore` with documented exceptions or
a newer fix level before the pipeline goes green.
