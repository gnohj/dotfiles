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

SESSION_NAME="$(tmux display-message -p '#S')"
PREFIX_ACTIVE="$(tmux display-message -p '#{client_prefix}')"

if [ "$PREFIX_ACTIVE" = "1" ]; then
  SESSION_COLOR="${gnohj_color21}"
else
  SESSION_COLOR="${gnohj_color04}"
fi

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

    GIT_INFO=$(cd "$DIR" 2>/dev/null && gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh" | perl -pe 's/(#\[[^\]]*\][\s]*)+$//; s/\s+$//')
    [ -n "$GIT_INFO" ] && GIT_INFO="${GIT_INFO}  "
  fi
fi

# Emits only the session + git segment; the window list is rendered natively via `#{W:...}` in generate-tmux-colors.sh (a `#()` job would lag the active-window highlight behind status-interval + gitmux).
SESSION_CELL="#[range=user|sesh]${SESSION_NAME}#[norange] "
if [ -n "$GITCTX" ]; then
  echo "#[fg=${gnohj_color03},nobold]${GITCTX} #[fg=${SESSION_COLOR},nobold]${SESSION_CELL}#[fg=${gnohj_color14},nobold]${GIT_INFO}"
else
  echo "#[fg=${SESSION_COLOR},nobold]${SESSION_CELL}#[fg=${gnohj_color14},nobold]${GIT_INFO}"
fi
