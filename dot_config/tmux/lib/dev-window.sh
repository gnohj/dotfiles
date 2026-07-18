#!/usr/bin/env bash
# Shared builders for the sesh "dev session" window layout: a pen (editor/nvim)
# window plus two background 3-pane shell windows — robot (AI) and hammer (dev).
# Sourced by both launchers so the layout and the window-identity emoji map live
# in ONE place:
#   * dot_config/tmux/sesh-session-created.sh  — fast path (respawns to nvim)
#   * dot_config/sesh/dev.sh                    — fallback (send-keys nvim)
#
# Callers still own HOW the pen window launches nvim (respawn vs send-keys);
# this module owns WHAT the windows are (identity + shell layout).

# The one place window-identity emojis are defined. Callers refer to the
# identity ("pen"/"robot"/"hammer"), never the literal emoji.
_dev_window_emoji() {
  case "$1" in
    pen) printf '🖊️' ;;
    robot) printf '🤖' ;;
    hammer) printf '🛠️' ;;
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

# create_shell_window <session> <dir> <type>
# Build one 3-pane even-horizontal shell window in the background (-d keeps focus
# on the pen window). <type> sets its identity emoji (robot/hammer).
create_shell_window() {
  local session="$1" dir="$2" type="$3"
  local win
  win=$(tmux new-window -d -P -F '#{window_id}' -n "$(_dev_window_emoji "$type")" -c "$dir" -t "${session}:")
  tmux split-window -h -t "$win" -c "$dir"
  tmux split-window -h -t "$win" -c "$dir"
  tmux select-layout -t "$win" even-horizontal
}

# create_dev_windows <session> <dir>
# Build both background shell windows in order — robot (AI) then hammer (dev) —
# so they land at window indices 2 and 3 after the pen window (1).
create_dev_windows() {
  local session="$1" dir="$2"
  create_shell_window "$session" "$dir" robot
  create_shell_window "$session" "$dir" hammer
}
