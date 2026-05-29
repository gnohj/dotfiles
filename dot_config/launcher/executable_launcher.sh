#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154
#
# Omarchy-style hierarchical launcher using fzf
# Consolidates all scripts and utilities into one popup launcher

set -euo pipefail

# Source colorscheme for fzf colors
if [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ]; then
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
fi

# fzf colors using current colorscheme (matches FZF_DEFAULT_OPTS from zshrc)
FZF_COLORS="--color=bg+:$gnohj_color13,border:$gnohj_color03,fg:$gnohj_color02,fg+:$gnohj_color02,hl+:$gnohj_color04,info:$gnohj_color09,prompt:$gnohj_color04,pointer:$gnohj_color04,marker:$gnohj_color04,header:$gnohj_color09"

#-------------------------------------------------------------------------------
# Main Menu
#
# Top-level entries + breadcrumb-prefixed leaf entries from each
# submenu. Typing in fzf at the root searches across everything in one
# shot — "tokyo" matches the tokyo theme without needing
# Themes › Dark › tokyo. Submenu pointers (Themes ›, Worktrees ›, etc.)
# stay too so users who prefer drilldown still get it.
#
# Dispatch is by string prefix:
#   "🎨 Themes › <theme>"          → colorscheme-set <theme>
#   "🖥  Aerospace › <profile>"    → aerospace-profile <profile>
#   "🌐 Browser › ..."             → browser_menu's case (extracted)
#   "🌳 Worktrees › ..."           → worktrees_menu's case (extracted)
#   "🔧 System › ..."              → system_menu's case (extracted)
#   "🔁 Sync › ..."                → sync_menu's case (extracted)
#   "🔎 Fzf › ..."                 → fzf_menu's case (extracted)
#   "🤖 AI › ..."                  → ai_menu's case (extracted)
#-------------------------------------------------------------------------------
build_top_level_items() {
  # Top-level entries + submenu pointers. Shown in NORMAL mode (clean,
  # navigable list). The flattened breadcrumb leaves below are added only
  # in INSERT mode so fuzzy-typing "open pr" still resolves directly.
  printf "🤖 AI ›\n"
  printf "🖥  Aerospace Profiles ›\n"
  printf "🌐 Browser ›\n"
  printf "📦 Check Outdated Packages\n"
  printf "🧹 Cleanup Logs\n"
  printf "🌿 Copy Current Branch\n"
  printf "🧼 Dirty Repos\n"
  printf "🔎 Fzf ›\n"
  printf "🔁 Sync ›\n"
  printf "🔧 System ›\n"
  printf "🎨 Themes ›\n"
  printf "👻 Toggle Transparency\n"
  printf "🌳 Worktrees ›\n"
}

