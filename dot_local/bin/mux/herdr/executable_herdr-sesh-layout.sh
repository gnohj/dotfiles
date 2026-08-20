#!/usr/bin/env bash
# herdr-sesh-layout.sh — open a directory as a herdr workspace with the sesh dev
# layout: pen (🖋️ nvim, focused) + robot (🤖 AI) + hammer (🔨 dev), each a 3-EVEN
# -shell tab, backgrounded. The herdr-native replacement for dev.sh + dev-window.sh
# (which were tmux-only). Shared
# by the herdr-sesh.sh picker AND the treekanga worktree bridge, so the layout lives
# in one place. Pure herdr CLI → runs server-side, works local and over --remote.
#
# Usage: herdr-sesh-layout.sh <dir> [label]
#        herdr-sesh-layout.sh --entry <sesh Name>
# --entry takes the dir, startup_command and label from the sesh entry of that NAME, which is the only identity two entries sharing one path still differ on.
# If a workspace already sits at <dir>, it just focuses it (sesh "attach if exists").
# HERDR_SESH_NO_FOCUS=1 builds it without taking focus, for background callers; the picker leaves it unset.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
focus_flag=--focus
[ -n "${HERDR_SESH_NO_FOCUS:-}" ] && focus_flag=--no-focus
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

# One `sesh list -c -j` pass feeds both the --entry resolution and the startup_command lookup below.
sesh_json=""
command -v sesh >/dev/null 2>&1 && sesh_json=$(sesh list -c -j 2>/dev/null)

# entry_shared says whether a SECOND config entry sits at this same path; it is what switches
# the label derivation and the attach test off the directory and onto the name, below.
entry_name=""
entry_shared=""
case "${1:-}" in
  --entry) entry_name="${2:?usage: herdr-sesh-layout.sh --entry <sesh Name>}" ;;
