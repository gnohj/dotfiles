#!/usr/bin/env bash
# herdr-sesh-layout.sh — open a directory as a herdr workspace with the sesh dev
# layout: pen (🖋️ nvim, focused) + robot (🤖 AI) + hammer (🔨 dev), each a 3-EVEN
# -shell tab, backgrounded. The herdr-native replacement for dev.sh + dev-window.sh
# (which were tmux-only). Shared
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

# Workspace label: match tmux-dash's sidebar naming (its state.rs
# session_display_name -> cwd_logical_path -> shorten_segments), so a worktree reads
# the SAME in herdr as in tmux-dash. The name is DIRECTORY-derived, home-relative:
#   ~/Developer/<repo>/<worktree>        -> "<repo>/<worktree>"  (web/master, web/review)
#   ~/Developer/<repo>/<bucket>/<branch> -> "<branch>"           (bucket in fix|feat|ui|…)
#   ~/<other>/…/<leaf>  (>=3 segments)   -> "<leaf>"
#   anything else                        -> basename
# herdr still shows the real git branch on its own second sidebar line, so a review
# worktree checked out on _master reads "web/review" over "_master". Pure prefix
# expansion (no arrays / negative indices), so it stays bash-3.2 safe on macOS.
#
# A type glyph is prepended to the derived name so the sidebar reads its kind at a
# glance: 🌳 linked git worktree, 🌿 plain git repo (a branch checkout), 📁 non-git
# dir. Detection is nesting-safe (rev-parse, not a .git probe): a linked worktree's
# git-dir differs from the shared common-dir (e.g. web/.bare/worktrees/review vs
# web/.bare); a main repo's two match. An explicit $2 always wins (no glyph).
label="${2:-}"
if [ -z "$label" ]; then
  case "$dir" in
    "$HOME"/Developer/*)
      rel="${dir#"$HOME"/Developer/}"; rel="${rel%/}"
      s1="${rel%%/*}"
      rest="${rel#"$s1"}"; rest="${rest#/}"
      s2="${rest%%/*}"
      after2="${rest#"$s2"}"; after2="${after2#/}"
      s3="${after2%%/*}"
      case "$s2" in
        fix|feat|ui|infra|refactor|perf|test|chore|spike|orch|work)
          [ -n "$s3" ] && label="$s3" || label="$s1${s2:+/$s2}" ;;
        *)
          label="$s1${s2:+/$s2}" ;;
      esac
      ;;
    "$HOME"/*)
      rel="${dir#"$HOME"/}"; rel="${rel%/}"
      if [ -n "$rel" ]; then
        if [ "$(printf '%s' "$rel" | awk -F/ '{print NF}')" -ge 3 ]; then
          label="${rel##*/}"
        else
          label="$rel"
        fi
      fi
      ;;
  esac
  [ -n "$label" ] || label=$(basename "$dir")

  glyph="📁"
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    gd=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)
    gcd=$(cd "$dir" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)
    if [ -n "$gd" ] && [ -n "$gcd" ] && [ "$gd" != "$gcd" ]; then glyph="🌳"; else glyph="🌿"; fi
  fi
  label="$glyph $label"
fi

# Honor the sesh entry's startup_command. sesh runs an explicit per-session
# startup_command in a SINGLE window (it overrides the default dev layout), so
# web/review + inferno/review (startup_command = "ghd") open one gh-dash window,
# not the dev layout. Mirror that below. Entries with no explicit startup_command
# (StartupCommand empty) — plus zoxide/treekanga dirs not in sesh config — fall
# through to the pen/robot/hammer dev layout.
startup_cmd=""
if command -v sesh >/dev/null 2>&1; then
  startup_cmd=$(sesh list -c -j 2>/dev/null | jq -r --arg d "$dir" \
    '[.[] | select((.Path // "" | rtrimstr("/")) == ($d | rtrimstr("/"))) | .StartupCommand // ""] | map(select(. != "")) | first // ""' 2>/dev/null)
fi

# Attach-if-exists: focus a workspace already rooted at this dir (real sesh behavior).
existing=$("$herdr" pane list 2>/dev/null | jq -r --arg d "$dir" \
  '[.result.panes[] | select((.foreground_cwd // .cwd) == $d)] | (first // {}).workspace_id // empty' 2>/dev/null)
if [ -n "$existing" ]; then
  ( "$HOME/.local/bin/herdr-scripts/herdr-git-status.sh" --kick >/dev/null 2>&1 & )
  exec "$herdr" workspace focus "$existing" >/dev/null 2>&1
fi

# Create the workspace (focused) rooted at dir.
out=$("$herdr" workspace create --cwd "$dir" --label "$label" --focus 2>/dev/null)
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
pen=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
tab=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
[ -n "$ws" ] && [ -n "$pen" ] || { echo "workspace create failed"; exit 1; }

# Ensure the git-status poller is running (it feeds the sidebar `$git` token) and do
# an immediate pass so the new workspace's working-tree signs show without waiting for
# the next poll cycle. Detached so it never blocks this script or dies with it.
( "$HOME/.local/bin/herdr-scripts/herdr-git-status.sh" --kick >/dev/null 2>&1 & )

# herdr tabs default their label to their own number (that's why untouched tabs
# read "1", "2" … in the bar); a custom emoji label replaces it, dropping the
# number. Re-prefix "<number>." to match tmux's `1.🖋️` window style — the number
# comes straight from each create response (.result.tab.number).
pen_n=$(printf '%s' "$out" | jq -r '.result.tab.number // empty')

# startup_command session (e.g. web/review → "ghd"): sesh opens ONE window running
# that command, no extra tabs. Run it in the root pane and stop. Label the tab
# "<number>.🐚" (shell) so it matches the styled dev tabs instead of herdr's bare
# default number badge.
if [ -n "$startup_cmd" ]; then
  "$herdr" tab rename "$tab" "${pen_n:+$pen_n.}🐚" >/dev/null 2>&1
  "$herdr" pane run "$pen" "$startup_cmd" >/dev/null 2>&1
  exit 0
fi

# Default dev layout ------------------------------------------------------------
# pen tab: nvim in the root pane. herdr pane run handles the shell-ready pacing.
"$herdr" tab rename "$tab" "${pen_n:+$pen_n.}🖋️" >/dev/null 2>&1
"$herdr" pane run "$pen" "nvim" >/dev/null 2>&1

# Build one backgrounded 3-EVEN-shell tab labeled with <emoji> (--no-focus keeps
# focus on the pen/nvim tab). herdr --ratio is the fraction the TARGET pane keeps,
# so 1/3 then 1/2 yields even thirds — the dev-window.sh `even-horizontal`
# equivalent (herdr's default 0.5 gives 50/25/25).
make_shell_tab() {
  local emoji="$1" out root id num p2
  out=$("$herdr" tab create --workspace "$ws" --label "$emoji" --no-focus 2>/dev/null)
  root=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
  id=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
  num=$(printf '%s' "$out" | jq -r '.result.tab.number // empty')
  [ -n "$id" ] && "$herdr" tab rename "$id" "${num:+$num.}$emoji" >/dev/null 2>&1
  if [ -n "$root" ]; then
    p2=$("$herdr" pane split "$root" --direction right --ratio 0.3333 --no-focus 2>/dev/null \
          | jq -r '.result.pane.pane_id // empty')
    [ -n "$p2" ] && "$herdr" pane split "$p2" --direction right --ratio 0.5 --no-focus >/dev/null 2>&1
  fi
}

# robot (AI) then hammer (dev), so they land as tabs 2 and 3 after the pen tab (1).
make_shell_tab "🤖"
make_shell_tab "🔨"
