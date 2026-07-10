#!/usr/bin/env bash
# Shared builders for the sesh "dev session" window layout: a pen (editor)
# window plus a background 3-pane shell ("fish") window. Sourced by both
# launchers so the layout and the window-identity emoji map live in ONE place:
#   * dot_config/tmux/sesh-session-created.sh  — fast path (respawns to nvim)
#   * dot_config/sesh/dev.sh                    — fallback (send-keys nvim)
#
# Callers still own HOW the pen window launches nvim (respawn vs send-keys);
# this module owns WHAT the windows are (identity + fish layout).

# The one place window-identity emojis are defined. Callers refer to the
# identity ("pen"/"fish"), never the literal emoji.
_dev_window_emoji() {
  case "$1" in
    pen) printf '🖊️' ;;
    fish) printf '🐠' ;;
    *) printf '❔' ;;
  esac
}

# mark_window <target> <type>
# Give a window its identity: rename it to the type's emoji. (Identity is
# carried entirely by the window name — nothing else reads a type flag.)
mark_window() {
  local target="$1" type="$2"
  tmux rename-window -t "$target" "$(_dev_window_emoji "$type")"
}

# create_fish_window <session> <dir>
# Build the 3-pane shell window in the background (-d keeps focus on the pen
# window).
create_fish_window() {
  local session="$1" dir="$2"
  local fish_win
  fish_win=$(tmux new-window -d -P -F '#{window_id}' -n "$(_dev_window_emoji fish)" -c "$dir" -t "${session}:")
  tmux split-window -h -t "$fish_win" -c "$dir"
  tmux split-window -h -t "$fish_win" -c "$dir"
  tmux select-layout -t "$fish_win" even-horizontal
}
