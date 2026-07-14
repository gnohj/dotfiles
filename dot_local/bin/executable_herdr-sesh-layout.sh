#!/usr/bin/env bash
# herdr-sesh-layout.sh — open a directory as a herdr workspace with the sesh dev
# layout: pen (🖋️ nvim, focused) + fish (🐠, 3 EVEN shells, backgrounded). The
# herdr-native replacement for dev.sh + dev-window.sh (which were tmux-only). Shared
# by the herdr-sesh.sh picker AND the treekanga worktree bridge, so the layout lives
# in one place. Pure herdr CLI → runs server-side, works local and over --remote.
#
# Usage: herdr-sesh-layout.sh <dir> [label]
# If a workspace already sits at <dir>, it just focuses it (sesh "attach if exists").
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
dir="${1:?usage: herdr-sesh-layout.sh <dir> [label]}"
dir="${dir/#\~/$HOME}"

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
[ -d "$dir" ] || { echo "not a directory: $dir"; exit 1; }

# Workspace label: for a git repo/worktree use the REPO name (basename of the repo
# root above the shared git dir) so every worktree of a repo reads as "web",
# "inferno", "chezmoi" — herdr then shows the branch/worktree on its own second
# sidebar line. This matches how herdr labels its native worktrees, instead of the
# bare basename (which for web/fix/IHRWEB-… would be the long ticket slug). Non-git
# dirs keep the basename (today's behavior). An explicit $2 always wins.
label="${2:-}"
if [ -z "$label" ]; then
  if command -v git >/dev/null 2>&1 && git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    common=$(cd "$dir" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)
    [ -n "$common" ] && label=$(basename "$(dirname "$common")")
  fi
  [ -n "$label" ] || label=$(basename "$dir")
fi

# Honor the sesh entry's startup_command. sesh runs an explicit per-session
# startup_command in a SINGLE window (it overrides the default dev layout), so
# web/review + inferno/review (startup_command = "ghd") open one gh-dash window,
# not pen/fish. Mirror that below. Entries with no explicit startup_command
# (StartupCommand empty) — plus zoxide/treekanga dirs not in sesh config — fall
# through to the pen/fish dev layout.
startup_cmd=""
if command -v sesh >/dev/null 2>&1; then
  startup_cmd=$(sesh list -c -j 2>/dev/null | jq -r --arg d "$dir" \
    '[.[] | select((.Path // "" | rtrimstr("/")) == ($d | rtrimstr("/"))) | .StartupCommand // ""] | map(select(. != "")) | first // ""' 2>/dev/null)
fi

# Attach-if-exists: focus a workspace already rooted at this dir (real sesh behavior).
existing=$("$herdr" pane list 2>/dev/null | jq -r --arg d "$dir" \
  '[.result.panes[] | select((.foreground_cwd // .cwd) == $d)] | (first // {}).workspace_id // empty' 2>/dev/null)
if [ -n "$existing" ]; then
  exec "$herdr" workspace focus "$existing" >/dev/null 2>&1
fi

# Create the workspace (focused) rooted at dir.
out=$("$herdr" workspace create --cwd "$dir" --label "$label" --focus 2>/dev/null)
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
pen=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
tab=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
[ -n "$ws" ] && [ -n "$pen" ] || { echo "workspace create failed"; exit 1; }

# Keep numbered tab labels position-correct as tabs open/close (herdr has no
# native renumber). Lazy-start the renumber daemon; it persists per session.
"$HOME/.local/bin/herdr-tab-renumber.py" ensure >/dev/null 2>&1 || true

# herdr tabs default their label to their own number (that's why untouched tabs
# read "1", "2" … in the bar); a custom emoji label replaces it, dropping the
# number. Re-prefix "<number>." to match tmux's `1.🖋️` window style — the number
# comes straight from each create response (.result.tab.number).
pen_n=$(printf '%s' "$out" | jq -r '.result.tab.number // empty')

# startup_command session (e.g. web/review → "ghd"): sesh opens ONE window running
# that command, no second tab. Run it in the root pane and stop. Label the tab
# "<number>.🐠" (fish) so it matches the styled "1.🖋️"/"2.🐠" tabs instead of
# herdr's bare default number badge.
if [ -n "$startup_cmd" ]; then
  "$herdr" tab rename "$tab" "${pen_n:+$pen_n.}🐠" >/dev/null 2>&1
  "$herdr" pane run "$pen" "$startup_cmd" >/dev/null 2>&1
  exit 0
fi

# Default dev layout ------------------------------------------------------------
# pen tab: nvim in the root pane. herdr pane run handles the shell-ready pacing.
"$herdr" tab rename "$tab" "${pen_n:+$pen_n.}🖋️" >/dev/null 2>&1
"$herdr" pane run "$pen" "nvim" >/dev/null 2>&1

# fish tab (backgrounded so focus stays on nvim): 3 EVEN shells. herdr --ratio is
# the fraction the TARGET pane keeps, so 1/3 then 1/2 yields even thirds — the
# dev-window.sh `even-horizontal` equivalent (herdr's default 0.5 gives 50/25/25).
ftab=$("$herdr" tab create --workspace "$ws" --label "🐠" --no-focus 2>/dev/null)
froot=$(printf '%s' "$ftab" | jq -r '.result.root_pane.pane_id // empty')
ftab_id=$(printf '%s' "$ftab" | jq -r '.result.tab.tab_id // empty')
fish_n=$(printf '%s' "$ftab" | jq -r '.result.tab.number // empty')
[ -n "$ftab_id" ] && "$herdr" tab rename "$ftab_id" "${fish_n:+$fish_n.}🐠" >/dev/null 2>&1
if [ -n "$froot" ]; then
  p2=$("$herdr" pane split "$froot" --direction right --ratio 0.3333 --no-focus 2>/dev/null \
        | jq -r '.result.pane.pane_id // empty')
  [ -n "$p2" ] && "$herdr" pane split "$p2" --direction right --ratio 0.5 --no-focus >/dev/null 2>&1
fi
