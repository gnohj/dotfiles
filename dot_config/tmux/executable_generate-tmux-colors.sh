#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
# shellcheck disable=SC1091

source "$HOME/.config/colorscheme/active/active-colorscheme.sh" 2>/dev/null || true

# Defensive defaults (Tokyo Night-ish) for the vars this script emits, in case
# the active palette is momentarily unavailable (e.g. mid `chezmoi apply` on a
# fresh box). Keeps the generated file from emitting empty `fg=`/`bg=` styles.
: "${gnohj_color01:=#c0aed2}" "${gnohj_color02:=#b7ce97}" "${gnohj_color03:=#a7cfbd}"
: "${gnohj_color04:=#a3b8c6}" "${gnohj_color05:=#dab183}" "${gnohj_color09:=#9fb7a4}"
: "${gnohj_color10:=#0f1419}" "${gnohj_color11:=#da858e}" "${gnohj_color13:=#536571}"
: "${gnohj_color14:=#b8c9d3}" "${gnohj_color17:=#40474b}" "${gnohj_color24:=#a7cfaf}"

OUTPUT_FILE="$HOME/.config/tmux/tmux-colors.conf"

# Active-pane border COLOR (tmux 3.2+ expands formats in style options): the
# pane you're ON is green (gnohj_color03, #a7cfbd) normally — the SAME bright mint
# green as tmux-dash's sidebar foreground text (theme.name → gnohj_color03), so
# the active pane reads in the same green as the agent names. Orange
# (gnohj_color05) in copy-mode, lavender (gnohj_color01) when zoomed. NB: this is
# close to the identity pill's green (@chip_green → gnohj_color24), so the active
# border can blend with the pill's edges on agent panes — intended, to match the
# sidebar text.
# Same on every window; 🤖 windows are already marked by the agent HUD chip, so
# the border just means "you are here". pane_in_mode / window_zoomed_flag are
# evaluated in the active pane's OWN context, and tmux re-evaluates *-style
# formats on every redraw - including on pane switch and on entering/leaving copy
# or zoom - so this needs no hooks. Prefix is intentionally NOT tinted: tmux
# never repaints borders on prefix press, so it would require taking over the
# prefix key (we don't).
active_border_color="#{?pane_in_mode,${gnohj_color05},#{?window_zoomed_flag,${gnohj_color01},${gnohj_color03}}}"

# Inactive panes: a muted slate blue (gnohj_color13, #536571), thin (fg only, no
# bg fill), on every window — blue-toned so it recedes but still reads distinct
# from the red active border.
inactive_border_fmt="fg=${gnohj_color13}"

# Active-pane border: a bright colored line (fg only, no bg fill) so it stays
# thin like the inactive borders but pops by color — green normally, orange in
# copy, lavender when zoomed. (Filling bg with the color would make a solid,
# heavier band like tubular's "extra bold"; too heavy here.)
active_border_fmt="fg=${active_border_color}"

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

# Pane border colors — inactive panes dim to muted gray so the active pane
# stands out by color on pane switch; the active pane keeps its per-window
# normal color (green on 🤖 windows, slate elsewhere) plus the mode-aware
# copy/zoom tint. See inactive_border_fmt / active_border_fmt above.
set -g pane-border-style "${inactive_border_fmt}"
set -g pane-active-border-style "${active_border_fmt}"

# Border-chip palette — referenced by pane-border-format in tmux.conf (via
# #{@chip_*}) so the agent-status pills follow the active colorscheme instead of
# hardcoded hexes. Formats resolve at draw time, so these being set here (sourced
# after tmux.conf) is fine.
#   dark  = pill text on filled pills;  green = left identity chip + active dot;
#   gray  = inactive (dimmed) pill bg.
set -g @chip_dark "${gnohj_color10}"
set -g @chip_green "${gnohj_color24}"
set -g @chip_gray "${gnohj_color17}"
# Status pill colors — mirror the sidebar's theme.working/idle/input/done/new
# (see state::load_theme) so the border pills and the agent list agree at a
# glance. \`input\`, \`done\`, and \`limit\` all share the red (color11) — they're the
# "needs you" states — distinguished by the pill's text, not color.
set -g @chip_working "${gnohj_color04}"
set -g @chip_idle "${gnohj_color05}"
set -g @chip_input "${gnohj_color11}"
set -g @chip_done "${gnohj_color11}"
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
