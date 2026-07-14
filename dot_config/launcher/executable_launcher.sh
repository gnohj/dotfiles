#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154
#
# Omarchy-style fzf launcher. Single-source registry: every entry is declared
# once (CATEGORIES + ACTIONS + SIMPLE_ACTIONS); the NORMAL pointer list, the
# flattened INSERT-mode fuzzy corpus, and dispatch are all derived from it — so
# labels can't drift out of sync and adding an entry is a one-line edit.
#
# Flags:
#   --preview <line>   emit preview content for <line> (called by fzf --preview)
#   --category <ID>    open directly into the named category's submenu

set -euo pipefail

SELF="${BASH_SOURCE[0]}"

# Backend mode. `tmux` (default): the launcher runs inside a tmux popup, so
# window-opening / pane actions drive tmux. `herdr`: the launcher runs standalone
# (e.g. the ghostty quake), so those actions drive herdr's socket API instead.
# Entry points set this; ALL the menu/registry/engine logic below is shared and
# identical for both. See launcher-quake.sh for the herdr entry point.
LAUNCHER_MODE="${LAUNCHER_MODE:-tmux}"

[ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# fzf colors using current colorscheme (matches FZF_DEFAULT_OPTS from zshrc)
FZF_COLORS="--color=bg+:$gnohj_color13,border:$gnohj_color03,fg:$gnohj_color04,fg+:$gnohj_color04,hl+:$gnohj_color04,info:$gnohj_color09,prompt:$gnohj_color04,pointer:$gnohj_color04,marker:$gnohj_color04,header:$gnohj_color09"

#===============================================================================
# Registry — the only thing you edit to add/rename entries
#===============================================================================

# id|prefix|pointer|header|prompt|leaf_provider|submenu_fn|leaf_handler
#   leaf_provider  static (leaves from ACTIONS) | fn emitting labels at runtime
#   submenu_fn     generic | custom fn (themes drilldown, aerospace header)
#   leaf_handler   static (label→ACTIONS fn)    | fn called as `fn "<label>"`
CATEGORIES=(
  "AI|🤖 AI|🤖 AI ›|AI|AI > |static|generic|static"
  "AERO|🖥  Aerospace|🖥  Aerospace Profiles ›|Aerospace|Profile > |provide_aerospace|aerospace_menu|handle_aerospace"
  "OPEN|🔗 Open|🔗 Open ›|Open|Open > |static|generic|static"
  "BROWSER|🌐 Browser|🌐 Browser ›|Browser|Browser > |static|generic|static"
  "FZF|🔎 Fzf|🔎 Fzf ›|Fzf|Fzf > |static|generic|static"
  "SYNC|🔁 Sync|🔁 Sync ›|Sync|Sync > |static|generic|static"
  "SYSTEM|🔧 System|🔧 System ›|System|System > |static|generic|static"
  "THEMES|🎨 Themes|🎨 Themes ›|Themes|Theme > |provide_themes|themes_menu|handle_theme"
  "WORKTREES|🌳 Worktrees|🌳 Worktrees ›|Worktrees|Worktree > |static|generic|static"
)

# Static leaves — prefix|label|function|description
ACTIONS=(
  "🤖 AI|🔥 Codeburn (cost)|act_ai_codeburn|Show today's AI spending via codeburn report"
  "🤖 AI|📊 RTK Savings (graph)|act_ai_rtk|Graph RTK token savings with rtk gain"
  "🤖 AI|👤 Claude Desktop (personal)|act_ai_claude_personal|Launch the Claude Desktop app signed into personal"
  "🤖 AI|💼 Claude Desktop (work)|act_ai_claude_work|Launch the Claude Desktop app signed into work"

  "🔗 Open|🔗 Open PR|act_browser_pr|Open the GitHub PR for the current branch in browser"
  "🔗 Open|📂 Open Note|act_notes_current|Open the Obsidian vault note for this ticket in nvim"
  "🔗 Open|🎫 Open Jira|act_browser_jira|Open the Jira ticket for the current branch in browser"

  "🌐 Browser|🐙 Open Dotfiles|act_browser_dotfiles|Open the dotfiles repo on GitHub"

  "🔎 Fzf|🔎 Aliases (fza)|act_fzf_aliases|Browse and copy alias names via fzf"
  "🔎 Fzf|🔍 Env Vars (fze)|act_fzf_env|Browse and copy env var values via television"
  "🔎 Fzf|📋 Logs (fzl)|act_fzf_logs|Open a log file in nvim via television"

  "🔁 Sync|🚀 Autopush Repos|act_sync_autopush|Run github-auto-push on all tracked repos"

  "🔧 System|🔧 System Setup|act_system_setup|Run system-setup.sh (brew, nix, packages)"
  "🔧 System|⬆️ System Update|act_system_update|nix flake update + darwin-rebuild switch"
  "🔧 System|👤 User Setup|act_system_usersetup|Run user-setup.sh (dotfiles, configs)"
  "🔧 System|🎯 All (update + setup + user-setup)|act_system_all|Run all three setup steps in sequence with one sudo prompt"

  "🌳 Worktrees|🌳 Add Worktree|act_worktree_add|Create a new git worktree interactively"
  "🌳 Worktrees|✨ AI Add Worktree (prompt → worktree)|act_worktree_ai_prompt|Type free-text; Claude infers the ticket and creates the worktree"
  "🌳 Worktrees|🎫 AI Add Worktree (Chrome tab (jira) → worktree)|act_worktree_jira|Capture the active Chrome Jira tab and create a worktree"
  "🌳 Worktrees|📋 AI Add Worktree (clipboard → worktree)|act_worktree_clipboard|Use clipboard content (text or image) to create a worktree"
  "🌳 Worktrees|🐛 AI Add Worktree (clipboard → Jira bug → worktree)|act_worktree_bug|Classify clipboard as a bug, file Jira ticket, create worktree"
  "🌳 Worktrees|🔁 AI Retry capture → worktree|act_worktree_retry|Retry the most-recent worktree capture with refined context"
  "🌳 Worktrees|🗑  Delete Worktree|act_worktree_delete|Interactively select and delete a git worktree"
)

# Top-level actions with no submenu — label|function|description
SIMPLE_ACTIONS=(
  "📦 Check Outdated Packages|act_outdated|Check for outdated Homebrew, mise, and nix packages"
  "🧹 Cleanup Logs|act_cleanup_logs|Delete old log files from ~/.logs"
  "🌿 Copy Current Branch|act_copy_branch|Copy the current git branch name to clipboard"
  "[tmux] 📋 Copy Pane Address|act_copy_pane_address|Copy the focused pane's address — server · session · window · pane (1-based) · pane-id — to clipboard"
  "🧼 Dirty Repos|act_dirty_repos|List all repos with uncommitted changes"
  "👻 Toggle Transparency|act_toggle_transparency|Toggle terminal background transparency"
)

# Exact NORMAL-mode order — cat:<ID> (renders pointer) or simple:<label>.
TOP_LEVEL_ORDER=(
  "cat:AI" "cat:AERO" "cat:OPEN" "cat:BROWSER"
  "simple:📦 Check Outdated Packages" "simple:🧹 Cleanup Logs" "simple:🌿 Copy Current Branch"
  "simple:[tmux] 📋 Copy Pane Address"
  "simple:🧼 Dirty Repos" "cat:FZF" "cat:SYNC" "cat:SYSTEM" "cat:THEMES"
  "simple:👻 Toggle Transparency" "cat:WORKTREES"
)

# Preview command: call this script in --preview mode with the selected line.
PREVIEW_CMD="\"$SELF\" --preview {}"

#===============================================================================
# Engine — derives all three views from the registry
#===============================================================================

# Populate REC0..REC7 with a category's fields by id; 1 if unknown.
get_cat() {
  local rec
  for rec in "${CATEGORIES[@]}"; do
    case "$rec" in
    "$1|"*)
      IFS='|' read -r REC0 REC1 REC2 REC3 REC4 REC5 REC6 REC7 <<<"$rec"
      return 0
      ;;
    esac
  done
  return 1
}

