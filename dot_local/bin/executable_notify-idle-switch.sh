#!/usr/bin/env bash
# Smart-switch binding for rctrl - '.
# Reads the latest session that emitted an idle banner (tracked by
# notify-idle.sh in /tmp/notify-idle.latest), switches to it, then clears all
# displayed banners. Pane-id shape picks the mux: "%N" tmux, "wA:pN" herdr.

set -uo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/bin:/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

STATE_FILE="/tmp/notify-idle.latest"
ENTRY=$(cat "$STATE_FILE" 2>/dev/null)

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# True when $1 looks like a herdr pane id ("wA:p2E") rather than a tmux one ("%3").
is_herdr_pane() {
  case "$1" in *:p*) return 0 ;; *) return 1 ;; esac
}

# Focus a herdr pane by id; non-zero lets the caller fall to workspace-by-name.
herdr_jump() {
  "$HOME/.local/bin/herdr-scripts/herdr-focus-pane.sh" "$1" >/dev/null 2>&1
}

# Focus the herdr workspace labelled $1, comparing on the emoji-stripped tail.
herdr_focus_workspace_named() {
  local want="$1" ws
  command -v jq >/dev/null 2>&1 || return 1
  ws=$("$herdr_bin" workspace list 2>/dev/null |
    jq -r --arg w "$want" '.result.workspaces[]?
      | select(((.label // "") | sub("^[^[:alnum:]]*";"")) == $w)
      | .workspace_id' 2>/dev/null | head -1)
  [ -n "$ws" ] || return 1
  "$herdr_bin" workspace focus "$ws" >/dev/null 2>&1
}

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
  # Worktree captures are work-context (treekanga worktrees = work tickets), so
  # they land in the work vault + its session. Resolved via vault-path (no hardcode).
  VAULT_DIR="$("$HOME/.local/bin/vault-path" --work)"
  VAULT_INBOX="$VAULT_DIR/Notes-Inbox"
  VAULT_SESSION="$(basename "$VAULT_DIR")"

  # If multiple worktree captures landed in the inbox in the last hour,
  # offer an fzf picker so the user can choose which one to open. The
  # state file always points at the LATEST, but a stack of failures
  # would otherwise hide the earlier ones from `rctrl + '`. Single-slot
  # state is preserved — picker only opens when COUNT > 1.
  RECENT_NOTES=$(find "$VAULT_INBOX" -maxdepth 1 -name '*Worktree-*.md' -mmin -60 -type f 2>/dev/null \
    | xargs -I{} sh -c 'stat -f "%m %N" "$1" 2>/dev/null || stat -c "%Y %n" "$1" 2>/dev/null' _ {} \
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
      mtime=$(stat -f '%Sm' -t '%H:%M' "$path" 2>/dev/null || date -d "@$(stat -c %Y "$path" 2>/dev/null)" '+%H:%M' 2>/dev/null)
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

    # Staged as a script so mux-popup.sh can draw it or exec it inline under herdr.
    PICK_SH=$(mktemp -t notify-idle-picker.XXXXXX.sh)
    chmod +x "$PICK_SH"
    cat > "$PICK_SH" <<EOF
#!/usr/bin/env bash
fzf --reverse --delimiter=\$'\t' --with-nth=1 --prompt='capture > ' < '$PICK_LIST' > '$PICK_OUT'
EOF
    "$HOME/.local/bin/mux-popup.sh" --width 80% --height 40% "$PICK_SH" 2>/dev/null || true
    rm -f "$PICK_SH"

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

  # Focus the vault session, creating if absent; note opens in a FRESH tab.
  # printf %q on NOTE_PATH: a filename with a quote would otherwise inject a command.
  if [ "$("$HOME/.local/bin/mux-kind.sh")" = herdr ]; then
    # herdr-sesh-layout.sh is the herdr counterpart of `sesh connect`.
    herdr_focus_workspace_named "$VAULT_SESSION" ||
      "$HOME/.local/bin/herdr-scripts/herdr-sesh-layout.sh" "$VAULT_DIR" >/dev/null 2>&1 || true
    if [ -n "$NOTE_PATH" ] && [ -f "$NOTE_PATH" ]; then
      "$HOME/.local/bin/mux-window.sh" "📝" "$VAULT_DIR" "nvim $(printf %q "$NOTE_PATH")" >/dev/null 2>&1 || true
    fi
  else
    if tmux has-session -t "$VAULT_SESSION" 2>/dev/null; then
      if [ -n "$NOTE_PATH" ] && [ -f "$NOTE_PATH" ]; then
        tmux new-window -t "$VAULT_SESSION" -c "$VAULT_DIR" "nvim $(printf %q "$NOTE_PATH")" 2>/dev/null || true
      fi
    else
      if [ -n "$NOTE_PATH" ] && [ -f "$NOTE_PATH" ]; then
        tmux new-session -d -s "$VAULT_SESSION" -c "$VAULT_DIR" "nvim $(printf %q "$NOTE_PATH")" 2>/dev/null || true
      else
        tmux new-session -d -s "$VAULT_SESSION" -c "$VAULT_DIR" 2>/dev/null || true
      fi
    fi
    tmux switch-client -t "$VAULT_SESSION" 2>/dev/null \
      || tmux attach-session -t "$VAULT_SESSION" 2>/dev/null \
      || true
  fi
  ;;
*)
  RAW="${ENTRY%%|*}"
  WORKTREE_PATH=""
  case "$ENTRY" in *\|*) WORKTREE_PATH="${ENTRY#*|}" ;; esac

  # RAW is one of:
  #   wA:pN       — a herdr pane id; `agent focus` reaches it wherever it lives.
  #   %N          — a STABLE tmux pane id (notify-idle.sh records this). It
  #                 survives pane/window renumbering, so it always points at the
  #                 agent that fired — even minutes later, even with multiple
  #                 agents in the session. Resolve its live session for the switch.
  #   <session>   — a bare session (worktree deferred-create banner, or older
  #                 state). We ask tmux-dash for its agent pane at press time
  #                 (fresh, so no drift).
  # PANE = the pane to focus (id or index target); SESSION = its session.
  # HANDLED skips the tmux block without exiting; the tail still clears banners.
  HANDLED=""
  if is_herdr_pane "$RAW"; then
    if herdr_jump "$RAW"; then
      HANDLED=1
    else
      # Pane gone (workspace closed) — let the path branch below rebuild it.
      RAW=""
    fi
  fi

  if [ -z "$HANDLED" ] && [ -n "$WORKTREE_PATH" ] &&
    [ "$("$HOME/.local/bin/mux-kind.sh")" = herdr ]; then
    # Deferred creation, herdr side: attach to the workspace at this path or build it.
    "$HOME/.local/bin/herdr-scripts/herdr-sesh-layout.sh" "$WORKTREE_PATH" >/dev/null 2>&1 || true
    HANDLED=1
  fi

  case "$RAW" in
    "") PANE="";     SESSION="" ;;
    %*) PANE="$RAW"; SESSION=$(tmux display-message -t "$RAW" -p '#{session_name}' 2>/dev/null) ;;
    *)  PANE="";     SESSION="$RAW" ;;
  esac
  [ -n "$HANDLED" ] && { PANE=""; SESSION=""; WORKTREE_PATH=""; }

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
