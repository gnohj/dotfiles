#!/usr/bin/env bash
# herdr-native yazi launcher — the herdr counterpart of dot_local/bin/yazi-launch.sh.
# Runs as a herdr pane command (type=pane) opened by a herdr keybind. Discovers the
# sibling pane in this tab running (n)vim; if that nvim is up on its per-pane RPC
# socket (named by init.lua: /tmp/nvim-herdr-<sanitized pane id>.sock), seed yazi
# with the active buffer's path so it lands on the file you were editing, else fall
# back to that pane's cwd, else this pane's cwd.
#
# Backwards-compat: tmux keeps yazi-launch.sh via skhd (rctrl-y) unchanged. This
# path only runs inside herdr, where HERDR_PANE_ID is set.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
TARGET=""

if [ -n "${HERDR_PANE_ID:-}" ] && command -v jq >/dev/null 2>&1 && command -v "$herdr" >/dev/null 2>&1; then
  cur_tab=$("$herdr" pane current --current 2>/dev/null | jq -r '.result.pane.tab_id // empty')
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
  done < <("$herdr" pane list 2>/dev/null \
    | jq -r --arg t "$cur_tab" --arg self "$HERDR_PANE_ID" \
        '.result.panes[] | select(.tab_id==$t and .pane_id!=$self) | [.pane_id, (.foreground_cwd // .cwd // "")] | @tsv')

  if [ -n "$host_pane" ]; then
    key="herdr-$(printf '%s' "$host_pane" | sed 's/[^A-Za-z0-9]/-/g')"
    sock="/tmp/nvim-${key}.sock"
    if [ -S "$sock" ]; then
      buf=$(nvim --server "$sock" --remote-expr 'expand("%:p")' 2>/dev/null)
      [ -n "$buf" ] && [ -e "$buf" ] && TARGET="$buf"
    fi
    [ -z "$TARGET" ] && [ -n "$host_cwd" ] && TARGET="$host_cwd"
  fi
fi

[ -z "$TARGET" ] && TARGET="$PWD"
exec yazi "$TARGET"
