#!/usr/bin/env bash
# Supervises `claude -p` for the second-brain work log - a log queue (post-commit hook) and a finish queue (herdr-thread-status on PR merge). A daemon, not a direct hook call, because a blocking post-commit is unusable and batching reads as one story.
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

INTERVAL="${HERDR_SB_DRAIN_INTERVAL:-600}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_Q="$STATE/sb-queue/log"
WORK_D="$LOG_Q/.work"
ATT_D="$LOG_Q/.attempts"
FAIL_D="$LOG_Q/.failed"
FINISH_Q="$STATE/sb-ticket-finish-pending"
LOG="$HOME/.logs/herdr-sb-drain/ticks.log"
MAX_TRIES=3
CAP=300

# Absolute path: PATH hits mise's raw npm binary first, which has no auth and dies.
CLAUDE="$HOME/.local/bin/claude"
VAULT_PATH="$HOME/.local/bin/vault-path"
VAULT_NOTE="$HOME/.local/bin/vault-note"
ACCOUNT="$HOME/.local/bin/claude-account"

mkdir -p "$(dirname "$LOG")" "$LOG_Q" "$WORK_D" "$ATT_D" "$FAIL_D" "$FINISH_Q"
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"; }

# A tick that outlives its interval would stack; cap it and let the next one retry.
run_capped() {
  local cap="$1"; shift
  "$@" >/dev/null 2>&1 &
  local pid=$! waited=0 rc=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$cap" ]; do sleep 5; waited=$((waited + 5)); done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; return 124; fi
  wait "$pid" 2>/dev/null || rc=$?
  return "$rc"
}

# Append rather than move: commits may have queued while this batch was claimed.
requeue() { cat "$1" >> "$2" 2>/dev/null; rm -f "$1"; }

drain_log() {
  local f ticket work root shas n vault acct tries
  for f in "$LOG_Q"/*.tsv; do
    [ -e "$f" ] || continue
    ticket=$(basename "$f" .tsv)
    work="$WORK_D/$ticket.tsv"
    # Atomic claim, so commits landing mid-run open a fresh queue file instead of racing this batch.
    mv "$f" "$work" 2>/dev/null || continue

    root=$(awk -F'\t' 'NF>1 { print $2; exit }' "$work" 2>/dev/null)
    shas=$(awk -F'\t' 'NF { print $1 }' "$work" 2>/dev/null | tr '\n' ' ')
    n=$(awk 'NF' "$work" 2>/dev/null | wc -l | tr -d ' ')

    if [ -z "$shas" ] || [ -z "$root" ] || [ ! -d "$root" ]; then
      log "DROP log $ticket — worktree gone or queue empty"
      rm -f "$work"
      continue
    fi

    vault=$("$VAULT_PATH" "$root" 2>/dev/null || true)
    if [ ! -d "$vault" ]; then
      log "DEFER log $ticket — vault not mounted"
      requeue "$work" "$f"
      continue
    fi
    acct=$("$ACCOUNT" cwd "$root" 2>/dev/null || true)

    # --add-dir: claude's sandbox is the cwd, which excludes the vault, so the skill would halt at pre-check.
    if ( cd "$root" && run_capped "$CAP" env CLAUDE_ACCOUNT="$acct" \
        "$CLAUDE" -p "/sb-ticket-log --from-commits $shas" \
          --permission-mode bypassPermissions \
          --add-dir "$vault" ); then
      log "OK log $ticket ($n commits)"
      rm -f "$work" "$ATT_D/$ticket"
    else
      tries=$(( $(cat "$ATT_D/$ticket" 2>/dev/null || echo 0) + 1 ))
      printf '%s\n' "$tries" > "$ATT_D/$ticket"
      if [ "$tries" -ge "$MAX_TRIES" ]; then
        # Park rather than drop: a batch that never composes is still a record of what was committed.
        mv "$work" "$FAIL_D/$ticket.$(date +%s).tsv" 2>/dev/null
        rm -f "$ATT_D/$ticket"
        log "FAIL log $ticket after $tries tries — parked in .failed/"
      else
        requeue "$work" "$f"
        log "RETRY log $ticket (try $tries)"
      fi
    fi
  done
}

drain_finish() {
  local f ticket wt ref pr vault acct note
  for f in "$FINISH_Q"/*.json; do
    [ -e "$f" ] || continue
    ticket=$(basename "$f" .json)
    wt=$(jq -r '.worktree // empty' "$f" 2>/dev/null || true)
    pr=$(jq -r '.pr_url // empty' "$f" 2>/dev/null || true)
    ref="$wt"
    [ -n "$ref" ] && [ -d "$ref" ] || ref="$HOME"

    # Same cheap idempotency check tkrm makes: tkrm's pre-delete hook fires for these tickets too.
    note=$("$VAULT_NOTE" --ticket "$ticket" "$ref" 2>/dev/null) || note=""
    if [ -n "$note" ] && grep -q '^state: frozen' "$note" 2>/dev/null; then
      log "SKIP finish $ticket — already frozen"
      rm -f "$f"
      continue
    fi

    vault=$("$VAULT_PATH" "$ref" 2>/dev/null || true)
    if [ ! -d "$vault" ]; then
      log "DEFER finish $ticket — vault not mounted"
      continue
    fi
    acct=$("$ACCOUNT" cwd "$ref" 2>/dev/null || true)

    if run_capped "$CAP" env SB_TICKET_FINISH_FROM_TKRM=1 CLAUDE_ACCOUNT="$acct" \
        "$CLAUDE" -p "/sb-ticket-finish $ticket $pr" \
          --permission-mode bypassPermissions \
          --add-dir "$vault" \
          --add-dir "$STATE"; then
      log "OK finish $ticket"
      rm -f "$f"
    else
      # Keep the job: a failed freeze must stay retryable, same rationale as tkrm keeping thread state.
      log "RETRY finish $ticket"
    fi
  done
}

drain_once() {
  command -v "$CLAUDE" >/dev/null 2>&1 || [ -x "$CLAUDE" ] || { log "SKIP claude not executable"; return 0; }
  drain_log
  drain_finish
  return 0
}

case "${1:-}" in
  --once) drain_once ;;
  *) while :; do drain_once; sleep "$INTERVAL"; done ;;
esac
