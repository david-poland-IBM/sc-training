# Capstone 5–6 stack — Compose → Kubernetes mapping (stretch goal solution)

| Compose element (Capstones 5–6) | Kubernetes object | Notes for the follow-up engagement |
|---|---|---|
| `msr-1`, `msr-2` (same image, 2 copies) | `Deployment` (replicas: 2) + `Service` | IBM Helm chart: <https://github.com/IBM/webmethods-helm-charts> (microservicesruntime) |
| `healthcheck` → `/health/readiness` | `readinessProbe` (`/health/readiness`) + `livenessProbe` (`/health/liveness`) | Validation result: readiness goes 503 when UM is down, liveness stays 200 — exactly the probe split K8s needs |
| `start_period: 60s` | `startupProbe` | MSR first start ≈ 30–75 s in the workshop |
| `stop_grace_period: 90s` + `SAG_IS_SHUTDOWN_WAIT_TIME` | `terminationGracePeriodSeconds: 90` | Default 30 s in K8s — still too short for safety |
| `application.properties` bind mount | `ConfigMap` mounted at `/opt/webmethods/IntegrationServer/application.properties` | Same file, same `$env{}` syntax |
| Compose `secrets` + `secrets-entrypoint.sh` | `Secret` → `env.valueFrom.secretKeyRef` | No wrapper needed: K8s injects env vars from Secrets natively |
| `deploy.resources.limits` | `resources.requests/limits` | Keep `JAVA_MAX_MEM` ≈ 65–75 % of the memory limit |
| `nginx` load balancer + manual drain | `Service` (ClusterIP) + `Ingress` | Endpoints are drained automatically by readiness |
| `scripts/rolling-update.sh` | `Deployment.strategy: RollingUpdate` (`maxUnavailable: 0`, `maxSurge: 1`) | Fully automated |
| `um` (stateful, own volume) | `StatefulSet` + `PersistentVolumeClaim` | UM Helm chart in the same IBM repository |
| `postgres` | Managed DB or `StatefulSet` + PVC | Prefer the existing Swisscom DB service |
| `apigateway` + `apigw-store` | API Gateway Helm chart + OpenSearch (operator or managed) | |
| named volumes | `PersistentVolumeClaim` | |
| `compose.prod.yaml` overlay | Helm `values-prod.yaml` / Kustomize overlay | Same base-plus-overlay idea |
| Fluent Bit sidecar | Fluent Bit `DaemonSet` reading container stdout | Set `LOG_FORMAT=json` on MSR for structured logs |
| `check_msr.sh` (Nagios/OP5) | Prometheus scraping `/metrics` + alert rules (or keep OP5 polling the Ingress) | |
