#!/usr/bin/env bash
# Smart-switch binding for rctrl - '.
# Reads the latest session that emitted an idle banner (tracked by
# notify-idle.sh in /tmp/notify-idle.latest), switches to it, then clears all
# displayed banners. Every jump goes through a `mux` verb, never herdr/tmux directly.

set -uo pipefail
. "$HOME/.local/bin/mux/shared/mux-env.sh"

MUX="${MUX:-$HOME/.local/bin/mux/mux}"
STATE_FILE="/tmp/notify-idle.latest"
ENTRY=$(cat "$STATE_FILE" 2>/dev/null)

# No-op when there's no recent notification to act on. Prevents repeated
# presses from blowing away active notifications when there's nothing to
# switch to — wait for a real banner first.
[ -z "$ENTRY" ] && exit 0

# State file format:
#   "<session_name>"           — bare session name (claude-idle banners)
#   "<session_name>|<path>"    — session may not exist yet, create at path
#                                (worktree runner success banners)
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
  # GNU stat first: on Linux `stat -f` reads its arg as a filesystem and poisons the list.
  RECENT_NOTES=$(find "$VAULT_INBOX" -maxdepth 1 -name '*Worktree-*.md' -mmin -60 -type f 2>/dev/null \
    | xargs -I{} sh -c 'stat -c "%Y %n" "$1" 2>/dev/null || stat -f "%m %N" "$1" 2>/dev/null' _ {} \
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
      # GNU stat first: `stat -f` is filesystem mode on Linux and poisons the value.
      epoch=$(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null)
      # `date -r <epoch>` is BSD; GNU reads -r as a filename and falls through cleanly.
      mtime=$(date -r "$epoch" '+%H:%M' 2>/dev/null || date -d "@$epoch" '+%H:%M' 2>/dev/null)
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

    # Staged as a script so mux popup can draw it or exec it inline under herdr.
    PICK_SH=$(mktemp -t notify-idle-picker.XXXXXX.sh)
    chmod +x "$PICK_SH"
    cat > "$PICK_SH" <<EOF
#!/usr/bin/env bash
fzf --reverse --delimiter=\$'\t' --with-nth=1 --prompt='capture > ' < '$PICK_LIST' > '$PICK_OUT'
EOF
    "$MUX" popup --width 80% --height 40% "$PICK_SH" 2>/dev/null || true
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

  # Focus the vault session, creating if absent; note opens in a FRESH window.
  # printf %q on NOTE_PATH: a filename with a quote would otherwise inject a command.
  "$MUX" session --label "$VAULT_SESSION" "$VAULT_DIR" >/dev/null 2>&1 || true
  if [ -n "$NOTE_PATH" ] && [ -f "$NOTE_PATH" ]; then
    "$MUX" window "📝" "$VAULT_DIR" "nvim $(printf %q "$NOTE_PATH")" >/dev/null 2>&1 || true
  fi
  ;;
*)
  RAW="${ENTRY%%|*}"
  WORKTREE_PATH=""
  case "$ENTRY" in *\|*) WORKTREE_PATH="${ENTRY#*|}" ;; esac

  # RAW is a pane id (herdr wA:pN / tmux %N) or a bare session; only the latter has a label.
  SESSION_LABEL=""
  case "$RAW" in
    "" | *:p* | %*) ;;
    *) SESSION_LABEL="$RAW" ;;
  esac

  # Only pane-id shapes are worth a focus attempt; a session name just costs a fork.
  if [ -n "$RAW" ] && [ -z "$SESSION_LABEL" ] && "$MUX" focus "$RAW" 2>/dev/null; then
    :
  elif [ -n "$WORKTREE_PATH" ]; then
    # Deferred creation: the worktree wrapper skips pre-creating the session.
    if [ -n "$SESSION_LABEL" ]; then
      "$MUX" session --label "$SESSION_LABEL" "$WORKTREE_PATH" >/dev/null 2>&1 || true
    else
      "$MUX" session "$WORKTREE_PATH" >/dev/null 2>&1 || true
    fi
  elif [ -n "$SESSION_LABEL" ]; then
    "$MUX" session --label "$SESSION_LABEL" >/dev/null 2>&1 || true
  fi
  ;;
esac
rm -f "$STATE_FILE"

# Clear banners + lingering alerter processes
pkill alerter 2>/dev/null
killall NotificationCenter usernotificationsd 2>/dev/null
exit 0
