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

# fzf re-forks --preview per cursor move, so each mode skips the startup work it never reads.
case "${1:-}" in
--preview) LAUNCHER_NEEDS=preview ;;
--mux-badge) LAUNCHER_NEEDS=badge ;;
*) LAUNCHER_NEEDS=full ;;
esac

FZF_COLORS=""

# Preview inherits MUX_LIVE (a socket probe per keystroke would kill the fast path); the badge must re-probe.
if [ "$LAUNCHER_NEEDS" = preview ]; then
  MUX_LIVE="${MUX_LIVE:-}"
else
  # shellcheck source=/dev/null
  [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ] &&
    source "$HOME/.config/colorscheme/active/active-colorscheme.sh" || true

  # mux_kind() — one definition of "which mux is live", shared with the mux dispatcher.
  # shellcheck source=/dev/null
  . "$HOME/.local/bin/mux/shared/mux-detect.sh"

  # Resolved once here: active_mux() call sites use $(...), so a memo inside would re-probe every time.
  MUX_LIVE=$(mux_kind)
  [ "$MUX_LIVE" = none ] && MUX_LIVE=""
  export MUX_LIVE
fi

if [ "$LAUNCHER_NEEDS" = full ]; then
  # fzf colors using current colorscheme (matches FZF_DEFAULT_OPTS from zshrc)
  FZF_COLORS="--color=bg+:$gnohj_color13,border:$gnohj_color03,fg:$gnohj_color04,fg+:$gnohj_color04,hl+:$gnohj_color04,info:$gnohj_color09,prompt:$gnohj_color04,pointer:$gnohj_color04,marker:$gnohj_color04,header:$gnohj_color09"
fi

# Machine identity from the central resolver, so the os gate and the Mac-relay badge share one source of truth. role: mac->darwin, devbox->linux+mac-relay, linux->plain.
# Exported so the per-keystroke re-forks inherit it instead of re-running machine-identity.
LAUNCHER_ROLE="${LAUNCHER_ROLE:-$("$HOME/.local/bin/machine-identity" role 2>/dev/null || echo mac)}"
LAUNCHER_HOST="${LAUNCHER_HOST:-$(hostname -s 2>/dev/null || echo '?')}"
export LAUNCHER_ROLE LAUNCHER_HOST
case "$LAUNCHER_ROLE" in mac) LAUNCHER_OS=darwin ;; *) LAUNCHER_OS=linux ;; esac
[ "$LAUNCHER_ROLE" = devbox ] && LAUNCHER_IS_DEVBOX=1 || LAUNCHER_IS_DEVBOX=""

#===============================================================================
# Registry — the only thing you edit to add/rename entries
#===============================================================================

# id|prefix|pointer|header|prompt|leaf_provider|submenu_fn|leaf_handler|scope|os|mux
#   leaf_provider  static (leaves from ACTIONS) | fn emitting labels at runtime
#   submenu_fn     generic | custom fn (themes drilldown, aerospace header)
#   leaf_handler   static (label→ACTIONS fn)    | fn called as `fn "<label>"`
#   scope          omitted = local | mac. `mac` = reaches back to your Mac (clipboard/
#                  browser/notify); 󰛳 shows only on the devbox (a Mac relay is set). A
#                  category's scope is inherited by its leaves unless a leaf overrides.
#   os             omitted = all | darwin | linux. Entry only shows on the matching
#                  OS (filtered at every derivation path, so it can't be dispatched
#                  off-OS either). scope is field 9; os is field 10 — set an empty
#                  scope (||) when an entry needs os but not mac.
#   mux            omitted = all | tmux | herdr. Field 11, same treatment as os but
#                  against the LIVE mux — set empty scope+os (|||) to reach it.
CATEGORIES=(
  "AI|🤖 AI|🤖 AI ›|AI|AI > |static|generic|static"
  "AERO|🖥  Aerospace|🖥  Aerospace Profiles ›|Aerospace|Profile > |provide_aerospace|aerospace_menu|handle_aerospace||darwin"
  "OPEN|🔗 Open|🔗 Open ›|Open|Open > |static|generic|static"
  "BROWSER|🌐 Browser|🌐 Browser ›|Browser|Browser > |static|generic|static"
  "FZF|🔎 Fzf|🔎 Fzf ›|Fzf|Fzf > |static|generic|static"
  "SYNC|🔁 Sync|🔁 Sync ›|Sync|Sync > |static|generic|static"
  "SYSTEM|🔧 System|🔧 System ›|System|System > |static|generic|static"
  "THEMES|🎨 Themes|🎨 Themes ›|Themes|Theme > |provide_themes|themes_menu|handle_theme"
  "WORKTREES|🌳 Worktrees|🌳 Worktrees ›|Worktrees|Worktree > |static|generic|static"
)

