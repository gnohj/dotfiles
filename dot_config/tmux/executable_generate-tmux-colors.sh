#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
# shellcheck disable=SC1091

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

OUTPUT_FILE="$HOME/.config/tmux/tmux-colors.conf"

# Generate tmux color configuration
cat >"$OUTPUT_FILE" <<EOF
# Auto-generated tmux colors from active colorscheme
# Generated at: $(date)

# Status bar colors (transparent background)
set -g status-style "bg=default,fg=${gnohj_color14}"
set -g status-left-style "fg=${gnohj_color04},bg=default"
set -g status-right-style "fg=${gnohj_color09},bg=default"

# Use status-format for complete control - everything centered as one unit
set -g status-format[0] "#[align=centre]#($HOME/.config/tmux/generate-status-line.sh '#{pane_id}')"

# Empty status-left and status-right since we're using status-format
set -g status-left ""
set -g status-right ""

# Empty window status formats to prevent duplication
set -g window-status-current-format ''
set -g window-status-format ''

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
