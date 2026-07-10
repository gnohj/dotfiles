#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
# shellcheck disable=SC1091

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

OUTPUT_FILE="$HOME/.config/tmux/tmux-colors.conf"

# Pane-border color as a tmux #{...} conditional (tmux 3.2+ expands formats in
# style options): only the AI-widget window (name contains the 🤖 robot emoji)
# keeps the accent green (gnohj_color24); every other window gets the scheme's
# dimmed slate (gnohj_color13 — the same muted tone as stale agents) so the AI
# window stands out. Glob-matched (`m:`) so the emoji's variation selector /
# tmux-fingers suffix don't matter. The shell expands the two ${gnohj_color*}
# hexes here; the #{...} stays literal and is evaluated by tmux per-window at
# draw time — no hooks needed.
border_fmt="fg=#{?#{m:*🤖*,#{window_name}},${gnohj_color24},${gnohj_color13}}"

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

# Cursor color — tmux owns the cursor inside a session and, with the default
# 'cursor-colour none', it does NOT pass the terminal's configured cursor color
# through. The cursor then falls back to reverse-video (inverts whatever glyph
# is under it), which over a transparent background reads as a gray box. Setting
# it explicitly makes tmux assert the color so the cursor stays this green.
set -g cursor-colour "${gnohj_color24}"

# Pane border colors — accent green on every window, except the editor window
# (🖋️) which blends into the transparent bg; see border_fmt above.
set -g pane-border-style "${border_fmt}"
set -g pane-active-border-style "${border_fmt}"

# Border-chip palette — referenced by pane-border-format in tmux.conf (via
# #{@chip_*}) so the agent-status pills follow the active colorscheme instead of
# hardcoded hexes. Formats resolve at draw time, so these being set here (sourced
# after tmux.conf) is fine.
#   dark  = pill text on filled pills;  green = left identity chip + active dot;
#   gray  = inactive (dimmed) pill bg.
set -g @chip_dark "${gnohj_color10}"
set -g @chip_green "${gnohj_color24}"
set -g @chip_gray "${gnohj_color17}"
# Status pill colors — mirror the sidebar's theme.working/idle/input/new (see
# state::load_theme) so the border pills and the agent list agree at a glance.
set -g @chip_working "${gnohj_color04}"
set -g @chip_idle "${gnohj_color05}"
set -g @chip_input "${gnohj_color11}"
set -g @chip_new "${gnohj_color03}"

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