# Static leaves — prefix|label|function|description|scope|os|mux (all optional; scope
# omitted inherits the category; set empty leading fields to reach a later one)
ACTIONS=(
  "🤖 AI|🔥 Codeburn (cost)|act_ai_codeburn|Show today's AI spending via codeburn report"
  "🤖 AI|📊 RTK Savings (graph)|act_ai_rtk|Graph RTK token savings with rtk gain"
  "🤖 AI|👤 Claude Desktop (personal)|act_ai_claude_personal|Launch the Claude Desktop app signed into personal||darwin"
  "🤖 AI|💼 Claude Desktop (work)|act_ai_claude_work|Launch the Claude Desktop app signed into work||darwin"

  "🔗 Open|🔗 Open PR|act_browser_pr|Open the GitHub PR for the current branch in browser|mac"
  "🔗 Open|📂 Open Note|act_notes_current|Open the Obsidian vault note for this ticket in nvim"
  "🔗 Open|🎫 Open Jira|act_browser_jira|Open the Jira ticket for the current branch in browser|mac"

  "🌐 Browser|🐙 Open Dotfiles|act_browser_dotfiles|Open the dotfiles repo on GitHub|mac"

  "🔎 Fzf|🔎 Aliases (fza)|act_fzf_aliases|Browse and copy alias names via fzf|mac"
  "🔎 Fzf|🔍 Env Vars (fze)|act_fzf_env|Browse and copy env var values via television|mac"
  "🔎 Fzf|📋 Logs (fzl)|act_fzf_logs|Open a log file in nvim via television"

  "🔁 Sync|🚀 Autopush Repos|act_sync_autopush|Run github-auto-push on all tracked repos"
  "🔁 Sync|🔄 Update Repos|act_sync_update|Pull config repos: chezmoi update + agents + tmux-dash||darwin"

  "🔧 System|🚀 Full Update (up)|act_system_up|Cross-platform full update - macOS: nix+darwin+brew; Linux: apt+nix/home-manager+mise; then chezmoi + tpm"
  "🔧 System|🎯 All (provision: setup + user-setup + rebuild)|act_system_all|Fresh-machine provision: mac-setup.sh + user-setup.sh + nix rebuild, one sudo prompt||darwin"

  "🌳 Worktrees|🌳 Add Worktree|act_worktree_add|Create a new git worktree interactively"
  "🌳 Worktrees|✨ AI Add Worktree (prompt → worktree)|act_worktree_ai_prompt|Type free-text; Claude infers the ticket and creates the worktree"
  "🌳 Worktrees|🎫 AI Add Worktree (Chrome tab (jira) → worktree)|act_worktree_jira|Capture the active Chrome Jira tab and create a worktree||darwin"
  "🌳 Worktrees|📋 AI Add Worktree (clipboard → worktree)|act_worktree_clipboard|Use clipboard content (text or image) to create a worktree||darwin"
  "🌳 Worktrees|🐛 AI Add Worktree (clipboard → Jira bug → worktree)|act_worktree_bug|Classify clipboard as a bug, file Jira ticket, create worktree||darwin"
  "🌳 Worktrees|🔁 AI Retry capture → worktree|act_worktree_retry|Retry the most-recent worktree capture with refined context"
  "🌳 Worktrees|🗑  Delete Worktree|act_worktree_delete|Interactively select and delete a git worktree"
)

