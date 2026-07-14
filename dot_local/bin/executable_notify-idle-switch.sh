#!/usr/bin/env bash
# Smart-switch binding for rctrl - '.
# Reads the latest tmux session that emitted an idle banner (tracked by
# notify-idle.sh in /tmp/notify-idle.latest), switches the tmux client to
# that session, then clears all displayed banners.

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

STATE_FILE="/tmp/notify-idle.latest"
ENTRY=$(cat "$STATE_FILE" 2>/dev/null)

# No-op when there's no recent notification to act on. Prevents repeated
# presses from blowing away active notifications when there's nothing to
# switch to — wait for a real banner first.
[ -z "$ENTRY" ] && exit 0

# State file format:
#   "<session_name>"           — bare session name (claude-idle banners)
#   "<session_name>|<path>"    — session may not exist yet, create at path
#                                (worktree-runner success banners)
#   "vault|<note-path>"        — most recent worktree attempt failed or
#                                was deliberately skipped (NOT_BUG); the
#                                runner captured it to the second-brain
#                                inbox and points us at the note. Open
#                                the vault tmux session and the note in
#                                a fresh nvim window so the user can
#                                review the decision in context.

case "$ENTRY" in
vault\|*)
  STATE_NOTE="${ENTRY#vault|}"
  VAULT_DIR="$HOME/Obsidian/second-brain"
  VAULT_INBOX="$VAULT_DIR/Notes-Inbox"
  VAULT_SESSION="second-brain"

  # If multiple worktree captures landed in the inbox in the last hour,
  # offer an fzf picker so the user can choose which one to open. The
  # state file always points at the LATEST, but a stack of failures
  # would otherwise hide the earlier ones from `rctrl + '`. Single-slot
  # state is preserved — picker only opens when COUNT > 1.
  RECENT_NOTES=$(find "$VAULT_INBOX" -maxdepth 1 -name '*Worktree-*.md' -mmin -60 -type f 2>/dev/null \
    | xargs -I{} stat -f '%m %N' {} 2>/dev/null \
    | sort -rn \
    | awk '{$1=""; sub(/^ /, ""); print}')

  # Make sure the state's note is in the candidate list (in case it's
  # somehow older than the 1h window — e.g. the user re-set the state
  # manually). Prepend if missing.
  if [ -n "$STATE_NOTE" ] && [ -f "$STATE_NOTE" ] && ! printf '%s\n' "$RECENT_NOTES" | grep -qFx "$STATE_NOTE"; then
    RECENT_NOTES=$(printf '%s\n%s' "$STATE_NOTE" "$RECENT_NOTES")
  fi

  COUNT=$(printf '%s' "$RECENT_NOTES" | grep -c '^.' || true)
  COUNT=${COUNT:-0}

  if [ "$COUNT" -le 1 ]; then
    NOTE_PATH="$STATE_NOTE"
  else
    # Pretty-format each path for the picker:
    #   "HH:MM │ <outcome> │ <entry-point> │ <slug>\t<full-path>"
    # fzf displays only field 1 (the formatted text); we extract field 2
    # (the path) from the selected line.
    PICK_LIST=$(mktemp -t notify-idle-picker.XXXXXX)
    PICK_OUT=$(mktemp -t notify-idle-picker-out.XXXXXX)
    trap 'rm -f "$PICK_LIST" "$PICK_OUT"' EXIT
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      base=$(basename "$path" .md)
      # base format: YYYY-MM-DD_Worktree-<entry-point>-<outcome>-<slug>
      mtime=$(stat -f '%Sm' -t '%H:%M' "$path" 2>/dev/null)
      stripped=${base#*_Worktree-}
      # Entry-point matches the WORKTREE_LOG_TAG family: "worktree-<X>"
      entry=$(printf '%s' "$stripped" | sed -E 's|^(worktree-[a-z]+)-.*|\1|')
      rest=${stripped#${entry}-}
      # Outcome is the first hyphenated chunk: success | not-a-bug | failed
      case "$rest" in
        not-a-bug-*) outcome="not-a-bug"; slug="${rest#not-a-bug-}" ;;
        success-*)   outcome="success";   slug="${rest#success-}"   ;;
        failed-*)    outcome="failed";    slug="${rest#failed-}"    ;;
        *)           outcome="?";         slug="$rest"              ;;
      esac
      printf '%s │ %-9s │ %-18s │ %s\t%s\n' "$mtime" "$outcome" "$entry" "$slug" "$path"
    done <<< "$RECENT_NOTES" > "$PICK_LIST"

    tmux display-popup -E -w 80% -h 40% \
      "fzf --reverse --delimiter=$'\t' --with-nth=1 --prompt='capture > ' < '$PICK_LIST' > '$PICK_OUT'" \
      2>/dev/null || true

    PICK=$(cat "$PICK_OUT" 2>/dev/null || true)
    NOTE_PATH=$(printf '%s' "$PICK" | awk -F'\t' '{print $2}')
    rm -f "$PICK_LIST" "$PICK_OUT"
    trap - EXIT

    # User cancelled the picker (Ctrl-C or Esc) — leave state file alone
    # so a follow-up press behaves the same.
    if [ -z "$NOTE_PATH" ]; then
      exit 0
    fi
  fi

  # Create the vault session detached if it doesn't exist (rooted at the
  # vault dir). If it already exists, opening the note in a fresh window
  # avoids stomping whatever the user has up in the existing pane.
  if tmux has-session -t "$VAULT_SESSION" 2>/dev/null; then
    if [ -n "$NOTE_PATH" ] && [ -f "$NOTE_PATH" ]; then
      tmux new-window -t "$VAULT_SESSION" -c "$VAULT_DIR" "nvim '$NOTE_PATH'" 2>/dev/null || true
    fi
  else
    if [ -n "$NOTE_PATH" ] && [ -f "$NOTE_PATH" ]; then
      tmux new-session -d -s "$VAULT_SESSION" -c "$VAULT_DIR" "nvim '$NOTE_PATH'" 2>/dev/null || true
    else
      tmux new-session -d -s "$VAULT_SESSION" -c "$VAULT_DIR" 2>/dev/null || true
    fi
  fi
  tmux switch-client -t "$VAULT_SESSION" 2>/dev/null \
    || tmux attach-session -t "$VAULT_SESSION" 2>/dev/null \
    || true
  ;;
