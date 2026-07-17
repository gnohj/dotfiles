#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

PANE_ID="${1:-}"

# Git-context glyph for the current pane's directory:
#   🌳 linked git worktree · 🌿 normal git checkout · (blank) not a git repo.
# The rbw vault-lock indicator that used to live here moved to sketchybar — it's
# global state, so redrawing it in every session's status line was duplication.
GITCTX=""
GIT_INFO=""

if [ -n "$PANE_ID" ]; then
  DIR=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}')

  if [ -d "$DIR" ]; then
    # One rev-parse resolves all three states: empty output → not a git repo
    # (GITCTX stays blank); git-dir == git-common-dir → main checkout (🌿);
    # they differ → linked worktree (🌳). --path-format=absolute makes the
    # comparison robust (both sides absolute, never relative-vs-absolute).
    mapfile -t GITDIRS < <(git -C "$DIR" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null)
    if [ -n "${GITDIRS[0]:-}" ]; then
      if [ "${GITDIRS[0]}" != "${GITDIRS[1]:-}" ]; then
        GITCTX="🌳"
      else
        GITCTX="🌿"
      fi
    fi

    # Publish the glyph as a pane option so status-format renders it NATIVELY (instant, and positioned BEFORE the session name → order stays 🌿 session git) instead of via this laggy #() job. A pane's git-context is fixed, so it's written once then persists → instant on revisit. Guarded so we only set-option (and trigger a redraw) when it actually changes, not every tick.
    NEWCTX="${GITCTX:+$GITCTX }"
    [ "$(tmux show-option -pqv -t "$PANE_ID" @git_ctx 2>/dev/null)" != "$NEWCTX" ] && tmux set-option -p -t "$PANE_ID" @git_ctx "$NEWCTX" 2>/dev/null

    # gitmux is a full git status (slow on big repos), so serve the last cached value instantly and refresh in the background - stale-while-revalidate keeps session/window switches from blocking on it. The refresh (mkdir-lock + gitmux + cache write) lives in status-git-refresh.sh, shared with sesh-session-created.sh which pre-warms the cache on session creation.
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-git"
    KEY="$(cksum <<<"$DIR" | cut -d' ' -f1)"
    CACHE="$CACHE_DIR/$KEY"
    [ -f "$CACHE" ] && GIT_INFO="$(cat "$CACHE")"
    "$HOME/.config/tmux/status-git-refresh.sh" "$DIR" >/dev/null 2>&1 &
  fi
fi

# Emits ONLY the (cached) gitmux status. The git-context glyph (@git_ctx, set above), session name (#S), and window list (#{W:...}) are all rendered NATIVELY in generate-tmux-colors.sh, so they repaint instantly instead of lagging behind this #() job.
echo "#[fg=${gnohj_color14},nobold]${GIT_INFO}"