# Emit leaf labels (no prefix). $1=prefix $2=leaf_provider.
leaves_of() {
  if [ "$2" = static ]; then
    local rec p l f desc
    for rec in "${ACTIONS[@]}"; do
      IFS='|' read -r p l f desc <<<"$rec"
      [ "$p" = "$1" ] && printf '%s\n' "$l"
    done
  else
    "$2"
  fi
}

# Static leaf (prefix,label) → function name; 1 if not found.
action_fn() {
  local rec p l f desc
  for rec in "${ACTIONS[@]}"; do
    IFS='|' read -r p l f desc <<<"$rec"
    [ "$p" = "$1" ] && [ "$l" = "$2" ] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# Run a terminal action, then return to the caller. In herdr mode the launcher is
# a persistent root-menu loop (see the entry point), so every action — a process,
# a GUI hand-off, a worktree capture — returns to the root menu the moment it
# finishes. Nothing dismisses the quake per-action; only an explicit Ctrl+C tears
# the picker down. In tmux mode the popup closes on its own when the launcher
# exits, exactly as before.
run_action() {
  local fn="$1"
  shift
  "$fn" "$@"
}

# Run a chosen leaf. $1=prefix $2=label $3=leaf_handler.
run_leaf() {
  if [ "$3" = static ]; then
    local fn
    fn=$(action_fn "$1" "$2") || { back_to_root; return; }
    run_action "$fn"
  else
    run_action "$3" "$2"
  fi
}

provide_themes() {
  [ -d "$HOME/.config/colorscheme/list" ] || return 0
  find "$HOME/.config/colorscheme/list" -maxdepth 1 -name "*.sh" -type f -print0 |
    xargs -0 -n 1 basename | sort
}

provide_aerospace() {
  local dir="$HOME/.config/aerospace/profiles"
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -name '*.toml' -exec basename {} .toml \; 2>/dev/null | sort
}

handle_theme() { "$HOME/.config/zshrc/colorscheme-set.sh" "$1"; }
handle_aerospace() {
  "$HOME/.local/bin/aerospace-profile" "$1"
  sleep 1
}

# NORMAL mode: clean pointer list interleaved with standalone simple actions.
build_top_level_items() {
  local tok
  for tok in "${TOP_LEVEL_ORDER[@]}"; do
    case "$tok" in
    cat:*) get_cat "${tok#cat:}" && printf '%s\n' "$REC2" ;;
    simple:*) printf '%s\n' "${tok#simple:}" ;;
    esac
  done
}