*)
  RAW="${ENTRY%%|*}"
  WORKTREE_PATH=""
  case "$ENTRY" in *\|*) WORKTREE_PATH="${ENTRY#*|}" ;; esac

  # RAW is one of:
  #   %N          — a STABLE pane id (notify-idle.sh records this). It survives
  #                 pane/window renumbering, so it always points at the agent that
  #                 fired — even minutes later, even with multiple agents in the
  #                 session. Resolve its live session name for the switch.
  #   <session>   — a bare session (worktree deferred-create banner, or older
  #                 state). We ask tmux-dash for its agent pane at press time
  #                 (fresh, so no drift).
  # PANE = the pane to focus (id or index target); SESSION = its session.
  case "$RAW" in
    %*) PANE="$RAW"; SESSION=$(tmux display-message -t "$RAW" -p '#{session_name}' 2>/dev/null) ;;
    *)  PANE="";     SESSION="$RAW" ;;
  esac

  # If a path was provided and the session doesn't exist yet, create it
  # detached at that path. This is the "deferred creation" the worktree
  # wrapper relies on — it skips pre-creation to avoid a session-created
  # hook fire on the user's tmux while they're not switching.
  if [ -n "$WORKTREE_PATH" ] && ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -d -s "$SESSION" -c "$WORKTREE_PATH" 2>/dev/null || true
  fi

  # Bare session → resolve its agent pane now, fresh from tmux-dash (no drift).
  if [ -z "$PANE" ] && [ -n "$SESSION" ]; then
    PANE=$("$HOME/.local/bin/tmux-dash" json 2>/dev/null \
      | jq -r --arg s "$SESSION" 'first(.sessions[] | select(.tmux_session == $s) | .pane_target) // empty' 2>/dev/null)
  fi

  # Focus the EXACT agent pane before switching. select-window sets the current
  # window (both a %pane-id and a session:window.pane target resolve to their
  # window); select-pane focuses the pane in it — select-pane alone won't change
  # the current window, so both are needed.
  if [ -n "$PANE" ]; then
    tmux select-window -t "$PANE" 2>/dev/null || true
    tmux select-pane -t "$PANE" 2>/dev/null || true
  fi
  # Switch to the session (skipped only if a stale pane id resolved to nothing).
  if [ -n "$SESSION" ]; then
    tmux switch-client -t "$SESSION" 2>/dev/null \
      || tmux attach-session -t "$SESSION" 2>/dev/null \
      || true
  fi
  ;;
esac
rm -f "$STATE_FILE"

# Clear banners + lingering alerter processes
pkill alerter 2>/dev/null
killall NotificationCenter usernotificationsd 2>/dev/null
exit 0