# Top-level actions with no submenu — label|function|description|scope|os|mux (all three optional)
SIMPLE_ACTIONS=(
  "📦 Check Outdated Packages|act_outdated|Check outdated Homebrew (mac) + mise packages; nix refreshes via 'up' (flake.lock), not per-package"
  "🧹 Cleanup Logs|act_cleanup_logs|Delete old log files from ~/.logs (this machine only)"
  "🌿 Copy Current Branch|act_copy_branch|Copy the current git branch name to clipboard|mac"
  "📋 Copy Pane Address|act_copy_pane_address|Copy the focused pane's address — server · session · window · pane (1-based) · pane-id — to clipboard|mac||tmux"
  "🧼 Dirty Repos|act_dirty_repos|List all repos with uncommitted changes"
  "🩺 Errors & Orphans|act_errors|Service-log errors + orphaned processes with kill commands"
  "📈 Usage Report (cpu/mem)|act_usage_report|CPU/mem/swap trend for the dev-box-sizing decision (macOS: usage-report + spike culprits; Linux: sar/atop export)"
  "🔀 GitHub PRs|act_ghpr|ghpr summary: my open PRs, review-requested, and involved (bots filtered)"
  "👻 Toggle Transparency|act_toggle_transparency|Toggle terminal background transparency|mac"
  "🔃 Restart Launcher|act_restart_launcher|Reload the launcher itself so edits to launcher.sh take effect, without restarting the quake"
)

# Exact NORMAL-mode order — cat:<ID> (renders pointer) or simple:<label>.
TOP_LEVEL_ORDER=(
  "cat:AI" "cat:AERO" "cat:OPEN" "cat:BROWSER"
  "simple:📦 Check Outdated Packages" "simple:🧹 Cleanup Logs" "simple:🌿 Copy Current Branch"
  "simple:🔀 GitHub PRs" "simple:📋 Copy Pane Address"
  "simple:🧼 Dirty Repos" "simple:🩺 Errors & Orphans" "simple:📈 Usage Report (cpu/mem)"
  "cat:FZF" "cat:SYNC" "cat:SYSTEM" "cat:THEMES"
  "simple:👻 Toggle Transparency" "cat:WORKTREES" "simple:🔃 Restart Launcher"
)

# Preview command: call this script in --preview mode with the selected line.
PREVIEW_CMD="\"$SELF\" --preview {}"

#===============================================================================
# Engine — derives all three views from the registry
#===============================================================================

# Populate REC0..REC10 with a category's fields by id; 1 if unknown.
get_cat() {
  local rec
  for rec in "${CATEGORIES[@]}"; do
    case "$rec" in
    "$1|"*)
      IFS='|' read -r REC0 REC1 REC2 REC3 REC4 REC5 REC6 REC7 REC8 REC9 REC10 <<<"$rec"
      return 0
      ;;
    esac
  done
  return 1
}

#===============================================================================
# Mac-relay badge + OS gate — a `mac`-scoped entry reaches back to your Mac (clipboard/browser/notify); the 󰛳 renders only on the devbox (LAUNCHER_IS_DEVBOX), never on the Mac where those are already local. os hides entries off their OS.
# The badge rides after a TAB sentinel so it never collides with a label; strip_scope() removes it before any dispatch match.
#===============================================================================
SCOPE_GLYPH="󰛳"

strip_scope() { printf '%s' "${1%%$'\t'*}"; }

# OS gate: 0 (show) when the os field is empty/all or matches the current OS.
os_match() { case "${1:-}" in "" | all | "$LAUNCHER_OS") return 0 ;; *) return 1 ;; esac; }

# Mux filter: 0 (show) when the field is empty/all or names the live mux (none running = hidden).
mux_match() { case "${1:-}" in "" | all | "$MUX_LIVE") return 0 ;; *) return 1 ;; esac; }

# One scan setting scope+os+mux, so the render path forks no subshell per field.
SIMPLE_SCOPE="" SIMPLE_OS="" SIMPLE_MUX=""
simple_fields() { # label
  local rec lbl fn desc scope os mux
  SIMPLE_SCOPE="" SIMPLE_OS="" SIMPLE_MUX=""
  for rec in "${SIMPLE_ACTIONS[@]}"; do
    IFS='|' read -r lbl fn desc scope os mux <<<"$rec"
    [ "$lbl" = "$1" ] && { SIMPLE_SCOPE="$scope" SIMPLE_OS="$os" SIMPLE_MUX="$mux"; return; }
  done
}

# Category scope by prefix (field 2 of CATEGORIES). Echoes "mac" or "local".
cat_scope_by_prefix() {
  local rec id prefix pointer header prompt provider submenu handler scope os
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler scope os <<<"$rec"
    [ "$prefix" = "$1" ] && { printf '%s' "${scope:-local}"; return; }
  done
  printf 'local'
}

