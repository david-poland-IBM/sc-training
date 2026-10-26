#!/usr/bin/env bash
# =====================================================================
# Nagios / OP5 compatible check for a Microservices Runtime node.
# Uses only the anonymous MSR endpoints:
#   /health/readiness  -> overall status + failing indicators (JDBC, JMS, UM, memory ...)
#   /metrics           -> Prometheus metrics, used for perfdata
#
# Exit codes follow the Nagios plugin convention:
#   0 OK | 1 WARNING | 2 CRITICAL | 3 UNKNOWN
#
#   ./scripts/check_msr.sh -u http://msr-1:5555
#   ./scripts/check_msr.sh -u http://localhost:5555 -w 80 -c 90     # heap % thresholds
# Workshop: run it inside the compose network, e.g.
#   podman-compose exec -T loadbalancer sh -c 'apk add -q bash curl >/dev/null; bash -s -- -u http://msr-1:5555' < scripts/check_msr.sh
# =====================================================================
URL="http://localhost:5555"; WARN=80; CRIT=90
while getopts "u:w:c:" o; do
  case "$o" in u) URL="$OPTARG" ;; w) WARN="$OPTARG" ;; c) CRIT="$OPTARG" ;; *) echo "UNKNOWN - bad option"; exit 3 ;; esac
done

body=$(curl -s -m 10 -w '\n%{http_code}' "$URL/health/readiness") || { echo "CRITICAL - $URL not reachable"; exit 2; }
code=$(printf '%s' "$body" | tail -n1)
json=$(printf '%s' "$body" | sed '$d')

# Indicators reported as DOWN (top-level keys whose status is DOWN)
down=$(printf '%s' "$json" | tr -d '\n ' | grep -oE '"[A-Za-z0-9_]+":\{[^{}]*"status":"DOWN"' | cut -d'"' -f2 | sort -u | tr '\n' ' ' | sed 's/ $//')

metrics=$(curl -s -m 10 "$URL/metrics")
pick() { printf '%s\n' "$metrics" | grep -E "^$1[{ ]" | head -1 | awk '{print $2}'; }
used=$(pick sag_is_used_memory_bytes); max=$(pick sag_is_max_memory_bytes)
threads=$(pick sag_is_server_threads)
heap_pct=""
if [ -n "$used" ] && [ -n "$max" ]; then heap_pct=$(awk -v u="$used" -v m="$max" 'BEGIN{ if (m>0) printf "%d", u*100/m }'); fi
perf="heap_pct=${heap_pct:-0}%;$WARN;$CRIT threads=${threads:-0}"

if [ "$code" != "200" ]; then
  echo "CRITICAL - readiness HTTP $code, DOWN: ${down:-unknown} | $perf"; exit 2
fi
if [ -n "$heap_pct" ] && [ "$heap_pct" -ge "$CRIT" ]; then echo "CRITICAL - heap ${heap_pct}% | $perf"; exit 2; fi
if [ -n "$heap_pct" ] && [ "$heap_pct" -ge "$WARN" ]; then echo "WARNING - heap ${heap_pct}% | $perf"; exit 1; fi
echo "OK - MSR ready, heap ${heap_pct:-n/a}% | $perf"; exit 0
