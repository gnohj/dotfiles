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

# Git info for current pane (branch only via gitmux)
if [ -n "$PANE_ID" ]; then
  DIR=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}')

  if [ -d "$DIR" ]; then
    GIT_INFO=$(cd "$DIR" 2>/dev/null && gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh")
    [ -n "$GIT_INFO" ] && GIT_INFO="${GIT_INFO} "
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