# INSERT mode: breadcrumb-prefixed leaves so fuzzy-typing any partial name
# ("tokyo", "laptop", "open pr") resolves in one shot.
build_flattened_leaves() {
  local rec id prefix pointer header prompt provider submenu handler leaf
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler <<<"$rec"
    while IFS= read -r leaf; do
      [ -n "$leaf" ] && printf '%s › %s\n' "$prefix" "$leaf"
    done < <(leaves_of "$prefix" "$provider")
  done
}

# Emit preview content for a selected line. Called via --preview mode.
do_preview() {
  local line="$1"

  # Category pointer (e.g. "🌳 Worktrees ›") — list its leaves.
  local rec id prefix pointer header prompt provider submenu handler
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler <<<"$rec"
    if [ "$line" = "$pointer" ]; then
      printf '%s\n\n' "$header"
      leaves_of "$prefix" "$provider" | while IFS= read -r leaf; do
        printf '  %s\n' "$leaf"
      done
      return 0
    fi
  done

  # INSERT breadcrumb (e.g. "🌳 Worktrees › 🌳 Add Worktree") or bare leaf label.
  local p l f desc
  for rec in "${ACTIONS[@]}"; do
    IFS='|' read -r p l f desc <<<"$rec"
    if [ "$line" = "$p › $l" ] || [ "$line" = "$l" ]; then
      printf '%s\n' "$desc"
      return 0
    fi
  done

  # Simple action.
  local lbl fn
  for rec in "${SIMPLE_ACTIONS[@]}"; do
    IFS='|' read -r lbl fn desc <<<"$rec"
    if [ "$line" = "$lbl" ]; then
      printf '%s\n' "$desc"
      return 0
    fi
  done

  return 0
}

# Generic drilldown for static categories: list leaves + Back, then dispatch.
# $1 prefix $2 header $3 prompt $4 leaf_provider $5 leaf_handler.
generic_submenu() {
  local choice rc=0
  choice=$(
    {
      leaves_of "$1" "$4"
      printf "← Back\n"
    } | ~/.local/bin/fzf-vim.sh --height="${LAUNCHER_SUBMENU_HEIGHT:-40%}" --header="$2" --prompt="$3" --ansi $FZF_COLORS \
      --preview "$PREVIEW_CMD" --preview-window 'right:50%:wrap:border-left'
  ) || rc=$?
  quit_on_interrupt "$rc"
  clear
  case "$choice" in
  "← Back" | "") back_to_root ;;
  *) run_leaf "$1" "$choice" "$5" ;;
  esac
}

main_menu() {
  local choice insert_corpus rc=0
  # INSERT corpus = top-level + flattened leaves; NORMAL list = top-level only.
  insert_corpus=$({
    build_top_level_items
    build_flattened_leaves
  })
  choice=$(build_top_level_items |
    FZF_VIM_INSERT_INPUT="$insert_corpus" \
      ~/.local/bin/fzf-vim.sh --height=100% --prompt="❯ " --ansi $FZF_COLORS \
      --preview "$PREVIEW_CMD" --preview-window 'right:50%:wrap:border-left') || rc=$?
  quit_on_interrupt "$rc"
  clear
  # Empty = Esc / aborted fzf. Never an exit: in herdr mode the loop just redraws
  # root (only Ctrl+C quits); in tmux mode returning falls through to the end of
  # the script, closing the popup as before.
  [ -z "$choice" ] && return 0
  dispatch_root "$choice"
  return 0
}

dispatch_root() {
  local choice="$1" rec id prefix pointer header prompt provider submenu handler
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler <<<"$rec"
    case "$choice" in
    "$prefix › "*)
      run_leaf "$prefix" "${choice#"$prefix › "}" "$handler"
      return
      ;;
    esac
    if [ "$choice" = "$pointer" ]; then
      if [ "$submenu" = generic ]; then
        generic_submenu "$prefix" "$header" "$prompt" "$provider" "$handler"
      else
        "$submenu"
      fi
      return
    fi
  done
  local s lbl fn desc
  for s in "${SIMPLE_ACTIONS[@]}"; do
    IFS='|' read -r lbl fn desc <<<"$s"
    [ "$choice" = "$lbl" ] && { run_action "$fn"; return; }
  done
  return 0
}