esac
if [ -n "$entry_name" ]; then
  [ -n "$sesh_json" ] || { echo "sesh required for --entry"; exit 1; }
  resolved=$(printf '%s' "$sesh_json" | jq -r --arg n "$entry_name" '
    (map(select((.Name // "") == $n)) | first) as $e
    | if $e == null then empty
      else (($e.Path // "") | rtrimstr("/")) as $p
        | [$p, (if ([.[] | select(((.Path // "") | rtrimstr("/")) == $p)] | length) > 1
                then "shared" else "solo" end)] | @tsv
      end' 2>/dev/null)
  [ -n "$resolved" ] || { echo "no sesh entry named: $entry_name"; exit 1; }
  dir="${resolved%%$'\t'*}"
  entry_shared="${resolved#*$'\t'}"
  label=""
else
  dir="${1:?usage: herdr-sesh-layout.sh <dir> [label] | --entry <sesh Name>}"
  label="${2:-}"
fi
dir="${dir/#\~/$HOME}"
[ -d "$dir" ] || { echo "not a directory: $dir"; exit 1; }

# Workspace label: the shared sidebar naming rule (session_display_name ->
# cwd_logical_path -> shorten_segments). The name is DIRECTORY-derived and home-relative:
#   ~/Developer/<repo>/<worktree>          -> "<repo>/<worktree>"      (web/master, web/review)
#   ~/Developer/<repo>/<bucket>/<TICKET-…> -> "<repo>/<bucket>/<NUM>"  (web/infra/24314)
#   ~/Developer/<repo>/<bucket>/<branch>   -> "<repo>/<bucket>/<branch>"
#   ~/<other>/…/<leaf>  (>=3 segments)     -> "<leaf>"
#   anything else                          -> basename
# The third segment collapses to its ticket NUMBER when it has one, because the descriptive tail
# is already the sidebar's second row ($br, which strips that same key off the branch). Split
# that way each row carries something the other doesn't, instead of both spelling out
# IHRWEB-24314-listen-endpoint. The constant project prefix goes with it, ambiguous only if a
# second project ever shares this tree. A branch dir with no ticket key is kept whole - there is
# nothing to move to row two - and herdr truncates it if the row runs out. Pure prefix
# expansion (no arrays / negative indices), so it stays bash-3.2 safe on macOS.
#
# herdr-sesh.sh (derive_name) mirrors this rule and re-expands the tail - keep the two in sync.
#
# A type glyph is prepended to the derived name so the sidebar reads its kind at a
# glance: 🌳 linked git worktree, 🌿 plain git repo (a branch checkout), 📁 non-git
# dir, 🖥️ home, 🚢 the fm-personal / fm-work firstmate homes (one shared checkout).
# Detection is nesting-safe (rev-parse, not a .git probe): a linked worktree's
# git-dir differs from the shared common-dir (e.g. web/.bare/worktrees/review vs
# web/.bare); a main repo's two match. An explicit $2 always wins (no glyph).
label_explicit="$label"
# Twins share a path, and fm-settings' leaf reads as the fm-work home it is not - both label by sesh Name.
if [ -z "$label" ] && { [ "$entry_shared" = shared ] || [ "$entry_name" = fm-settings ]; }; then
  label="$entry_name"
elif [ -z "$label" ]; then
  case "$dir" in
    "$HOME"/Developer/*)
      rel="${dir#"$HOME"/Developer/}"; rel="${rel%/}"
      s1="${rel%%/*}"
      rest="${rel#"$s1"}"; rest="${rest#/}"
      s2="${rest%%/*}"
      after2="${rest#"$s2"}"; after2="${after2#/}"
      s3="${after2%%/*}"
      # grep, not [[ =~ ]], to stay bash-3.2 safe like the rest of this block. Key shape
      # [A-Z]+-[0-9]+ is the same one launcher.sh and worktree already parse out of branches.
      if [ -n "$s3" ]; then
        key=$(printf '%s' "$s3" | grep -oE '^[A-Z]+-[0-9]+' | head -n1)
        [ -n "$key" ] && s3="${key##*-}"
      fi
      label="$s1${s2:+/$s2}${s3:+/$s3}"
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
fi

if [ -z "$label_explicit" ]; then
  glyph="📁"
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Both sides physical (pwd -P): a logical pwd made every symlinked repo read as a worktree.
    gd=$(cd "$dir" 2>/dev/null && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)
    gcd=$(cd "$dir" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
    if [ -n "$gd" ] && [ -n "$gcd" ] && [ "$gd" != "$gcd" ]; then glyph="🌳"; else glyph="🌿"; fi
  fi
  [ "${dir%/}" = "${HOME%/}" ] && glyph="🖥️"
  case "$label" in fm-personal|fm-work) glyph="🚢" ;; esac
  label="$glyph $label"
fi

# Honor the sesh entry's startup_command. sesh runs an explicit per-session
# startup_command in a SINGLE window (it overrides the default dev layout), so
# web/review + inferno/review (startup_command = "ghd") open one gh-dash window,
# not the dev layout. Mirror that below. Entries with no explicit startup_command
# (StartupCommand empty) — plus zoxide/treekanga dirs not in sesh config — fall
# through to the pen/robot/hammer dev layout.
#
# --entry matches the NAME instead, so a twin runs its own command rather than inheriting `first`.
startup_cmd=""
if [ -n "$sesh_json" ] && [ -n "$entry_name" ]; then
  startup_cmd=$(printf '%s' "$sesh_json" | jq -r --arg n "$entry_name" \
    '[.[] | select((.Name // "") == $n) | .StartupCommand // ""] | map(select(. != "")) | first // ""' 2>/dev/null)
elif [ -n "$sesh_json" ]; then
  startup_cmd=$(printf '%s' "$sesh_json" | jq -r --arg d "$dir" \
    '[.[] | select((.Path // "" | rtrimstr("/")) == ($d | rtrimstr("/"))) | .StartupCommand // ""] | map(select(. != "")) | first // ""' 2>/dev/null)
fi

# Attach-if-exists: focus a workspace already rooted at this dir (real sesh behavior).
# The background caller cd's into the new worktree first, so its own pane would read as "already open here" and skip the create.
self_pane=""
[ "$focus_flag" = --no-focus ] && self_pane="${HERDR_PANE_ID:-}"
if [ "$entry_shared" = shared ]; then
  # Twins report one cwd, so a cwd match focuses the sibling and a second workspace can never exist; the label is the only thing that separates them.
  existing=$("$herdr" workspace list 2>/dev/null | jq -r --arg l "$label" \
    '[.result.workspaces[] | select((((.label // "") | split(" · ")[0]) | rtrimstr(" ")) == $l)] | (first // {}).workspace_id // empty' 2>/dev/null)
else
  existing=$("$herdr" pane list 2>/dev/null | jq -r --arg d "$dir" --arg self "$self_pane" \
    '[.result.panes[] | select($self == "" or .pane_id != $self) | select((.foreground_cwd // .cwd) == $d)] | (first // {}).workspace_id // empty' 2>/dev/null)
fi

# Home matches by label too: herdr's API carries no workspace root cwd, so a pin whose pane cd'd off ~ gets twinned.
if [ -z "$existing" ] && [ "${dir%/}" = "${HOME%/}" ]; then
  existing=$("$herdr" workspace list 2>/dev/null | jq -r --arg l "$label" \
    '[.result.workspaces[] | select(.label == $l)] | (first // {}).workspace_id // empty' 2>/dev/null)
fi

if [ -n "$existing" ]; then
  ( "$HOME/.local/bin/mux/herdr/herdr-git-status.sh" --kick >/dev/null 2>&1 & )
  [ "$focus_flag" = --no-focus ] && exit 0
  exec "$herdr" workspace focus "$existing" >/dev/null 2>&1
fi

# Create the workspace rooted at dir, focused unless the caller asked for background.
out=$("$herdr" workspace create --cwd "$dir" --label "$label" "$focus_flag" 2>/dev/null)
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
pen=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
tab=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
[ -n "$ws" ] && [ -n "$pen" ] || { echo "workspace create failed"; exit 1; }

# Ensure the git-status poller is running (it feeds the sidebar `$git` and `$br` tokens) and do
# an immediate pass so the new workspace's working-tree signs show without waiting for
# the next poll cycle. Detached so it never blocks this script or dies with it.
( "$HOME/.local/bin/mux/herdr/herdr-git-status.sh" --kick >/dev/null 2>&1 & )

# No sysinfo --kick any more: that daemon is retired, its line lives in tab_bar_right, and a kick here would rebuild the pinned space it maintained.

# herdr tabs default their label to their own number (that's why untouched tabs
# read "1", "2" … in the bar); a custom emoji label replaces it, dropping the
# number. Re-prefix "<number>." to match tmux's `1.🖋️` window style — the number
# comes straight from each create response (.result.tab.number).
pen_n=$(printf '%s' "$out" | jq -r '.result.tab.number // empty')

# startup_command session (e.g. web/review → "ghd"): sesh opens ONE window running
# that command, no extra tabs. Run it in the root pane and stop. Label the tab
# "<number>.🐟" (shell) so it matches the styled dev tabs instead of herdr's bare
# default number badge.
if [ -n "$startup_cmd" ]; then
  "$herdr" tab rename "$tab" "${pen_n:+$pen_n.}🐟" >/dev/null 2>&1
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
