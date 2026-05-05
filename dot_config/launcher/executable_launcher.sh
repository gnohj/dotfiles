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
#-------------------------------------------------------------------------------
main_menu() {
  local choice
  choice=$(printf "🤖 Agent Sidebar Dashboard\n🔎 Aliases (fza)\n🌐 Browser ›\n📦 Check Outdated Packages\n🧹 Cleanup Logs\n🔥 Codeburn (AI cost)\n🌿 Copy Current Branch\n🧼 Dirty Repos\n🔍 Environment Variables (fze)\n📋 Logs (fzl)\n🚀 Sync Autopush Repos\n🔄 Sync Agent Dashboard\n🔧 Run System Setup\n⬆️ Run System Update\n👤 Run User Setup\n🎨 Themes ›\n👻 Toggle Transparency\n🌳 Worktrees ›\n" |
    ~/Scripts/fzf-vim.sh --height=100% \
      --prompt="❯ " \
      --ansi \
      $FZF_COLORS)

  # Clear residual fzf output before running action
  clear

  case "$choice" in
  "🎨 Themes ›") themes_menu ;;
  "🌐 Browser ›") browser_menu ;;
  "🌳 Worktrees ›") worktrees_menu ;;
  "🚀 Sync Autopush Repos")
    ~/.config/zshrc/github-auto-push.sh --nowait
    echo "GitHub auto-push completed"
    sleep 1
    ;;
  "🔄 Sync Agent Dashboard")
    python3 ~/Developer/agents/setup_symlinks.py
    printf '\nAgent sync complete. Press any key to continue...'
    read -n1
    ;;
  "🧼 Dirty Repos")
    # Use `;` instead of `&&` so the prompt fires even if `dirty` exits non-zero.
    # `read -k1` works because we're inside a zsh subshell.
    zsh -c "source ~/.config/zshrc/.zshrc 2>/dev/null; dirty; echo; echo 'Press any key to continue...'; read -k1"
    ;;
  "📦 Check Outdated Packages")
    zsh -c "source ~/.config/zshrc/.zshrc && outdated && echo '\nPress any key to continue...' && read -k1"
    ;;
  "🧹 Cleanup Logs")
    if [ -f "$HOME/Scripts/cleanup-logs.sh" ]; then
      ~/Scripts/cleanup-logs.sh
      echo "\nLogs cleaned up. Press any key to continue..."
      read -k1
    else
      echo "cleanup-logs.sh not found"
      sleep 2
    fi
    ;;
  "🔧 Run System Setup")
    if [ -f "$HOME/.local/share/chezmoi/system-setup.sh" ]; then
      cd "$HOME/.local/share/chezmoi" && ./system-setup.sh
    else
      echo "system-setup.sh not found"
      sleep 2
    fi
    ;;
  "⬆️ Run System Update")
    echo "Updating nix flake inputs..."
    nix flake update --flake ~/.nix
    echo "Rebuilding system with updated packages..."
    sudo darwin-rebuild switch --flake ~/.nix#macbook_silicon
    echo "\nSystem update complete. Press any key to continue..."
    read -k1
    ;;
  "👤 Run User Setup")
    if [ -f "$HOME/.local/share/chezmoi/user-setup.sh" ]; then
      cd "$HOME/.local/share/chezmoi" && ./user-setup.sh
    else
      echo "user-setup.sh not found"
      sleep 2
    fi
    ;;
  "👻 Toggle Transparency")
    ~/.config/tmux/toggle-terminal-transparency.sh
    echo "Transparency toggled"
    sleep 1
    ;;
  "🤖 Agent Sidebar Dashboard")
    # Same toggle that rctrl+shift+d fires — summons the recon-backed
    # claude-agents sidebar on workspace T.
    ~/Scripts/agent-sidebar-dashboard.sh
    ;;
  "🔥 Codeburn (AI cost)")
    ~/.config/skhd/tmux-window-simple.sh 🔥 codeburn "~/.local/share/mise/shims/codeburn report --period today" true
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
  *"fze"*)
    export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    value=$(tv env)
    if [ -n "$value" ]; then
      printf '%s' "$value" | pbcopy
      echo "Copied to clipboard"
    fi
    sleep 1
    ;;
  *"fzl"*)
    export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    log_file=$(tv --source-command "fd --type f . ~/.logs" --input-header "logs" --preview-command "bat -n --color=always --line-range=-500 {} 2>/dev/null || tail -500 {}")
    [ -n "$log_file" ] && exec nvim "$log_file"
    ;;
  *"fza"*) aliases_menu ;;
  *) exit 0 ;;
  esac
}

#-------------------------------------------------------------------------------
# Themes Menu
#-------------------------------------------------------------------------------
themes_menu() {
  local choice
  choice=$(printf "🎨 All\n🌙 Dark\n☀️ Light\n← Back" |
    ~/Scripts/fzf-vim.sh --height=40% \
      --header="Themes" \
      --prompt="Theme > " \
      --ansi \
      $FZF_COLORS)

  case "$choice" in
  "🎨 All") all_themes_menu ;;
  "🌙 Dark") dark_themes_menu ;;
  "☀️ Light") light_themes_menu ;;
  "← Back") main_menu ;;
  *) exit 0 ;;
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
  )

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
  )

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
  )

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
# Browser Menu
#-------------------------------------------------------------------------------
browser_menu() {
  local choice
  choice=$(printf "🔗 Open Pull Request\n🎫 Open Jira Ticket\n← Back\n" |
    ~/Scripts/fzf-vim.sh --height=40% \
      --header="Browser" \
      --prompt="Browser > " \
      --ansi \
      $FZF_COLORS)

  clear

  case "$choice" in
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
  "← Back") main_menu ;;
  *) exit 0 ;;
  esac
}

#-------------------------------------------------------------------------------
# Worktrees Menu
#-------------------------------------------------------------------------------
worktrees_menu() {
  local choice
  choice=$(printf "🌳 Add Worktree\n✨ Add Worktree (describe)\n🎫 Add Worktree (from Chrome tab with Jira ticket)\n🗑  Delete Worktree\n← Back\n" |
    ~/Scripts/fzf-vim.sh --height=40% \
      --header="Worktrees" \
      --prompt="Worktree > " \
      --ansi \
      $FZF_COLORS)

  case "$choice" in
  "🌳 Add Worktree")
    ~/.config/treekanga/treekanga-add.sh
    ;;
  "✨ Add Worktree (describe)")
    # The launcher itself runs inside a tmux popup, and worktree-prompt
    # opens another tmux popup. tmux can't nest popups, so we hand off
    # to the tmux server via `run-shell -b` — the server schedules
    # worktree-prompt for *after* this popup closes, in a context that
    # has clean access to the user's attached client.
    tmux run-shell -b "$HOME/.local/bin/worktree-prompt"
    ;;
  "🎫 Add Worktree (from Chrome tab with Jira ticket)")
    # jira-worktree reads the active Chrome tab, so it doesn't need the
    # detach-and-delay trick — it doesn't open another tmux popup.
    ~/.local/bin/jira-worktree
    ;;
  "🗑  Delete Worktree")
    ~/.config/treekanga/treekanga-rm.sh
    ;;
  "← Back") main_menu ;;
  *) exit 0 ;;
  esac
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
      "$HOME/.zsh_radioctl_cmds" 2>/dev/null \
    | sed -E 's/^[[:space:]]*alias //' \
    | sort -u \
    | ~/Scripts/fzf-vim.sh \
        --height=80% \
        --header="Aliases (select to copy) - Type to search" \
        --prompt="Alias > " \
        $FZF_COLORS)

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