#===============================================================================
# Custom submenus (bespoke: nested drilldown / dynamic header)
#===============================================================================

# Themes drilldown. Flattened root leaves still jump straight to a theme.
themes_menu() {
  local choice rc=0
  choice=$(printf "🎨 All\n🌙 Dark\n☀️ Light\n← Back" |
    ~/.local/bin/fzf-vim.sh --height=40% --header="Themes" --prompt="Theme > " --ansi $FZF_COLORS) || rc=$?
  quit_on_interrupt "$rc"
  case "$choice" in
  "🎨 All") themes_filtered "" "All Themes" "All > " ;;
  "🌙 Dark") themes_filtered "dark" "Dark Themes" "Dark > " ;;
  "☀️ Light") themes_filtered "light" "Light Themes" "Light > " ;;
  *) back_to_root ;;
  esac
}

# $1 = name filter ("" = all), $2 = header, $3 = prompt.
themes_filtered() {
  local schemes_dir="$HOME/.config/colorscheme/list" sel
  sel=$(
    {
      find "$schemes_dir" -name "*.sh" -type f -print0 | xargs -0 -n 1 basename |
        { [ -n "$1" ] && grep -i "$1" || cat; }
      printf "← Back\n"
    } | fzf --height=40% --reverse --header="$2" --prompt="$3" --no-info $FZF_COLORS
  ) || true
  case "$sel" in
  "← Back" | "") themes_menu ;;
  *) "$HOME/.config/zshrc/colorscheme-set.sh" "$sel" ;;
  esac
}

# Custom so the header can show the currently-active profile.
aerospace_menu() {
  local active choice rc=0
  active="$(cat "$HOME/.config/aerospace/.active-profile" 2>/dev/null || echo '(none)')"
  choice=$(
    {
      provide_aerospace
      printf "← Back\n"
    } | ~/.local/bin/fzf-vim.sh --height=40% --header="Aerospace profile (active: $active)" \
      --prompt="Profile > " --ansi $FZF_COLORS
  ) || rc=$?
  quit_on_interrupt "$rc"
  case "$choice" in
  "← Back" | "") back_to_root ;;
  *) handle_aerospace "$choice" ;;
  esac
}

# fza — copy an alias name to the clipboard.
aliases_menu() {
  local selected rc=0
  # Grep alias decls from rc files instead of sourcing zshrc (zinit + plugins
  # make a non-interactive `source` hang inside the popup).
  selected=$(grep -hE "^[[:space:]]*alias [A-Za-z0-9_.-]+=" \
    "$HOME/.config/zshrc/.zshrc" "$HOME/.zsh_gnohj_env" \
    "$HOME/.zsh_aws_cmds" "$HOME/.zsh_radioctl_cmds" 2>/dev/null |
    sed -E 's/^[[:space:]]*alias //' | sort -u |
    ~/.local/bin/fzf-vim.sh --height=80% \
      --header="Aliases (select to copy) - Type to search" --prompt="Alias > " $FZF_COLORS) || rc=$?
  quit_on_interrupt "$rc"
  if [[ -n "$selected" ]]; then
    echo -n "${selected%%=*}" | pbcopy
    echo "Copied to clipboard: ${selected%%=*}"
    sleep 1
  fi
}

#===============================================================================
# Actions (bodies ported verbatim; load-bearing comments kept)
#===============================================================================

# Resolve the working directory of the pane the launcher should act on, across
# every context the launcher can run in:
#
#   * plain tmux (default socket or any -L server): the active pane of the
#     active window IS the repo pane. A bare `display-message -p
#     '#{pane_current_path}'` can resolve to the popup itself (same trap fixed
#     in act_copy_pane_address), so we read it from `list-panes` instead —
#     popups are excluded from `list-panes`, so the real pane wins every time.
#   * herdr (launcher drawn in the tmux popup): the `-L herdr` tmux host is an
#     INVISIBLE shell — its only pane runs the `herdr` client, and the actual
#     repo pane is managed by herdr, not tmux (so tmux only ever reports the
#     herdr host's cwd, ~). Detect that (active tmux pane command == herdr) and
#     ask herdr's socket API for the focused pane's cwd instead.
#   * NO multiplexer around us (run via the `launcher` alias in the ghostty quake
#     or any plain shell): tmux reports nothing, so ask herdr's socket for its
#     GLOBALLY-focused pane cwd (see herdr_focused_cwd above).
#
# Empty output lets callers fall back to $PWD. Every step is guarded so a
# missing tool / stopped server degrades to the plain-tmux path, never worse
# than the pre-fix behavior.
# herdr's GLOBALLY-focused pane cwd, straight over the socket API — needs neither
# tmux nor the HERDR pane env, so it resolves from the ghostty quake or any
# standalone shell. herdr's own focus does not move when macOS focus shifts to
# the quake window, so this still points at the pane you were looking at.
herdr_focused_cwd() {
  command -v herdr >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  herdr api snapshot 2>/dev/null | jq -r '
    .result.snapshot as $s
    | $s.panes[]? | select(.pane_id == $s.focused_pane_id)
    | .foreground_cwd // .cwd // empty' 2>/dev/null
}

