#!/usr/bin/env bash
# herdr-jira-status — supervises `claude -p /sb-agent-refresh` for the $jira token; MCP exists only inside a Claude session, so a daemon cannot fetch it directly.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

INTERVAL="${HERDR_JIRA_INTERVAL:-1800}"

# Pin the work account: a daemon has no meaningful cwd for claude-account to infer from.
acct_dir="$(CLAUDE_ACCOUNT="${HERDR_JIRA_ACCOUNT:-work}" "$HOME/.local/bin/claude-account" dir 2>/dev/null || true)"
[ -n "$acct_dir" ] && export CLAUDE_CONFIG_DIR="$acct_dir"

refresh_once() {
  command -v claude >/dev/null 2>&1 || return 0
  # A tick that outlives its interval would stack; cap it well under INTERVAL and let the next one retry.
  "$HOME/.local/bin/claude" -p /sb-agent-refresh >/dev/null 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 300 ]; do sleep 5; waited=$((waited + 5)); done
  kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  return 0
}

case "${1:-}" in
  --once) refresh_once ;;
  *) while :; do refresh_once; sleep "$INTERVAL"; done ;;
esac
