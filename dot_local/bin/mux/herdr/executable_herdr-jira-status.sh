#!/usr/bin/env bash
# herdr-jira-status — supervises `claude -p /sb-agent-refresh` for the $jira token; MCP exists only inside a Claude session, so a daemon cannot fetch it directly.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

INTERVAL="${HERDR_JIRA_INTERVAL:-1800}"
LOG="$HOME/.logs/herdr-jira-status/ticks.log"
mkdir -p "$(dirname "$LOG")"

# Preserving last-known on failure means a dead token and a healthy one render the same badge, so this log is the only place a silent failure shows.
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"; }

# Pin the work account: a daemon has no meaningful cwd for claude-account to infer from.
acct_dir="$(CLAUDE_ACCOUNT="${HERDR_JIRA_ACCOUNT:-work}" "$HOME/.local/bin/claude-account" dir 2>/dev/null || true)"
[ -n "$acct_dir" ] && export CLAUDE_CONFIG_DIR="$acct_dir"

refresh_once() {
  command -v claude >/dev/null 2>&1 || { log "SKIP claude not on PATH"; return 0; }
  local out; out=$(mktemp)
  # A tick that outlives its interval would stack; cap it well under INTERVAL and let the next one retry.
  "$HOME/.local/bin/claude" -p /sb-agent-refresh >"$out" 2>&1 &
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