focused_pane_path() {
  local line cmd path hcwd
  # `|| true` so a failing tmux (running standalone, e.g. from the quake, where
  # there is no tmux server) does not trip `set -euo pipefail` and abort the whole
  # launcher before the herdr-focus fallback below can run.
  line=$(tmux list-panes -s -f '#{&&:#{window_active},#{pane_active}}' \
    -F '#{pane_current_command}	#{pane_current_path}' 2>/dev/null | head -1) || true
  cmd=${line%%$'\t'*}
  path=${line#*$'\t'}

  if [ "$cmd" = herdr ] && command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    hcwd=$(herdr pane process-info --current 2>/dev/null |
      jq -r '[.result.process_info.foreground_processes[].cwd]
               | map(select(. != null and . != "")) | .[-1] // empty' 2>/dev/null) || hcwd=""
    [ -n "$hcwd" ] && { printf '%s' "$hcwd"; return; }
  fi

  # No tmux context around us (run via the `launcher` alias in the ghostty quake
  # or any plain shell): ask herdr's socket for its globally-focused pane cwd.
  if [ -z "$path" ]; then
    hcwd=$(herdr_focused_cwd) && [ -n "$hcwd" ] && { printf '%s' "$hcwd"; return; }
  fi

  printf '%s' "$path"
}

# Transient message. tmux mode uses the tmux status line; standalone prints inline.
notify() {
  if [ "$LAUNCHER_MODE" = herdr ]; then
    echo "$1"
    sleep 1.5
  else
    tmux display-message -d 3000 "$1" 2>/dev/null || { echo "$1"; sleep 1.5; }
  fi
}

# Open <cmd> in a fresh window/tab labeled <label>, optionally rooted at <dir>.
# tmux mode → new tmux window. herdr mode → new herdr tab in the focused
# workspace (herdr defaults the new tab to the focused workspace), then run <cmd>
# in that tab's root pane over the socket API.
open_window() {
  local label="$1" cmd="$2" dir="${3:-}" pane
  if [ "$LAUNCHER_MODE" = herdr ]; then
    command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 ||
      { notify "herdr/jq not available"; return 1; }
    pane=$(herdr tab create --label "$label" ${dir:+--cwd "$dir"} --focus 2>/dev/null |
      jq -r '.result.root_pane.pane_id // empty') || pane=""
    if [ -n "$pane" ]; then
      herdr pane run "$pane" "$cmd"
    else
      notify "herdr: could not open tab"
    fi
  else
    tmux new-window -n "$label" "$cmd" 2>/dev/null || { notify "tmux: could not open window"; return 1; }
  fi
}

# Open a NAMED command window. tmux mode delegates to tmux-window-simple.sh (which
# reuses a window by emoji and keeps the shell alive after the command); herdr
# mode opens a herdr tab running the command (optionally keeping a shell open).
open_named_window() {
  local emoji="$1" name="$2" cmd="$3" keepopen="${4:-}" run
  if [ "$LAUNCHER_MODE" = herdr ]; then
    run="$cmd"
    [ -n "$keepopen" ] && run="$cmd; exec ${SHELL:-/bin/zsh} -l"
    open_window "$emoji" "$run"
  else
    ~/.config/skhd/tmux-window-simple.sh "$emoji" "$name" "$cmd" $keepopen
  fi
}

# In herdr mode the launcher runs inside the ghostty quake; once an action hands
# off to a herdr tab, dismiss the quake so the herdr window comes forward. Ghostty
# has no CLI to toggle the quick terminal, so we send its toggle keybind (cmd+s,
# per ghostty/config `keybind = cmd+s=toggle_quick_terminal`) via System Events —
# key code 1 = 's'. Best-effort: needs Accessibility permission for the terminal;
# silently no-ops otherwise. Only fires in herdr mode (the quake), never in tmux.
dismiss_quake() {
  [ "$LAUNCHER_MODE" = herdr ] || return 0
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e 'tell application "System Events" to key code 1 using {command down}' >/dev/null 2>&1 || true
}

# Ctrl+C is a hard quit from any picker. fzf-vim.sh exits 130 on Ctrl+C (esc
# exits 1 = go back). The persistent herdr-mode loop treats an aborted picker as
# "redraw root", so without this Ctrl+C would just bounce back to the menu — the
# user wants it to bypass that and tear the launcher (and the quake) down. Called
# right after each picker with its captured exit code; runs in the main shell (the
# `$(...)` capture is a subshell, but its exit code propagates out), so `exit`
# here ends the whole launcher. In tmux mode dismiss_quake no-ops and the exit
# closes the popup — Ctrl+C dismissing the popup is correct there too.
quit_on_interrupt() {
  [ "${1:-0}" = 130 ] || return 0
  dismiss_quake
  exit 0
}

# Navigate "up one level" to the root menu. In herdr mode the launcher is a
# persistent loop (see the entry point), so returning unwinds to it and root
# re-renders. In tmux mode there's no loop, so recurse into main_menu to redraw
# root in place — the original single-popup behavior, unchanged.
back_to_root() {
  [ "$LAUNCHER_MODE" = herdr ] && return 0
  main_menu
}

# Guard for actions still wired only to tmux: in herdr mode, say so and bail
# instead of aborting the launcher under `set -euo pipefail`.
require_tmux() {
  [ "$LAUNCHER_MODE" = herdr ] && { notify "'$1' is tmux-only for now"; return 1; }
  return 0
}

act_ai_codeburn() { open_named_window 🔥 codeburn "~/.local/share/mise/shims/codeburn report --period today" true; }
act_ai_rtk() { open_named_window 📊 rtk "/opt/homebrew/bin/rtk gain --graph"; }
act_ai_claude_personal() { "$HOME/.local/bin/claude-desktop" personal; }
act_ai_claude_work() { "$HOME/.local/bin/claude-desktop" work; }

act_browser_pr() {
  export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
  pane_path=$(focused_pane_path)
  cd "${pane_path:-$PWD}" 2>/dev/null || true
  if gh pr view --web 2>/dev/null; then
    echo "Opened PR for current branch"
  elif [ -z "$(git symbolic-ref -q --short HEAD 2>/dev/null)" ] && detached_ref=$(git branch --points-at HEAD -r --format='%(refname:short)' 2>/dev/null | grep -v '/HEAD$' | head -n1) && [ -n "$detached_ref" ] && detached_branch=${detached_ref#*/} && gh pr view "$detached_branch" --web 2>/dev/null; then
    echo "Opened PR for detached-HEAD branch: $detached_branch"
  else
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    if [ -n "$repo" ]; then
      open "https://github.com/$repo/pulls?q=sort%3Aupdated-desc+is%3Apr+is%3Aopen"
      echo "No PR for branch — opened $repo PRs list"
    else
      echo "Could not resolve repo (not a git repo or gh not authenticated)"
    fi
  fi
  sleep 1
}

act_browser_jira() {
  export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
  pane_path=$(focused_pane_path)
  branch=$(git -C "${pane_path:-$PWD}" branch --show-current 2>/dev/null) || branch=""
  if [ -z "$branch" ]; then
    echo "Not in a git repository"
  else
    key=$(printf '%s' "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -n1)
    if [ -n "$key" ]; then
      open "https://ihm-it.atlassian.net/browse/$key"
      echo "Opened ticket: $key"
    else
      echo "No Jira ticket key found in branch: $branch"
    fi
  fi
  sleep 1
}

act_browser_dotfiles() {
  open "https://github.com/gnohj/dotfiles"
  echo "Opened dotfiles repo"
  sleep 1
}

act_notes_current() {
  # Open the Obsidian vault note(s) for the ticket / unticketed worktree behind
  # the focused pane. Globs Notes/work/<id>-*.md and Notes-Inbox/<id>*.md (the
  # convention from /sb-ticket-capture and /sb-ingest-mine).
  pane_path=$(focused_pane_path)
  branch=$(git -C "${pane_path:-$PWD}" branch --show-current 2>/dev/null) || branch=""
  if [ -z "$branch" ]; then
    notify "not in a git repo"
    return
  fi
  if [[ "$branch" =~ ([A-Z]+-[0-9]+) ]]; then
    ID="${BASH_REMATCH[1]}"
  else
    ID=$(basename "${pane_path:-$PWD}")
  fi
  VAULT="$HOME/Obsidian/second-brain"
  MATCHES=$(
    {
      ls "$VAULT/Notes/work/${ID}-"*.md 2>/dev/null
      ls "$VAULT/Notes-Inbox/${ID}"*.md 2>/dev/null
    } | sort -u
  )
  COUNT=$(printf '%s' "$MATCHES" | grep -c .) || COUNT=0
  # open_window abstracts the multiplexer: a new tmux window in tmux mode, a new
  # herdr tab in herdr mode. (Avoids nested popups: the launcher may itself run in
  # a tmux popup, and display-popup-from-popup races the outer one's lifecycle.)
  case "$COUNT" in
  0) notify "no vault note for $ID" ;;
  1) open_window "📝" "nvim '$MATCHES'" "${pane_path:-$PWD}" ;;
  *)
    local rc=0
    PICK=$(printf '%s\n' "$MATCHES" | $HOME/.local/bin/fzf-vim.sh --prompt '📝 ') || rc=$?
    quit_on_interrupt "$rc"
    [ -n "$PICK" ] && open_window "📝" "nvim '$PICK'" "${pane_path:-$PWD}"
    ;;
  esac
}

act_fzf_aliases() { aliases_menu; }

act_fzf_env() {
  export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
  value=$(tv env)
  if [ -n "$value" ]; then
    printf '%s' "$value" | pbcopy
    echo "Copied to clipboard"
  fi
  sleep 1
}

act_fzf_logs() {
  export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
  log_file=$(tv --source-command "fd --type f . ~/.logs" --input-header "logs" --preview-command "bat -n --color=always --line-range=-500 {} 2>/dev/null || tail -500 {}")
  [ -n "$log_file" ] && exec nvim "$log_file"
}

act_sync_autopush() {
  ~/.config/zshrc/github-auto-push.sh --nowait
  echo "GitHub auto-push completed"
  sleep 1
}

act_system_setup() {
  if [ -f "$HOME/.local/share/chezmoi/system-setup.sh" ]; then
    cd "$HOME/.local/share/chezmoi" && ./system-setup.sh
  else
    echo "system-setup.sh not found"
    sleep 2
  fi
}

act_system_update() {
  echo "Updating nix flake inputs..."
  nix flake update --flake ~/.nix
  echo "Rebuilding system with updated packages..."
  sudo darwin-rebuild switch --flake ~/.nix#macbook_silicon
  echo "\nSystem update complete. Press any key to continue..."
  read -k1
}

act_system_usersetup() {
  if [ -f "$HOME/.local/share/chezmoi/user-setup.sh" ]; then
    cd "$HOME/.local/share/chezmoi" && ./user-setup.sh
  else
    echo "user-setup.sh not found"
    sleep 2
  fi
}

act_system_all() {
  # Pre-auth sudo once and refresh in the background so the flow never
  # re-prompts. ORDER MATTERS: darwin-rebuild runs LAST — its activation
  # reloads /etc/sudoers and invalidates the sudo cache, so any sudo step after
  # it would re-prompt. Each step is `|| echo`-guarded so one failure doesn't
  # abort the chain under `set -euo pipefail`.
  echo "Authenticating sudo (one prompt for the whole flow)..."
  if ! sudo -v; then
    echo "sudo authentication failed; aborting"
    sleep 2
    return
  fi
  (while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
  done) &
  SUDO_KEEPALIVE=$!
  trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' RETURN

  echo "\n▶ [1/3] System Setup..."
  if [ -f "$HOME/.local/share/chezmoi/system-setup.sh" ]; then
    (cd "$HOME/.local/share/chezmoi" && ./system-setup.sh) ||
      echo "(system-setup.sh exited non-zero — continuing)"
  else
    echo "system-setup.sh not found (skipping)"
  fi

  echo "\n▶ [2/3] User Setup..."
  if [ -f "$HOME/.local/share/chezmoi/user-setup.sh" ]; then
    (cd "$HOME/.local/share/chezmoi" && ./user-setup.sh) ||
      echo "(user-setup.sh exited non-zero — continuing)"
  else
    echo "user-setup.sh not found (skipping)"
  fi

  echo "\n▶ [3/3] System Update — nix flake update + darwin-rebuild..."
  nix flake update --flake ~/.nix ||
    echo "(nix flake update failed — continuing)"
  sudo darwin-rebuild switch --flake ~/.nix#macbook_silicon ||
    echo "(darwin-rebuild failed — continuing)"

  echo "\n▶ Reloading sketchybar..."
  /opt/homebrew/bin/sketchybar --reload 2>/dev/null ||
    sketchybar --reload 2>/dev/null ||
    echo "(sketchybar not running — skipped)"

  echo "\n✓ All complete. Press any key to continue..."
  read -k1
}

# Kick off an AI-worktree capture script, per host:
#   tmux mode  — hand off via `tmux run-shell -b`. The launcher runs inside a tmux
#     popup and the capture opens another popup; tmux can't nest popups, so the
#     server schedules it for after THIS popup closes.
#   herdr mode (ql) — run the capture inline in the quake (no tmux), signaling
#     worktree_setup.sh to open the result as a herdr workspace. WORKTREE_OPEN_IN
#     rides worktree-runner's env chain (open→Terminal, then claude→treekanga→
#     postScript), the same channel TREEKANGA_POSTSCRIPT_LOG uses. When the
#     capture returns, the persistent picker redraws root.
run_worktree_capture() {
  if [ "$LAUNCHER_MODE" = herdr ]; then
    WORKTREE_OPEN_IN=herdr "$1"
  else
    tmux run-shell -b "$1"
  fi
}

# treekanga-add.sh self-detects its host: tmux → new tmux window, herdr/quake →
# new herdr tab running `treekanga tui`. Runs in both modes.
act_worktree_add() { ~/.config/treekanga/treekanga-add.sh; }
act_worktree_ai_prompt() { run_worktree_capture "$HOME/.local/bin/worktree-prompt"; }
act_worktree_jira() {
  if [ "$LAUNCHER_MODE" = herdr ]; then
    WORKTREE_OPEN_IN=herdr ~/.local/bin/worktree-jira
  else
    ~/.local/bin/worktree-jira
  fi
}
act_worktree_clipboard() { run_worktree_capture "$HOME/.local/bin/worktree-clipboard"; }
act_worktree_bug() { run_worktree_capture "$HOME/.local/bin/worktree-bug"; }
act_worktree_retry() { run_worktree_capture "$HOME/.local/bin/worktree-retry"; }
# Removal runs in both hosts (treekanga-rm.sh's tmux session-kill is guarded). In
# herdr mode it won't auto-close the herdr workspace yet — minor follow-up.
act_worktree_delete() { ~/.config/treekanga/treekanga-rm.sh; }

act_outdated() {
  zsh -c "source ~/.config/zshrc/.zshrc && outdated && echo '\nPress any key to continue...' && read -k1"
}

act_cleanup_logs() {
  if [ -f "$HOME/.local/bin/cleanup-logs.sh" ]; then
    ~/.local/bin/cleanup-logs.sh
    echo "\nLogs cleaned up. Press any key to continue..."
    read -k1
  else
    echo "cleanup-logs.sh not found"
    sleep 2
  fi
}

act_copy_branch() {
  pane_path=$(focused_pane_path)
  branch=$(git -C "${pane_path:-$PWD}" branch --show-current 2>/dev/null) || branch=""
  if [ -n "$branch" ]; then
    printf '%s' "$branch" | pbcopy
    echo "Copied branch: $branch"
  else
    echo "Not in a git repository"
  fi
  sleep 1
}

# Copy the focused pane's full tmux address. The launcher runs in a popup, so a
# bare `display-message` resolves to the popup itself, not the pane you were on.
# Find the real focused pane first (active pane of the active window — popups are
# NOT in `list-panes`, so they're excluded), then read its address. window/pane
# are shown 1-based to match the status bar (tmux is 0-based internally); the raw
# #{pane_id} (%N) is the unambiguous target — Hunk review sessions match on it.
act_copy_pane_address() {
  require_tmux "Copy Pane Address" || return
  target=$(tmux list-panes -s -f '#{&&:#{window_active},#{pane_active}}' -F '#{pane_id}' 2>/dev/null | head -1) || target=""
  if [ -n "$target" ]; then
    addr=$(tmux display-message -t "$target" -p 'server=#{b:socket_path} · session=#{session_name} · window=#{e|+:#{window_index},1} · pane=#{e|+:#{pane_index},1} · id=#{pane_id}' 2>/dev/null)
  else
    addr=$(tmux display-message -p 'server=#{b:socket_path} · session=#{session_name} · window=#{e|+:#{window_index},1} · pane=#{e|+:#{pane_index},1} · id=#{pane_id}' 2>/dev/null)
  fi
  if [ -n "$addr" ]; then
    printf '%s' "$addr" | pbcopy
    echo "Copied pane address: $addr"
  else
    echo "No tmux pane context"
  fi
  sleep 1
}

act_dirty_repos() {
  # `;` not `&&` so the prompt fires even if `dirty` exits non-zero.
  zsh -c "source ~/.config/zshrc/.zshrc 2>/dev/null; dirty; echo; echo 'Press any key to continue...'; read -k1"
}

act_toggle_transparency() {
  ~/.config/tmux/toggle-terminal-transparency.sh
  echo "Transparency toggled"
  sleep 1
}

#===============================================================================
# Mode handlers — must come after all function definitions
#===============================================================================

if [[ "${1:-}" == "--preview" ]]; then
  do_preview "${2:-}"
  exit 0
fi

if [[ "${1:-}" == "--category" ]]; then
  get_cat "${2:-}" || { echo "Unknown category: ${2:-}"; exit 1; }
  # Direct category entry is a standalone popup (not a drilldown inside the
  # full-height main menu), so fill the popup instead of the 40% drilldown height
  # — otherwise the preview border only spans 40% and reads as "cut off".
  export LAUNCHER_SUBMENU_HEIGHT=100%
  if [ "$REC6" = generic ]; then
    generic_submenu "$REC1" "$REC3" "$REC4" "$REC5" "$REC7"
  else
    "$REC6"
  fi
  exit 0
fi

if [ "$LAUNCHER_MODE" = herdr ]; then
  # Persistent root-menu picker: every action returns here when it finishes, and
  # Esc / an aborted fzf just redraws root. The only way out is an explicit Ctrl+C
  # (SIGINT), which dismisses the quake on the way down. `|| true` keeps a
  # non-zero return (e.g. no fzf match) from tripping `set -e` and killing the loop.
  trap 'dismiss_quake; exit 0' INT
  while true; do
    main_menu || true
  done
else
  # tmux popup: single pass. The popup closes when the launcher exits, which the
  # worktree hand-off relies on (`tmux run-shell -b` fires after the popup closes).
  main_menu
fi
