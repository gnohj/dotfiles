#!/usr/bin/env bash
# Pick a repo from treekanga.yml and open its TUI to add a worktree.
#
# Called from:
#   - `tka` alias in .zshrc
#   - "🌳 Add Worktree" entry in the launcher (rctrl-i)
#
# rctrl-semi uses ~/.config/skhd/treekanga-selector.sh, which wraps the same
# flow in `tmux display-popup` because skhd launches outside of tmux.

set -euo pipefail
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

CONFIG_FILE="$HOME/.config/treekanga/treekanga.yml"

if [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
fi
FZF_COLORS="--color=bg+:${gnohj_color13:-},border:${gnohj_color03:-},fg:${gnohj_color02:-},fg+:${gnohj_color02:-},hl+:${gnohj_color04:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-},header:${gnohj_color09:-}"

REPOS=$(grep -E '^  [a-zA-Z0-9_-]+:$' "$CONFIG_FILE" | sed 's/^  //;s/:$//' | awk '{print "📂 " $0}')

SELECTED=$(echo "$REPOS" | "$HOME/Scripts/fzf-vim.sh" \
  --no-border \
  --ansi \
  --no-sort \
  --prompt='🌳 ' \
  --bind 'tab:down,btab:up' \
  $FZF_COLORS) || exit 0

[ -z "$SELECTED" ] && exit 0
SELECTED=$(echo "$SELECTED" | awk '{print $2}')

WORKTREE_DIR=$(awk -v repo="$SELECTED" '
  $0 ~ "^  " repo ":$" { found=1; next }
  found && /^  [a-zA-Z]/ { found=0 }
  found && /worktreeTargetDir:/ { gsub(/.*worktreeTargetDir: */, ""); print; exit }
' "$CONFIG_FILE")

BARE_REPO_PATH="$HOME/$WORKTREE_DIR/.bare"

tmux new-window -n '🌳' -c "$BARE_REPO_PATH" 'export PATH="/opt/homebrew/bin:$PATH"; /opt/homebrew/bin/treekanga tui'