build_flattened_leaves() {
  # Breadcrumb-prefixed leaves — surfaced only in INSERT mode so typing
  # any partial name (e.g. "tokyo", "laptop", "open pr") matches in one
  # shot. Kept out of the NORMAL-mode list so the root view stays clean.

  # AI (1 action)
  printf "🤖 AI › 🔥 Codeburn (cost)\n"

  # Aerospace profiles (type "laptop" or "desk" to match)
  if [ -d "$HOME/.config/aerospace/profiles" ]; then
    for f in "$HOME/.config/aerospace/profiles"/*.toml; do
      [ -f "$f" ] || continue
      printf "🖥  Aerospace › %s\n" "$(basename "$f" .toml)"
    done
  fi

  # Browser (3 actions)
  printf "🌐 Browser › 🔗 Open Pull Request\n"
  printf "🌐 Browser › 🎫 Open Jira Ticket\n"
  printf "🌐 Browser › 🐙 Open Dotfiles\n"

  # fzf (3 actions)
  printf "🔎 Fzf › 🔎 Aliases (fza)\n"
  printf "🔎 Fzf › 🔍 Env Vars (fze)\n"
  printf "🔎 Fzf › 📋 Logs (fzl)\n"

  # Sync (2 actions)
  printf "🔁 Sync › 🚀 Autopush Repos\n"
  printf "🔁 Sync › 🔄 Agent Dashboard\n"

  # System (4 actions)
  printf "🔧 System › 🔧 System Setup\n"
  printf "🔧 System › ⬆️ System Update\n"
  printf "🔧 System › 👤 User Setup\n"
  printf "🔧 System › 🎯 All (update + setup + user-setup)\n"

  # Worktrees (mirror worktrees_menu's options)
  printf "🌳 Worktrees › 🌳 Add Worktree\n"
  printf "🌳 Worktrees › ✨ AI Add Worktree (prompt → worktree)\n"
  printf "🌳 Worktrees › 🎫 AI Add Worktree (Chrome tab (jira) → worktree)\n"
  printf "🌳 Worktrees › 📋 AI Add Worktree (clipboard → worktree)\n"
  printf "🌳 Worktrees › 🐛 AI Add Worktree (clipboard → Jira bug → worktree)\n"
  printf "🌳 Worktrees › 🔁 AI Retry capture → worktree\n"
  printf "🌳 Worktrees › 🗑  Delete Worktree\n"

  # Themes (all of them; type any partial name to fuzzy-match)
  if [ -d "$HOME/.config/colorscheme/list" ]; then
    find "$HOME/.config/colorscheme/list" -maxdepth 1 -name "*.sh" -type f -print0 \
      | xargs -0 -n 1 basename \
      | sort \
      | while IFS= read -r theme; do
          printf "🎨 Themes › %s\n" "$theme"
        done
  fi
}

main_menu() {
  local choice insert_corpus
  # Insert mode gets the full corpus (top-level + flattened leaves) so
  # fuzzy typing matches across everything. Normal mode (the default,
  # piped to stdin) shows only the clean top-level list.
  insert_corpus=$({ build_top_level_items; build_flattened_leaves; })
  choice=$(build_top_level_items |
    FZF_VIM_INSERT_INPUT="$insert_corpus" \
    ~/.local/bin/fzf-vim.sh --height=100% \
      --prompt="❯ " \
      --ansi \
      $FZF_COLORS) || true

  # Clear residual fzf output before running action
  clear

  # Flattened-entry dispatch (breadcrumb-prefixed leaves)
  case "$choice" in
    "🎨 Themes › "*)
      "$HOME/.config/zshrc/colorscheme-set.sh" "${choice#🎨 Themes › }"
      return
      ;;
    "🖥  Aerospace › "*)
      "$HOME/.local/bin/aerospace-profile" "${choice#🖥  Aerospace › }"
      sleep 1
      return
      ;;
    "🌐 Browser › "*)
      browser_dispatch "${choice#🌐 Browser › }"
      return
      ;;
    "🌳 Worktrees › "*)
      worktrees_dispatch "${choice#🌳 Worktrees › }"
      return
      ;;
    "🔧 System › "*)
      system_dispatch "${choice#🔧 System › }"
      return
      ;;
    "🔁 Sync › "*)
      sync_dispatch "${choice#🔁 Sync › }"
      return
      ;;
    "🔎 Fzf › "*)
      fzf_dispatch "${choice#🔎 Fzf › }"
      return
      ;;
    "🤖 AI › "*)
      ai_dispatch "${choice#🤖 AI › }"
      return
      ;;
  esac

  case "$choice" in
  "🎨 Themes ›") themes_menu ;;
  "🌐 Browser ›") browser_menu ;;
  "🌳 Worktrees ›") worktrees_menu ;;
  "🖥  Aerospace Profiles ›") aerospace_menu ;;
  "🔧 System ›") system_menu ;;
  "🔁 Sync ›") sync_menu ;;
  "🔎 Fzf ›") fzf_menu ;;
  "🤖 AI ›") ai_menu ;;
  "🧼 Dirty Repos")
    # Use `;` instead of `&&` so the prompt fires even if `dirty` exits non-zero.
    # `read -k1` works because we're inside a zsh subshell.
    zsh -c "source ~/.config/zshrc/.zshrc 2>/dev/null; dirty; echo; echo 'Press any key to continue...'; read -k1"
    ;;
  "📦 Check Outdated Packages")
    zsh -c "source ~/.config/zshrc/.zshrc && outdated && echo '\nPress any key to continue...' && read -k1"
    ;;
  "🧹 Cleanup Logs")
    if [ -f "$HOME/.local/bin/cleanup-logs.sh" ]; then
      ~/.local/bin/cleanup-logs.sh
      echo "\nLogs cleaned up. Press any key to continue..."
      read -k1
    else
      echo "cleanup-logs.sh not found"
      sleep 2
    fi
    ;;
  "👻 Toggle Transparency")
    ~/.config/tmux/toggle-terminal-transparency.sh
    echo "Transparency toggled"
    sleep 1
    ;;
  "🌿 Copy Current Branch")
    pane_path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    branch=$(git -C "${pane_path:-$PWD}" branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
      printf '%s' "$branch" | pbcopy
      echo "Copied branch: $branch"
    else
      echo "Not in a git repository"
    fi
    sleep 1
    ;;
  *) exit 0 ;;
  esac
}

#-------------------------------------------------------------------------------
# Themes Menu
#-------------------------------------------------------------------------------
themes_menu() {
  local choice
  choice=$(printf "🎨 All\n🌙 Dark\n☀️ Light\n← Back" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="Themes" \
      --prompt="Theme > " \
      --ansi \
      $FZF_COLORS) || true

  case "$choice" in
  "🎨 All") all_themes_menu ;;
  "🌙 Dark") dark_themes_menu ;;
  "☀️ Light") light_themes_menu ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

aerospace_menu() {
  local profiles_dir="$HOME/.config/aerospace/profiles"
  local active
  active="$(cat "$HOME/.config/aerospace/.active-profile" 2>/dev/null || echo '(none)')"

  local choice
  choice=$(
    {
      find "$profiles_dir" -maxdepth 1 -name '*.toml' -exec basename {} .toml \; 2>/dev/null | sort
      printf "← Back\n"
    } | ~/.local/bin/fzf-vim.sh --height=40% \
      --header="Aerospace profile (active: $active)" \
      --prompt="Profile > " \
      --ansi \
      $FZF_COLORS
  ) || true

  case "$choice" in
  "← Back") main_menu ;;
  "") main_menu ;;
  *)
    "$HOME/.local/bin/aerospace-profile" "$choice"
    sleep 1
    ;;
  esac
}

all_themes_menu() {
  local schemes_dir="$HOME/.config/colorscheme/list"
  local selected_scheme

  # Show all themes with back option at the end
  selected_scheme=$(
    {
      find "$schemes_dir" -name "*.sh" -type f -print0 | xargs -0 -n 1 basename
      printf "← Back\n"
    } | fzf --height=40% \
      --reverse \
      --header="All Themes" \
      --prompt="All > " \
      $FZF_COLORS
  ) || true

  case "$selected_scheme" in
  "← Back") themes_menu ;;
  "")
    # Empty selection, go back
    themes_menu
    ;;
  *)
    "$HOME/.config/zshrc/colorscheme-set.sh" "$selected_scheme"
    ;;
  esac
}

dark_themes_menu() {
  local schemes_dir="$HOME/.config/colorscheme/list"
  local selected_scheme

  # Filter dark themes - only show files with "dark" in the name
  selected_scheme=$(
    {
      find "$schemes_dir" -name "*.sh" -type f -print0 | xargs -0 -n 1 basename | grep -i "dark"
      printf "← Back\n"
    } | fzf --height=40% \
      --reverse \
      --header="Dark Themes" \
      --prompt="Dark > " \
      --no-info \
      $FZF_COLORS
  ) || true

  case "$selected_scheme" in
  "← Back") themes_menu ;;
  "")
    # Empty selection, go back
    themes_menu
    ;;
  *)
    "$HOME/.config/zshrc/colorscheme-set.sh" "$selected_scheme"
    ;;
  esac
}

light_themes_menu() {
  local schemes_dir="$HOME/.config/colorscheme/list"
  local selected_scheme

  # Filter light themes - only show files with "light" in the name
  selected_scheme=$(
    {
      find "$schemes_dir" -name "*.sh" -type f -print0 | xargs -0 -n 1 basename | grep -i "light"
      printf "← Back\n"
    } | fzf --height=40% \
      --reverse \
      --header="Light Themes" \
      --prompt="Light > " \
      --no-info \
      $FZF_COLORS
  ) || true

  case "$selected_scheme" in
  "← Back") themes_menu ;;
  "")
    # Empty selection, go back
    themes_menu
    ;;
  *)
    "$HOME/.config/zshrc/colorscheme-set.sh" "$selected_scheme"
    ;;
  esac
}

#-------------------------------------------------------------------------------
# Browser Menu — dispatcher accepts an optional preselected subchoice so
# the flattened root-menu entries (build_main_menu_items) can call the
# same actions without duplicating code.
#-------------------------------------------------------------------------------
browser_dispatch() {
  case "$1" in
  "🔗 Open Pull Request")
    export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    pane_path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    cd "${pane_path:-$PWD}" 2>/dev/null || true
    if gh pr view --web 2>/dev/null; then
      echo "Opened PR for current branch"
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
    ;;
  "🎫 Open Jira Ticket")
    export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    pane_path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    branch=$(git -C "${pane_path:-$PWD}" branch --show-current 2>/dev/null)
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
    ;;
  "🐙 Open Dotfiles")
    open "https://github.com/gnohj/dotfiles"
    echo "Opened dotfiles repo"
    sleep 1
    ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

browser_menu() {
  local choice
  choice=$(printf "🔗 Open Pull Request\n🎫 Open Jira Ticket\n🐙 Open Dotfiles\n← Back\n" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="Browser" \
      --prompt="Browser > " \
      --ansi \
      $FZF_COLORS) || true

  clear
  browser_dispatch "$choice"
}

#-------------------------------------------------------------------------------
# Worktrees Menu — dispatcher accepts a preselected subchoice (used by
# both the drilldown menu and the flattened root-menu entries).
#-------------------------------------------------------------------------------
worktrees_dispatch() {
  case "$1" in
  "🌳 Add Worktree")
    ~/.config/treekanga/treekanga-add.sh
    ;;
  "✨ AI Add Worktree (prompt → worktree)")
    # The launcher itself runs inside a tmux popup, and worktree-prompt
    # opens another tmux popup. tmux can't nest popups, so we hand off
    # to the tmux server via `run-shell -b` — the server schedules
    # worktree-prompt for *after* this popup closes, in a context that
    # has clean access to the user's attached client.
    tmux run-shell -b "$HOME/.local/bin/worktree-prompt"
    ;;
  "🎫 AI Add Worktree (Chrome tab (jira) → worktree)")
    ~/.local/bin/worktree-jira
    ;;
  "📋 AI Add Worktree (clipboard → worktree)")
    tmux run-shell -b "$HOME/.local/bin/worktree-clipboard"
    ;;
  "🐛 AI Add Worktree (clipboard → Jira bug → worktree)")
    tmux run-shell -b "$HOME/.local/bin/worktree-bug"
    ;;
  "🔁 AI Retry capture → worktree")
    tmux run-shell -b "$HOME/.local/bin/worktree-retry"
    ;;
  "🗑  Delete Worktree")
    ~/.config/treekanga/treekanga-rm.sh
    ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

worktrees_menu() {
  local choice
  choice=$(printf "🌳 Add Worktree\n✨ AI Add Worktree (prompt → worktree)\n🎫 AI Add Worktree (Chrome tab (jira) → worktree)\n📋 AI Add Worktree (clipboard → worktree)\n🐛 AI Add Worktree (clipboard → Jira bug → worktree)\n🔁 AI Retry capture → worktree\n🗑  Delete Worktree\n← Back\n" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="Worktrees" \
      --prompt="Worktree > " \
      --ansi \
      $FZF_COLORS) || true

  worktrees_dispatch "$choice"
}

#-------------------------------------------------------------------------------
# AI Menu — dispatcher accepts a preselected subchoice (used by both
# the drilldown menu and the flattened root-menu entries).
#-------------------------------------------------------------------------------
ai_dispatch() {
  case "$1" in
  "🔥 Codeburn (cost)")
    ~/.config/skhd/tmux-window-simple.sh 🔥 codeburn "~/.local/share/mise/shims/codeburn report --period today" true
    ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

ai_menu() {
  local choice
  choice=$(printf "🔥 Codeburn (cost)\n← Back\n" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="AI" \
      --prompt="AI > " \
      --ansi \
      $FZF_COLORS) || true

  ai_dispatch "$choice"
}

#-------------------------------------------------------------------------------
# Fzf Menu — dispatcher accepts a preselected subchoice (used by both
# the drilldown menu and the flattened root-menu entries).
#-------------------------------------------------------------------------------
fzf_dispatch() {
  case "$1" in
  "🔎 Aliases (fza)") aliases_menu ;;
  "🔍 Env Vars (fze)")
    export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    value=$(tv env)
    if [ -n "$value" ]; then
      printf '%s' "$value" | pbcopy
      echo "Copied to clipboard"
    fi
    sleep 1
    ;;
  "📋 Logs (fzl)")
    export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    log_file=$(tv --source-command "fd --type f . ~/.logs" --input-header "logs" --preview-command "bat -n --color=always --line-range=-500 {} 2>/dev/null || tail -500 {}")
    [ -n "$log_file" ] && exec nvim "$log_file"
    ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

fzf_menu() {
  local choice
  choice=$(printf "🔎 Aliases (fza)\n🔍 Env Vars (fze)\n📋 Logs (fzl)\n← Back\n" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="Fzf" \
      --prompt="Fzf > " \
      --ansi \
      $FZF_COLORS) || true

  fzf_dispatch "$choice"
}

#-------------------------------------------------------------------------------
# Sync Menu — dispatcher accepts a preselected subchoice (used by both
# the drilldown menu and the flattened root-menu entries).
#-------------------------------------------------------------------------------
sync_dispatch() {
  case "$1" in
  "🚀 Autopush Repos")
    ~/.config/zshrc/github-auto-push.sh --nowait
    echo "GitHub auto-push completed"
    sleep 1
    ;;
  "🔄 Agent Dashboard")
    python3 ~/Developer/agents/setup_symlinks.py
    printf '\nAgent sync complete. Press any key to continue...'
    read -n1
    ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

sync_menu() {
  local choice
  choice=$(printf "🚀 Autopush Repos\n🔄 Agent Dashboard\n← Back\n" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="Sync" \
      --prompt="Sync > " \
      --ansi \
      $FZF_COLORS) || true

  sync_dispatch "$choice"
}

#-------------------------------------------------------------------------------
# System Menu — dispatcher accepts a preselected subchoice (used by both
# the drilldown menu and the flattened root-menu entries).
#-------------------------------------------------------------------------------
system_dispatch() {
  case "$1" in
  "🔧 System Setup")
    if [ -f "$HOME/.local/share/chezmoi/system-setup.sh" ]; then
      cd "$HOME/.local/share/chezmoi" && ./system-setup.sh
    else
      echo "system-setup.sh not found"
      sleep 2
    fi
    ;;
  "⬆️ System Update")
    echo "Updating nix flake inputs..."
    nix flake update --flake ~/.nix
    echo "Rebuilding system with updated packages..."
    sudo darwin-rebuild switch --flake ~/.nix#macbook_silicon
    echo "\nSystem update complete. Press any key to continue..."
    read -k1
    ;;
  "👤 User Setup")
    if [ -f "$HOME/.local/share/chezmoi/user-setup.sh" ]; then
      cd "$HOME/.local/share/chezmoi" && ./user-setup.sh
    else
      echo "user-setup.sh not found"
      sleep 2
    fi
    ;;
  "🎯 All (update + setup + user-setup)")
    # Pre-authenticate sudo once and refresh in the background so the
    # whole flow never re-prompts mid-run.
    #
    # ORDER MATTERS: darwin-rebuild runs LAST because its activation
    # scripts reload /etc/sudoers and can invalidate the sudo credential
    # cache — any sudo step after it would re-prompt for password.
    # With it last, the cache stays valid through both setup phases.
    #
    # Each step is wrapped with `|| echo` so a non-zero exit reports the
    # failure but doesn't abort the chain (set -euo pipefail is on at
    # the script level — without the `||` neutralizer, the first failing
    # step would skip everything below it including the sketchybar reload).
    echo "Authenticating sudo (one prompt for the whole flow)..."
    if ! sudo -v; then
      echo "sudo authentication failed; aborting"
      sleep 2
      return
    fi
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE=$!
    trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' RETURN

    echo "\n▶ [1/3] System Setup..."
    if [ -f "$HOME/.local/share/chezmoi/system-setup.sh" ]; then
      ( cd "$HOME/.local/share/chezmoi" && ./system-setup.sh ) \
        || echo "(system-setup.sh exited non-zero — continuing)"
    else
      echo "system-setup.sh not found (skipping)"
    fi

    echo "\n▶ [2/3] User Setup..."
    if [ -f "$HOME/.local/share/chezmoi/user-setup.sh" ]; then
      ( cd "$HOME/.local/share/chezmoi" && ./user-setup.sh ) \
        || echo "(user-setup.sh exited non-zero — continuing)"
    else
      echo "user-setup.sh not found (skipping)"
    fi

    echo "\n▶ [3/3] System Update — nix flake update + darwin-rebuild..."
    nix flake update --flake ~/.nix \
      || echo "(nix flake update failed — continuing)"
    sudo darwin-rebuild switch --flake ~/.nix#macbook_silicon \
      || echo "(darwin-rebuild failed — continuing)"

    echo "\n▶ Reloading sketchybar..."
    /opt/homebrew/bin/sketchybar --reload 2>/dev/null \
      || sketchybar --reload 2>/dev/null \
      || echo "(sketchybar not running — skipped)"

    echo "\n✓ All complete. Press any key to continue..."
    read -k1
    ;;
  "← Back") main_menu ;;
  *) main_menu ;;
  esac
}

system_menu() {
  local choice
  choice=$(printf "🔧 System Setup\n⬆️ System Update\n👤 User Setup\n🎯 All (update + setup + user-setup)\n← Back\n" |
    ~/.local/bin/fzf-vim.sh --height=40% \
      --header="System" \
      --prompt="System > " \
      --ansi \
      $FZF_COLORS) || true

  system_dispatch "$choice"
}

#-------------------------------------------------------------------------------
# Aliases Menu (fza - copy to clipboard)
#-------------------------------------------------------------------------------
aliases_menu() {
  local selected
  # Grep alias declarations directly from rc files instead of sourcing zshrc
  # (zinit + plugins make a non-interactive `source` hang inside the popup).
  selected=$(grep -hE "^[[:space:]]*alias [A-Za-z0-9_.-]+=" \
    "$HOME/.config/zshrc/.zshrc" \
    "$HOME/.zsh_gnohj_env" \
    "$HOME/.zsh_aws_cmds" \
    "$HOME/.zsh_radioctl_cmds" 2>/dev/null |
    sed -E 's/^[[:space:]]*alias //' |
    sort -u |
    ~/.local/bin/fzf-vim.sh \
      --height=80% \
      --header="Aliases (select to copy) - Type to search" \
      --prompt="Alias > " \
      $FZF_COLORS) || true

  if [[ -n "$selected" ]]; then
    # Extract just the alias name (before the '=')
    local alias_name="${selected%%=*}"
    # Copy to clipboard
    echo -n "$alias_name" | pbcopy
    echo "Copied to clipboard: $alias_name"
    sleep 1
  fi
}

#-------------------------------------------------------------------------------
# Entry Point
#-------------------------------------------------------------------------------
main_menu