# Is a static leaf mac-scoped AND are we on the devbox? Explicit ACTION scope wins, else inherit the category. Off the devbox nothing is badged.
leaf_is_mac() { # prefix label
  [ -n "$LAUNCHER_IS_DEVBOX" ] || return 1
  local rec p l f desc scope os
  for rec in "${ACTIONS[@]}"; do
    IFS='|' read -r p l f desc scope os <<<"$rec"
    if [ "$p" = "$1" ] && [ "$l" = "$2" ]; then
      [ -n "$scope" ] && { [ "$scope" = mac ]; return; }
      break
    fi
  done
  [ "$(cat_scope_by_prefix "$1")" = mac ]
}

# Is a simple action mac-scoped AND are we on the devbox? Reads what simple_fields resolved.
simple_is_mac() { # label (simple_fields must have run for it)
  [ -n "$LAUNCHER_IS_DEVBOX" ] || return 1
  [ "$SIMPLE_SCOPE" = mac ]
}

# Emit leaf labels (no prefix). $1=prefix $2=leaf_provider.
leaves_of() {
  if [ "$2" = static ]; then
    local rec p l f desc scope os mux
    for rec in "${ACTIONS[@]}"; do
      IFS='|' read -r p l f desc scope os mux <<<"$rec"
      [ "$p" = "$1" ] && os_match "$os" && mux_match "$mux" && printf '%s\n' "$l"
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

# Glob + expansion, not find|xargs|basename: these feed the INSERT corpus on every render.
provide_themes() {
  local f
  shopt -s nullglob
  for f in "$HOME"/.config/colorscheme/list/*.sh; do
    [ -f "$f" ] && printf '%s\n' "${f##*/}"
  done
  shopt -u nullglob
}

provide_aerospace() {
  local f base
  shopt -s nullglob
  for f in "$HOME"/.config/aerospace/profiles/*.toml; do
    base="${f##*/}"
    printf '%s\n' "${base%.toml}"
  done
  shopt -u nullglob
}

handle_theme() { "$HOME/.config/zshrc/colorscheme-set.sh" "$1"; }
handle_aerospace() {
  "$HOME/.local/bin/aerospace-profile" "$1"
  sleep 1
}

# NORMAL mode: clean pointer list interleaved with standalone simple actions.
build_top_level_items() {
  local tok lbl
  for tok in "${TOP_LEVEL_ORDER[@]}"; do
    case "$tok" in
    cat:*)
      get_cat "${tok#cat:}" || continue
      os_match "${REC9:-}" || continue
      mux_match "${REC10:-}" || continue
      if [ "${REC8:-local}" = mac ] && [ -n "$LAUNCHER_IS_DEVBOX" ]; then printf '%s\t%s\n' "$REC2" "$SCOPE_GLYPH"; else printf '%s\n' "$REC2"; fi
      ;;
    simple:*)
      lbl="${tok#simple:}"
      simple_fields "$lbl"
      os_match "$SIMPLE_OS" || continue
      mux_match "$SIMPLE_MUX" || continue
      if simple_is_mac "$lbl"; then printf '%s\t%s\n' "$lbl" "$SCOPE_GLYPH"; else printf '%s\n' "$lbl"; fi
      ;;
    esac
  done
}

# INSERT mode: breadcrumb-prefixed leaves so fuzzy-typing any partial name
# ("tokyo", "laptop", "open pr") resolves in one shot.
build_flattened_leaves() {
  local rec id prefix pointer header prompt provider submenu handler scope os mux leaf
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler scope os mux <<<"$rec"
    os_match "$os" || continue
    mux_match "$mux" || continue
    while IFS= read -r leaf; do
      [ -n "$leaf" ] || continue
      if leaf_is_mac "$prefix" "$leaf"; then
        printf '%s › %s\t%s\n' "$prefix" "$leaf" "$SCOPE_GLYPH"
      else
        printf '%s › %s\n' "$prefix" "$leaf"
      fi
    done < <(leaves_of "$prefix" "$provider")
  done
}

