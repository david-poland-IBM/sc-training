#!/usr/bin/env bash
# =====================================================================
# Capstone 6 - STRETCH GOAL: Monitoring with Nagios / OP5 (reference solution)
# Runs scripts/check_msr.sh inside each MSR node, the way an OP5 agent on the
# node would, and provokes every state the plugin can return:
#   OK (0)        default thresholds (heap 80 / 90 %)
#   WARNING (1)   -w 5          heap above 5 %
#   CRITICAL (2)  -w 1 -c 5     heap above 5 %
#   CRITICAL (2)  -u http://localhost:5599    nothing listens -> not reachable
#
#   ./check-nodes.sh                               # stack in ../../../block5/capstone
#   STACK_DIR=../../../block5/solution ./check-nodes.sh
#   DC="podman-compose" ./check-nodes.sh           # base stack without the prod overlay
# =====================================================================
set -uo pipefail          # no -e: non-zero exit codes are the point here
cd "$(dirname "$0")"
STACK_DIR="${STACK_DIR:-../../../block5/capstone}"
cd "$STACK_DIR"
read -ra DC <<< "${DC:-podman-compose -f compose.yaml -f compose.prod.yaml}"

check() {   # check <node> [plugin args...]
  local node=$1; shift
  printf '%-6s %-28s ' "$node" "${*:-(defaults)}"
  "${DC[@]}" exec -T "$node" bash -s -- -u http://localhost:5555 "$@" < scripts/check_msr.sh
  echo "  -> exit=$?"
}

for node in msr-1 msr-2; do
  check "$node"
  check "$node" -w 5
  check "$node" -w 1 -c 5
  printf '%-6s %-28s ' "$node" "-u http://localhost:5599"
  "${DC[@]}" exec -T "$node" bash -s -- -u http://localhost:5599 < scripts/check_msr.sh
  echo "  -> exit=$?"
  echo
done
echo "Everything after '|' is perfdata: OP5 graphs heap_pct and threads with the w/c thresholds."
