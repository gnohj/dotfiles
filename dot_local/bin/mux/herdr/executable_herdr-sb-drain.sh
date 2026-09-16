#!/usr/bin/env bash
set -uo pipefail

. "$HOME/.local/bin/mux/shared/mux-env.sh"

INTERVAL="${HERDR_SB_DRAIN_INTERVAL:-600}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_Q="$STATE/sb-queue/log"
WORK_D="$LOG_Q/.work"
ATT_D="$LOG_Q/.attempts"
FAIL_D="$LOG_Q/.failed"
FINISH_Q="$STATE/sb-ticket-finish-pending"
CAPTURE_Q="$STATE/sb-ticket-capture-pending"
LOG="$HOME/.logs/herdr-sb-drain/ticks.log"
MAX_TRIES=3
CAP=300

OPENCODE_RUNNER="$HOME/.local/bin/opencode-headless"
VAULT_PATH="$HOME/.local/bin/vault-path"
VAULT_NOTE="$HOME/.local/bin/vault-note"

mkdir -p "$(dirname "$LOG")" "$LOG_Q" "$WORK_D" "$ATT_D" "$FAIL_D" "$FINISH_Q" "$CAPTURE_Q"
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
  local f ticket work root shas n vault tries
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
    if ( cd "$root" && run_capped "$CAP" \
        bash "$OPENCODE_RUNNER" --dir "$root" --command sb-ticket-log -- "--from-commits $shas" ); then
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
  local f ticket wt ref pr vault note
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
    if run_capped "$CAP" env SB_TICKET_FINISH_FROM_TKRM=1 \
        bash "$OPENCODE_RUNNER" --dir "$ref" --command sb-ticket-finish -- "$ticket $pr"; then
      log "OK finish $ticket"
      rm -f "$f"
    else
      # Keep the job: a failed freeze must stay retryable, same rationale as tkrm keeping thread state.
      log "RETRY finish $ticket"
    fi
  done
}

drain_capture() {
  local f ticket wt ref vault workv note
  for f in "$CAPTURE_Q"/*.json; do
    [ -e "$f" ] || continue
    ticket=$(basename "$f" .json)
    wt=$(jq -r '.worktree // empty' "$f" 2>/dev/null || true)

    # No fallback ref, unlike finish: capture distills the code, so a gone worktree has nothing left to read.
    if [ -z "$wt" ] || [ ! -d "$wt" ]; then
      log "DROP capture $ticket — worktree gone"
      rm -f "$f"
      continue
    fi
    ref="$wt"

    # Same cheap idempotency check finish makes: a note on disk means capture already ran.
    note=$("$VAULT_NOTE" --ticket "$ticket" "$ref" 2>/dev/null) || note=""
    if [ -n "$note" ]; then
      log "SKIP capture $ticket — note already exists"
      rm -f "$f"
      continue
    fi

    vault=$("$VAULT_PATH" "$ref" 2>/dev/null || true)
    workv=$("$VAULT_PATH" --work 2>/dev/null || true)
    if [ ! -d "$vault" ] || [ ! -d "$workv" ]; then
      log "DEFER capture $ticket — vault not mounted"
      continue
    fi
    # Automatic vault writes are authorised for work only; vault-path owns that decision and ambiguous scopes are declined.
    if [ "$vault" != "$workv" ]; then
      log "DROP capture $ticket — $ref is not a work worktree"
      rm -f "$f"
      continue
    fi
    if ( cd "$ref" && run_capped "$CAP" \
        bash "$OPENCODE_RUNNER" --dir "$ref" --command sb-ticket-capture -- "$ticket --worktree $ref" ); then
      log "OK capture $ticket"
      rm -f "$f"
    else
      # Keep the job: a failed capture must stay retryable, same rationale as finish.
      log "RETRY capture $ticket"
    fi
  done
}

drain_once() {
  [ -f "$OPENCODE_RUNNER" ] || { log "SKIP opencode-headless is unavailable"; return 0; }
  drain_capture
  drain_log
  drain_finish
  return 0
}

case "${1:-}" in
  --once) drain_once ;;
  *) while :; do drain_once; sleep "$INTERVAL"; done ;;
esac
