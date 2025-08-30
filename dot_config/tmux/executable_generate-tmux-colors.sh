#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
# shellcheck disable=SC1091

# This script generates tmux color configuration from the active colorscheme

# Source the active colorscheme
source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Output file for tmux colors
OUTPUT_FILE="$HOME/.config/tmux/tmux-colors.conf"

# Generate tmux color configuration
cat >"$OUTPUT_FILE" <<EOF
# Auto-generated tmux colors from active colorscheme
# Generated at: $(date)

# Status bar colors (transparent background)
set -g status-style "bg=default,fg=${gnohj_color14}"
set -g status-left-style "fg=${gnohj_color04},bg=default"
set -g status-right-style "fg=${gnohj_color09},bg=default"

# Status left: Session name with space + repo name + gitmux (reactive to current pane)
set -g status-left "#[fg=${gnohj_color04},nobold]#S #[fg=${gnohj_color14},nobold]#(PANE_ID='#{pane_id}'; PANE_NVIM_CWD=\\\$(tmux show-environment -t \"\\\$PANE_ID\" \"NVIM_CWD_\\\$PANE_ID\" 2>/dev/null | cut -d= -f2); DIR=\"\\\${PANE_NVIM_CWD:-#{pane_current_path}}\"; cd \"\\\$DIR\" 2>/dev/null && REPO_NAME=\\\$(basename \"\\\$(git rev-parse --show-toplevel 2>/dev/null)\" 2>/dev/null); OUTPUT=\\\$(gitmux -cfg \\\$HOME/.config/gitmux/gitmux.yml | sed 's/^ //'); [ -n \"\\\$REPO_NAME\" ] && echo \"#[fg=${gnohj_color06}]\\\$REPO_NAME#[fg=${gnohj_color14}]\\\$OUTPUT \" || echo \"\\\$OUTPUT \")"
set -g status-left-length 100

# Status right: Empty (minimalist)
set -g status-right ""

# Window status colors
set -g window-status-current-format '#[fg=${gnohj_color24}]*#[fg=${gnohj_color04}]#W'
set -g window-status-format ' #[fg=${gnohj_color08}]#W'

# Pane border colors
set -g pane-border-style "fg=${gnohj_color24}"
set -g pane-active-border-style "fg=${gnohj_color24}"

# Message colors (display-message)
set -g message-style "bg=default,fg=${gnohj_color04}"
set -g message-command-style "bg=default,fg=${gnohj_color04}"

# Copy mode colors (selection highlight)
set -g mode-style "bg=${gnohj_color13},fg=${gnohj_color02}"
EOF

# Silent generation - only output on error
# echo "Tmux colors generated at $OUTPUT_FILE"

# Reload tmux if it's running (silently)
if tmux info &>/dev/null; then
  tmux source-file "$OUTPUT_FILE" 2>/dev/null
fi
