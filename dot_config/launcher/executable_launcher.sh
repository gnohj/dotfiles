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
  choice=$(printf "🎨 Themes\n🔀 PRs Requesting Review\n🚀 Push to GitHub (now)\n🔔 Test GitHub Notification\n📦 Check Outdated Packages\n🧹 Cleanup Logs\n🔧 Run System Setup\n👤 Run User Setup\n👻 Toggle Transparency\n📸 Copy Recent Screenshot\n🔍 Environment Variables (fze)\n📋 Logs (fzl)\n🔎 Aliases (fza)\n" |
    ~/Scripts/fzf-vim.sh --height=80% \
      --prompt="❯ " \
      --ansi \
      $FZF_COLORS)

  # Clear residual fzf output before running action
  clear

  case "$choice" in
  "🎨 Themes") themes_menu ;;
  "🔀 PRs Requesting Review")
    zsh -c '
      red="\033[1;31m"
      yellow="\033[1;33m"
      reset="\033[0m"
      bot_filter="[.[] | select(.author.login as \$a | [\"renovate\",\"dependabot\",\"github-actions\",\"changesets\",\"changeset-bot\"] | map(ascii_downcase) | index(\$a | ascii_downcase) | not)]"
      review_prs=$(gh search prs --review-requested=@me --state=open --json author,number,title,repository 2>/dev/null | jq -r "$bot_filter")
      review_count=$(echo "$review_prs" | jq "length")
      echo "${yellow}👀 PRs Requesting Review: ${review_count}${reset}"
      [[ "$review_count" -gt 0 ]] && echo "$review_prs" | jq -r ".[] | \"\(.repository.nameWithOwner | split(\"/\")[1])|\(.number)|\(.title)|\(.author.login)\"" | sort | while IFS="|" read -r repo num title author; do
        echo "${red}${repo}${reset} #${num} - ${title} (${author})"
      done
      echo ""
      read "?Press Enter to exit..."
    '
    ;;
  "🚀 Push to GitHub (now)")
    ~/.config/zshrc/github-auto-push.sh --nowait
    echo "GitHub auto-push completed"
    sleep 1
    ;;
  "🔔 Test GitHub Notification")
    ~/.config/zshrc/custom-notification.sh
    echo "GitHub notification completed"
    sleep 1
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
  "📸 Copy Recent Screenshot")
    ~/.config/skhd/copy-recent-screenshot.sh
    ;;
  *"fze"*) exec zsh -c "source ~/.config/zshrc/.zshrc && _fzf_env_vars" ;;
  *"fzl"*) exec zsh -c "source ~/.config/zshrc/.zshrc && _fzf_logs" ;;
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
# Aliases Menu (fza - copy to clipboard)
#-------------------------------------------------------------------------------
aliases_menu() {
  local selected
  # Source zshrc to get all aliases
  selected=$(zsh -c "source ~/.config/zshrc/.zshrc && alias" | ~/Scripts/fzf-vim.sh \
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
