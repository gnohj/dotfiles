#!/usr/bin/env bash
# herdr-native yazi launcher — the herdr counterpart of dot_local/bin/mux/tmux/yazi-launch.sh.
# Runs detached as a herdr shell keybind (type=shell) on prefix+y. Discovers the pane in
# this tab running (n)vim; if that nvim is up on its per-pane RPC socket (named by
# init.lua: /tmp/nvim-herdr-<sanitized pane id>.sock), seed yazi with the active
# buffer's path so it lands on the file you were editing, else fall back to that
# pane's cwd, else the focused pane's cwd. yazi then opens in a NEW TAB rooted at that
# dir (labeled "<number>.📂") which closes again when you quit yazi.
#
# Backwards-compat: tmux keeps yazi-launch.sh on its own prefix+y bind; this path only runs inside herdr.
set -uo pipefail

# Own the PATH like every sibling: a keybind command inherits the herdr server's env, which is a snapshot from whenever the server started.
. "$HOME/.local/bin/mux/shared/mux-env.sh"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

herdr="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

# One snapshot for focused pane/tab/workspace + every pane's cwd: type="shell" runs detached, so $PWD is not the pane's dir.
snap=$("$herdr" api snapshot 2>/dev/null | jq -c '.result.snapshot // empty')
[ -n "$snap" ] || exit 0

cur_tab=$(printf '%s' "$snap" | jq -r '.focused_tab_id // empty')
cur_ws=$(printf '%s' "$snap" | jq -r '.focused_workspace_id // empty')
cur_cwd=$(printf '%s' "$snap" | jq -r '
  . as $s | ($s.panes[] | select(.pane_id == $s.focused_pane_id)) | (.foreground_cwd // .cwd) // empty')

TARGET=""
host_pane=""
host_cwd=""
while IFS=$'\t' read -r pid pcwd; do
  [ -n "$pid" ] || continue
  name=$("$herdr" pane process-info --pane "$pid" 2>/dev/null \
    | jq -r '.result.process_info.foreground_processes[]?.name' 2>/dev/null)
  if printf '%s\n' "$name" | grep -qiE '^(view|l?n?vim?x?)$'; then
    host_pane="$pid"
    host_cwd="$pcwd"
    break
  fi
done < <(printf '%s' "$snap" \
  | jq -r --arg t "$cur_tab" \
      '[.panes[] | select(.tab_id==$t)] | sort_by(.focused != true) | .[] | [.pane_id, (.foreground_cwd // .cwd // "")] | @tsv')

if [ -n "$host_pane" ]; then
  key="herdr-$(printf '%s' "$host_pane" | sed 's/[^A-Za-z0-9]/-/g')"
  sock="/tmp/nvim-${key}.sock"
  if [ -S "$sock" ]; then
    buf=$(nvim --server "$sock" --remote-expr 'expand("%:p")' 2>/dev/null)
    [ -n "$buf" ] && [ -e "$buf" ] && TARGET="$buf"
  fi
  [ -z "$TARGET" ] && [ -n "$host_cwd" ] && TARGET="$host_cwd"
fi

[ -z "$TARGET" ] && TARGET="$cur_cwd"
[ -n "$TARGET" ] && [ -e "$TARGET" ] || TARGET="$HOME"

# The tab is rooted at a DIRECTORY (a file target still opens yazi on the file, hovered).
if [ -d "$TARGET" ]; then dir="$TARGET"; else dir=$(dirname "$TARGET"); fi

out=$("$herdr" tab create ${cur_ws:+--workspace "$cur_ws"} --cwd "$dir" --label "📂" --focus 2>/dev/null)
root=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
tab=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
ws=$(printf '%s' "$out" | jq -r '.result.tab.workspace_id // empty')
[ -n "$root" ] || { echo "tab create failed"; exit 1; }

# Re-prefix "<number>." (a custom label replaces herdr's number badge), from the tab's POSITION: .tab.number is a creation counter that climbs as tabs close (a lone tab reported 15).
if [ -n "$tab" ]; then
  num=$("$herdr" tab list 2>/dev/null \
    | jq -r --arg ws "$ws" --arg id "$tab" \
        '([.result.tabs[] | select(.workspace_id == $ws) | .tab_id] | index($id) // empty) | if . == null then empty else . + 1 end')
  "$herdr" tab rename "$tab" "${num:+$num.}📂" >/dev/null 2>&1
fi

# YAZI_START_DIR mirrors the `y` alias so yazi.toml's edit opener returns nvim to the launch dir; trailing `exit` closes the tab on quit.
"$herdr" pane run "$root" \
  "YAZI_START_DIR=$(printf %q "${host_cwd:-$dir}") yazi $(printf %q "$TARGET"); exit" >/dev/null 2>&1
