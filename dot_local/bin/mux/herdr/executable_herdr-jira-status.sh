#!/usr/bin/env bash
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

INTERVAL="${HERDR_JIRA_INTERVAL:-1800}"
OPENCODE_RUNNER="$HOME/.local/bin/opencode-headless"
LOG="$HOME/.logs/herdr-jira-status/ticks.log"
mkdir -p "$(dirname "$LOG")"

# Preserving last-known on failure means a dead token and a healthy one render the same badge, so this log is the only place a silent failure shows.
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"; }

refresh_once() {
  [ -f "$OPENCODE_RUNNER" ] || { log "SKIP opencode-headless is unavailable"; return 0; }
  local out; out=$(mktemp)
  # A tick that outlives its interval would stack; cap it well under INTERVAL and let the next one retry.
  bash "$OPENCODE_RUNNER" --dir "$HOME" --command sb-agent-refresh >"$out" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 300 ]; do sleep 5; waited=$((waited + 5)); done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    log "TIMEOUT killed after ${waited}s"
  else
    wait "$pid" 2>/dev/null; local rc=$?
    log "rc=$rc $(tr '\n' ' ' <"$out" | tail -c 300)"
  fi
  rm -f "$out"
  return 0
}

case "${1:-}" in
  --once) refresh_once ;;
  *) while :; do refresh_once; sleep "$INTERVAL"; done ;;
esac