# Emit preview content for a selected line. Called via --preview mode.
do_preview() {
  local line
  line="$(strip_scope "$1")"

  # Category pointer (e.g. "🌳 Worktrees ›") — list its leaves.
  local rec id prefix pointer header prompt provider submenu handler scope
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler scope <<<"$rec"
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
    IFS='|' read -r p l f desc scope <<<"$rec"
    if [ "$line" = "$p › $l" ] || [ "$line" = "$l" ]; then
      printf '%s\n' "$desc"
      return 0
    fi
  done

  # Simple action.
  local lbl fn
  for rec in "${SIMPLE_ACTIONS[@]}"; do
    IFS='|' read -r lbl fn desc scope <<<"$rec"
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
  local choice leaf rc=0
  choice=$(
    {
      while IFS= read -r leaf; do
        [ -n "$leaf" ] || continue
        if leaf_is_mac "$1" "$leaf"; then printf '%s\t%s\n' "$leaf" "$SCOPE_GLYPH"; else printf '%s\n' "$leaf"; fi
      done < <(leaves_of "$1" "$4")
      printf "← Back\n"
    } | ~/.local/bin/fzf-vim.sh --height="${LAUNCHER_SUBMENU_HEIGHT:-40%}" --header="$2" --prompt="$3" --ansi $FZF_COLORS \
      --preview "$PREVIEW_CMD" --preview-window 'right:50%:wrap:border-left'
  ) || rc=$?
  quit_on_interrupt "$rc"
  printf '\033[2J\033[H'
  choice="$(strip_scope "$choice")"
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
  # Badge rendered in-process (a subshell, not a re-exec); HEADER_CMD still feeds the poster.
  choice=$(build_top_level_items |
    FZF_VIM_INSERT_INPUT="$insert_corpus" FZF_VIM_HEADER_CMD="\"$SELF\" --mux-badge" \
      FZF_VIM_HEADER="$(mux_indicator)" \
      ~/.local/bin/fzf-vim.sh --height=100% --prompt="❯ " --ansi $FZF_COLORS \
      --preview "$PREVIEW_CMD" --preview-window 'right:50%:wrap:border-left') || rc=$?
  quit_on_interrupt "$rc"
  printf '\033[2J\033[H'
  # Empty = Esc / aborted fzf. Never an exit: in herdr mode the loop just redraws
  # root (only Ctrl+C quits); in tmux mode returning falls through to the end of
  # the script, closing the popup as before.
  [ -z "$choice" ] && return 0
  dispatch_root "$choice"
  return 0
}

