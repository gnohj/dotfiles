#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

PANE_ID="${1:-}"

# Lock icon
LOCK=""
rbw unlocked >/dev/null 2>&1 || LOCK="🔒"

# Session name (check if prefix is pressed)
SESSION_NAME="$(tmux display-message -p '#S')"
PREFIX_ACTIVE="$(tmux display-message -p '#{client_prefix}')"

if [ "$PREFIX_ACTIVE" = "1" ]; then
  SESSION_COLOR="${gnohj_color06}"
else
  SESSION_COLOR="${gnohj_color04}"
fi

# Git info for current pane
if [ -n "$PANE_ID" ]; then
  PANE_NVIM_CWD=$(tmux show-environment -t "$PANE_ID" "NVIM_CWD_$PANE_ID" 2>/dev/null | cut -d= -f2)
  DIR="${PANE_NVIM_CWD:-$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}')}"

  if [ -d "$DIR" ]; then
    # Use -C flag with git instead of cd to avoid issues with special characters in paths
    FULL_REPO_NAME=$(basename "$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    REPO_NAME=$(echo "$FULL_REPO_NAME" | sed 's/[-_].*//')
    OUTPUT=$(cd "$DIR" 2>/dev/null && gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh")

    # If no git info from current directory, fall back to initial git directory
    if [ -z "$REPO_NAME" ] && [ -z "$OUTPUT" ]; then
      INITIAL_GIT=$(tmux show-environment -t "$PANE_ID" "NVIM_INITIAL_GIT_$PANE_ID" 2>/dev/null | cut -d= -f2)
      if [ -n "$INITIAL_GIT" ] && [ -d "$INITIAL_GIT" ]; then
        FULL_REPO_NAME=$(basename "$(git -C "$INITIAL_GIT" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
        REPO_NAME=$(echo "$FULL_REPO_NAME" | sed 's/[-_].*//')
        OUTPUT=$(cd "$INITIAL_GIT" 2>/dev/null && gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh")
      fi
    fi

    if [ -n "$REPO_NAME" ]; then
      GIT_INFO="#[fg=${gnohj_color06}]${REPO_NAME}#[fg=${gnohj_color14}]${OUTPUT} "
    else
      GIT_INFO="${OUTPUT} "
    fi
  fi
fi

# Get all windows
WINDOWS=$(tmux list-windows -F '#{window_index}:#{window_name}:#{window_active}')

WINDOW_LIST=""
while IFS=: read -r idx name active; do
  if [ -n "$WINDOW_LIST" ]; then
    SPACING="  "
  else
    SPACING=""
  fi

  if [ "$active" = "1" ]; then
    WINDOW_LIST="${WINDOW_LIST}${SPACING}#[fg=${gnohj_color24}]*#[fg=${gnohj_color04}]${name}"
  else
    WINDOW_LIST="${WINDOW_LIST}${SPACING}#[fg=${gnohj_color08}]${name}"
  fi
done <<<"$WINDOWS"

# Build complete status line
if [ -n "$LOCK" ]; then
  echo "#[fg=${gnohj_color03},nobold]${LOCK}#[fg=${SESSION_COLOR},nobold]${SESSION_NAME} #[fg=${gnohj_color14},nobold]${GIT_INFO}${WINDOW_LIST}"
else
  echo "#[fg=${SESSION_COLOR},nobold]${SESSION_NAME} #[fg=${gnohj_color14},nobold]${GIT_INFO}${WINDOW_LIST}"
fi
