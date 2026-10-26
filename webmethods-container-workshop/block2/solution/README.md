# Day 1 — Reference Solution (Capstone 2)

* `capstone2-solution.sh` — every Capstone 2 step as one runnable script (`ENGINE=podman` for Podman)
* `application.properties` — completed TODOs from Part 5

## Model answers for the deliverable note

1. **What `server.log` shows vs. `podman logs`.** In MSR the server log goes to stdout
   *and* to `logs/server.log` (`WM_IS_LOG_DESTINATION=both`), so `podman logs` already
   shows the server log, with lines prefixed `ISSERVER||`. Only the file system has
   the security audit (`WMSECURITY_*.log`), `FailedAudit_*.log`, `stats.csv` and
   `configurationvariables.log`, which lists what `application.properties` changed.
2. **Start-up timings.** First boot to readiness took about 30–45 s, and so did a restart:
   MSR has no instance-creation step, and the work is package loading. `podman stop`
   took ~10.5 s because the default 10 s timeout SIGKILLs MSR before it finishes
   shutting down (clean shutdown ≈ 13 s). That is why Day 3 sets `stop_grace_period`.

## Expected outputs

| Check | Expected |
|---|---|
| `curl http://localhost:5555/health/readiness` | HTTP 200, JSON with `"status" : "UP"` |
| `curl -u Administrator:manage …/invoke/wm.server/ping` | **401** — the default password was replaced |
| `…/invoke/swisscom.lab.health/info` (Part 5) | `"labEnvironment":"capstone2-laptop"` |
| `grep logFilesToKeep config/server.cnf` | `watt.server.audit.logFilesToKeep=7` |

## Linux host note

On Linux, a bind-mounted host folder must be writable by UID 1724:
`podman unshare chown 1724:1724 ./msr-capstone2-logs` (rootless Podman), or
`sudo chown 1724:1724 ./msr-capstone2-logs` (rootful Podman / Docker).
macOS and Windows Desktop file sharing do not need this.