dispatch_root() {
  local choice rec id prefix pointer header prompt provider submenu handler scope
  choice="$(strip_scope "$1")"
  for rec in "${CATEGORIES[@]}"; do
    IFS='|' read -r id prefix pointer header prompt provider submenu handler scope <<<"$rec"
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
    IFS='|' read -r lbl fn desc scope <<<"$s"
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
  local sel rc=0
  sel=$(
    {
      provide_themes | { [ -n "$1" ] && grep -i "$1" || cat; }
      printf "← Back\n"
    } | ~/.local/bin/fzf-vim.sh --height=40% --header="$2" --prompt="$3" --ansi $FZF_COLORS
  ) || rc=$?
  # fzf-vim.sh, not raw fzf: plain fzf returns 130 for BOTH Esc and Ctrl+C.
  quit_on_interrupt "$rc"
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
    echo -n "${selected%%=*}" | clip
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
  # session_attached for the same reason as active_mux: a detached session's active
  # pane would otherwise win and hand back a cwd you are not actually looking at.
  line=$(tmux list-panes -s -f '#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}' \
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

# Copy stdin to clipboard portably: pbcopy on macOS, else OSC52 (lands on the SSH client's clipboard); base64 newlines stripped, \a terminates.
clip() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  else
    printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')"
  fi
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

# Which multiplexer to open INTO — the live one, not whatever LAUNCHER_MODE assumes
# (the quake is LAUNCHER_MODE=herdr for its own UI, but you may be running tmux).
# Delegates to mux_kind() from mux/shared/mux-detect.sh, sourced at the top of this
# file, so the dispatcher and the launcher can't drift on the answer; mux_kind itself
# is NOT memoized, which is why the result is resolved once into MUX_LIVE at startup.
#
# Reads the MUX_LIVE resolved at startup; "" means nothing running (mux_kind's "none").
# The one case it can't disambiguate — two independent muxes in two visible terminals
# at once — would need a focus-tracker daemon; not built (you run one at a time).
active_mux() { [ -z "$MUX_LIVE" ] || printf '%s\n' "$MUX_LIVE"; }

# host@city for the badge, mirroring the tmux host cell (host_cell_fmt in
# generate-tmux-colors.sh): same host-city geoip helper, same "drop @city when it
# can't be resolved" rule. Reads the cache FILE rather than forking host-city,
# because fzf re-invokes --mux-badge on every focus event; a cold cache is warmed
# in the background and this render shows the bare hostname, exactly like tmux's
# backgrounded @host_city set.
mux_host_label() {
  local host city="" cache="${XDG_CACHE_HOME:-$HOME/.cache}/host-city"
  host="$LAUNCHER_HOST"
  # read <file, not $(cat file): a builtin beats a fork on every menu spawn.
  if [ -s "$cache" ]; then
    # `|| true`, NOT `|| city=""`: no trailing newline means read returns 1 having already assigned.
    read -r city <"$cache" 2>/dev/null || true
  else
    ( "$HOME/.local/bin/mux/shared/host-city" >/dev/null 2>&1 & ) 2>/dev/null || true
  fi
  printf '%s%s' "$host" "${city:+@$city}"
}

# hex (#rrggbb) → truecolor SGR, the same conversion ccusage-statusline-green.sh and
# the zshrc outdated helpers use. $2 non-empty makes it bold.
sgr() {
  local hex="${1#\#}"
  printf '\033[%s38;2;%d;%d;%dm' "${2:+1;}" "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

# Colored badge for the live multiplexer plus the box it's on — shown in the
# launcher header so you always know both where an "open window/tab" action will
# land and which machine you're aimed at (matters over ssh / herdr --remote).
# Palette-driven (the colorscheme is sourced at the top of this file): both muxes
# wear the purple and the LABEL names which one, so the eye goes to host@city in red
# — the thing that changes when you're aimed at another box. Hex fallbacks keep it
# readable if a scheme omits a var.
mux_indicator() {
  local mux badge off=$'\033[0m' dim host
  dim=$(sgr "${gnohj_color08:-#505e62}")
  host=$(sgr "${gnohj_color11:-#da858e}")
  mux=$(active_mux)
  case "$mux" in
    herdr | tmux) badge="$(sgr "${gnohj_color01:-#c0aed2}" 1)● ${mux}${off}" ;;
    *) badge="$(sgr "${gnohj_color08:-#505e62}" 1)● no mux${off}" ;;
  esac
  printf '%s %s·%s %s%s%s' "$badge" "$dim" "$off" "$host" "$(mux_host_label)" "$off"
}

# Open <cmd> in a fresh window/tab labeled <label>, optionally rooted at <dir>,
# in the LIVE multiplexer (see active_mux). tmux → new window in the server
# (works even from the standalone quake). herdr → new tab in the focused
# workspace, then run <cmd> in its root pane over the socket API.
# Owns the quake dismissal: neither mux raises its window on an API-created tab.
open_window() {
  local label="$1" cmd="$2" dir="${3:-}" pane
  case "$(active_mux)" in
    herdr)
      pane=$(herdr tab create --label "$label" ${dir:+--cwd "$dir"} --focus 2>/dev/null |
        jq -r '.result.root_pane.pane_id // empty') || pane=""
      if [ -n "$pane" ]; then
        herdr pane run "$pane" "$cmd"
      else
        notify "herdr: could not open tab"
        return 1
      fi
      ;;
    tmux)
      tmux new-window -n "$label" ${dir:+-c "$dir"} "$cmd" 2>/dev/null ||
        { notify "tmux: could not open window"; return 1; }
      ;;
    *)
      notify "no herdr or tmux server to open into"
      return 1
      ;;
  esac
  dismiss_quake
}

# Open a NAMED command window. tmux mode delegates to tmux-window-simple.sh (which
# reuses a window by emoji and keeps the shell alive after the command); herdr
# mode opens a herdr tab running the command.
# keepopen is tmux-only: herdr types into a live shell that returns to its prompt anyway.
open_named_window() {
  local emoji="$1" name="$2" cmd="$3" keepopen="${4:-}" run
  if [ "$(active_mux)" = herdr ]; then
    run="$cmd"
    open_window "$emoji" "$run"
  else
    ~/.local/bin/mux/tmux/tmux-window-simple.sh "$emoji" "$name" "$cmd" $keepopen &&
      dismiss_quake
  fi
}

