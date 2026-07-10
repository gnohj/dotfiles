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
    GIT_INFO=$(cd "$DIR" 2>/dev/null && gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh" | perl -pe 's/(#\[[^\]]*\][\s]*)+$//; s/\s+$//')
    [ -n "$GIT_INFO" ] && GIT_INFO="${GIT_INFO}  "
  fi
fi

# Get all windows
WINDOWS=$(tmux list-windows -F '#{window_index}:#{window_name}:#{window_active}')

WINDOW_LIST=""
NUM=1
while IFS=: read -r idx name active; do
  if [ -n "$WINDOW_LIST" ]; then
    SPACING="  "
  else
    SPACING=""
  fi

  # Wrap each window entry in a `range=window` marker so clicking the number or
  # emoji selects that window. tmux resolves the range's `#{window_index}` into
  # the `=` mouse target, which the default `MouseDown1Status` binding
  # (switch-client -t =) uses to jump to it. The range uses the real
  # window_index ($idx), not the sequential display number ($NUM). Spacing sits
  # outside the range so the gap between entries stays inert.
  if [ "$active" = "1" ]; then
    WINDOW_LIST="${WINDOW_LIST}${SPACING}#[range=window|${idx}]#[fg=${gnohj_color03}]${NUM}:${name}*#[norange]"
  else
    WINDOW_LIST="${WINDOW_LIST}${SPACING}#[range=window|${idx}]#[fg=${gnohj_color08}]${NUM}:${name}#[norange]"
  fi
  NUM=$((NUM + 1))
done <<<"$WINDOWS"

# Build complete status line. The session name is wrapped in a `range=user|sesh`
# marker so clicking it opens the sesh picker — the MouseDown1Status binding in
# tmux.conf checks `#{mouse_status_range}` for `sesh` and launches the switcher.
# The trailing space stays outside the range so only the name is the hit target.
SESSION_CELL="#[range=user|sesh]${SESSION_NAME}#[norange] "
if [ -n "$LOCK" ]; then
  echo "#[fg=${gnohj_color03},nobold]${LOCK}#[fg=${SESSION_COLOR},nobold]${SESSION_CELL}#[fg=${gnohj_color14},nobold]${GIT_INFO}${WINDOW_LIST}"
else
  echo "#[fg=${SESSION_COLOR},nobold]${SESSION_CELL}#[fg=${gnohj_color14},nobold]${GIT_INFO}${WINDOW_LIST}"
fi