# Hide the quake after a hand-off: kitty socket, then its tty escape channel (survives the
# remote quake's ssh hop), then a frontmost-guarded Escape. ALWAYS returns 0 (set -e).
dismiss_quake() {
  [ "$LAUNCHER_MODE" = herdr ] || return 0
  # No --no-response: saves nothing measured, and the response is what lets a failure fall through.
  if [ -n "${KITTY_LISTEN_ON:-}" ] && command -v kitten >/dev/null 2>&1 &&
    kitten @ --to "$KITTY_LISTEN_ON" action hide_macos_app >/dev/null 2>&1; then
    return 0
  fi
  # Emit kitty's tty escape protocol ourselves rather than shelling out to `kitten`: the
  # remote quake's launcher runs on the dev box, which has no kitty installed at all.
  case "${TERM:-}" in
  xterm-kitty)
    printf '\033P@kitty-cmd{"cmd":"action","version":[0,26,0],"no_response":true,"payload":{"action":"hide_macos_app"}}\033\\' >/dev/tty 2>/dev/null && return 0
    ;;
  esac
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'tell application "System Events"
      set fg to name of first application process whose frontmost is true
      if fg is "kitty" then key code 53
    end tell' >/dev/null 2>&1 || true
  fi
  return 0
}

# No dismiss_quake: hide_on_focus_loss covers it, and racing it lands Escape in the browser.
open_url() { to-desktop open "$1"; }

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
  # Allow whenever tmux is the LIVE mux (even from the quake); block otherwise.
  [ "$(active_mux)" != tmux ] && { notify "'$1' needs tmux (not the live mux)"; return 1; }
  return 0
}

# Bare name, not the mise shim: both hosts use a login shell with mise on PATH (~0.8s cheaper).
act_ai_codeburn() { open_named_window 🔥 codeburn "codeburn report --period today" true; }
act_ai_rtk() { open_named_window 📊 rtk "rtk gain --graph"; }
# No dismiss_quake: the app takes focus and hide_on_focus_loss covers it — see open_url.
act_ai_claude_personal() { "$HOME/.local/bin/claude-desktop" personal; }
act_ai_claude_work() { "$HOME/.local/bin/claude-desktop" work; }

act_browser_pr() {
  export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
  pane_path=$(focused_pane_path)
  cd "${pane_path:-$PWD}" 2>/dev/null || true
  # Resolve the URL here, open it via to-desktop: --web would launch a browser on whichever box this runs on.
  if pr_url=$(gh pr view --json url -q .url 2>/dev/null) && [ -n "$pr_url" ]; then
    open_url "$pr_url"
    echo "Opened PR for current branch"
  elif [ -z "$(git symbolic-ref -q --short HEAD 2>/dev/null)" ] && detached_ref=$(git branch --points-at HEAD -r --format='%(refname:short)' 2>/dev/null | grep -v '/HEAD$' | head -n1) && [ -n "$detached_ref" ] && detached_branch=${detached_ref#*/} && pr_url=$(gh pr view "$detached_branch" --json url -q .url 2>/dev/null) && [ -n "$pr_url" ]; then
    open_url "$pr_url"
    echo "Opened PR for detached-HEAD branch: $detached_branch"
  else
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    if [ -n "$repo" ]; then
      open_url "https://github.com/$repo/pulls?q=sort%3Aupdated-desc+is%3Apr+is%3Aopen"
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
      open_url "https://ihm-it.atlassian.net/browse/$key"
      echo "Opened ticket: $key"
    else
      echo "No Jira ticket key found in branch: $branch"
    fi
  fi
  sleep 1
}

act_browser_dotfiles() {
  open_url "https://github.com/gnohj/dotfiles"
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
  VAULT="$("$HOME/.local/bin/vault-path" "${pane_path:-$PWD}")"
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
    printf '%s' "$value" | clip
    echo "Copied to clipboard"
  fi
  sleep 1
}

act_fzf_logs() {
  export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
  log_file=$(tv --source-command "fd --type f . ~/.logs" --input-header "logs" --preview-command "bat -n --color=always --line-range=-500 {} 2>/dev/null || tail -500 {}")
  [ -n "$log_file" ] || return 0
  # Quake mode hands off: `exec` would replace the persistent launcher loop with nvim.
  if [ "$LAUNCHER_MODE" = herdr ]; then
    open_window "📋" "nvim '$log_file'"
  else
    exec nvim "$log_file"
  fi
}

act_sync_autopush() {
  ~/.config/zshrc/github-auto-push.sh --nowait
  echo "GitHub auto-push completed"
  sleep 1
}

# Reuses the zshrc `update` function (chezmoi update + pull agents/tmux-dash); mirrors the act_dirty_repos wrapper.
act_sync_update() {
  zsh -c "source ~/.config/zshrc/.zshrc 2>/dev/null; update; echo; echo 'Press any key to continue...'; read -k1"
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
  if [ -f "$HOME/.local/share/chezmoi/mac-setup.sh" ]; then
    (cd "$HOME/.local/share/chezmoi" && ./mac-setup.sh) ||
      echo "(mac-setup.sh exited non-zero — continuing)"
  else
    echo "mac-setup.sh not found (skipping)"
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

# Unified cross-platform update. Delegates to the `up` function in zshrc so macOS
# (nix+darwin+brew) and Linux (apt+nix/home-manager+mise) share one entry — runs in
# a zsh subshell so `up`'s zsh-only builtins (print -P) and the read pause behave.
act_system_up() {
  zsh -c "source ~/.config/zshrc/.zshrc 2>/dev/null; up; echo; echo 'Press any key to continue...'; read -k1"
}

# Kick off an AI-worktree capture script, per host:
#   tmux mode  — hand off via `tmux run-shell -b`. The launcher runs inside a tmux
#     popup and the capture opens another popup; tmux can't nest popups, so the
#     server schedules it for after THIS popup closes.
#   herdr mode (ql) — run the capture inline in the quake (no tmux), signaling
#     worktree_setup.sh to open the result as a herdr workspace. WORKTREE_OPEN_IN
#     rides the worktree runner's env chain (open→Terminal, then claude→treekanga→
#     postScript), the same channel TREEKANGA_POSTSCRIPT_LOG uses. When the
#     capture returns, the persistent picker redraws root.
# Dismissal waits for the capture to return: it prompts inside the quake.
run_worktree_capture() {
  local verb="$1"
  if [ "$(active_mux)" = herdr ]; then
    WORKTREE_OPEN_IN=herdr "$HOME/.local/bin/worktree/worktree" "$verb" && dismiss_quake
  else
    tmux run-shell -b "$HOME/.local/bin/worktree/worktree $verb"
  fi
}

# treekanga-add.sh self-detects its host: tmux → new tmux window, herdr/quake →
# new herdr tab running `treekanga tui`. Runs in both modes.
act_worktree_add() { ~/.config/treekanga/treekanga-add.sh && dismiss_quake; }
act_worktree_ai_prompt() { run_worktree_capture prompt; }
act_worktree_jira() {
  if [ "$(active_mux)" = herdr ]; then
    WORKTREE_OPEN_IN=herdr ~/.local/bin/worktree/worktree jira && dismiss_quake
  else
    ~/.local/bin/worktree/worktree jira
  fi
}
act_worktree_clipboard() { run_worktree_capture clipboard; }
act_worktree_bug() { run_worktree_capture bug; }
act_worktree_retry() { run_worktree_capture retry; }
# treekanga-rm.sh sweeps both tmux sessions and herdr workspaces in the worktree.
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
    printf '%s' "$branch" | clip
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
    printf '%s' "$addr" | clip
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

# errors is a self-contained bin script — no zshrc source needed; `;` so the pause
# fires regardless of exit code.
act_errors() {
  zsh -c "$HOME/.local/bin/errors; echo; echo 'Press any key to continue...'; read -k1"
}

# Per-OS usage reader: macOS → usage-report.sh + spike culprits; Linux → vps-usage-export.sh (sar/atop). `;` so the pause fires regardless of exit.
act_usage_report() {
  if [ "$LAUNCHER_OS" = linux ]; then
    zsh -c "$HOME/.local/bin/vps-usage-export.sh; echo; echo 'Press any key to continue...'; read -k1"
  else
    zsh -c "$HOME/.local/bin/usage-report.sh; echo; echo '── load-spike culprits ──'; $HOME/.local/bin/usage-report.sh --burst 10; echo; echo 'Press any key to continue...'; read -k1"
  fi
}

# ghpr is a zshrc function, so source zshrc (in a zsh subshell, matching dirty).
act_ghpr() {
  zsh -c "source ~/.config/zshrc/.zshrc 2>/dev/null; ghpr; echo; echo 'Press any key to continue...'; read -k1"
}

# exec, so a source edit takes effect: the quake holds its parsed functions otherwise.
act_restart_launcher() { exec env LAUNCHER_MODE="$LAUNCHER_MODE" "$SELF"; }

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

# Live mux badge for the header — re-invoked by fzf (start/focus) so the state is
# polled fresh on every interaction, never cached from launch (matters for the
# persistent quake, which doesn't respawn).
if [[ "${1:-}" == "--mux-badge" ]]; then
  mux_indicator
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
