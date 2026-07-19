#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
# shellcheck disable=SC1091

source "$HOME/.config/colorscheme/active/active-colorscheme.sh" 2>/dev/null || true

# Defensive defaults (Tokyo Night-ish) for the vars this script emits, in case
# the active palette is momentarily unavailable (e.g. mid `chezmoi apply` on a
# fresh box). Keeps the generated file from emitting empty `fg=`/`bg=` styles.
: "${gnohj_color01:=#c0aed2}" "${gnohj_color02:=#b7ce97}" "${gnohj_color03:=#a7cfbd}" "${gnohj_color06:=#dc988e}"
: "${gnohj_color04:=#a3b8c6}" "${gnohj_color05:=#dab183}" "${gnohj_color08:=#505e62}" "${gnohj_color09:=#9fb7a4}"
: "${gnohj_color10:=#0f1419}" "${gnohj_color11:=#da858e}" "${gnohj_color13:=#536571}"
: "${gnohj_color14:=#b8c9d3}" "${gnohj_color17:=#40474b}" "${gnohj_color24:=#a7cfaf}"

OUTPUT_FILE="$HOME/.config/tmux/tmux-colors.conf"

# Active-pane border COLOR: the pane you're ON matches tmux-dash's sidebar green
# accent (gnohj_color24, the @chip_green identity chip + active dot). So the
# active tmux border and the dash's green cue agree. Same on every window;
# normally the border just means "you are here". The prefix/resize/copy/zoom
# modes retint it to the old active-border color (gnohj_color06, salmon-red).
#
# The tint is a SECONDARY cue only. With `pane-border-status top` the active
# border has two kinds of cell: the pane's OWN top title line, and the vertical
# dividers it SHARES with a neighbour pane. A style FORMAT like #{?pane_in_mode,…}
# resolves per border cell against the pane that owns that cell, and a middle
# pane's dividers resolve against the (not-in-copy) NEIGHBOUR — so the tint only
# reaches the top line and any window-edge border, and a middle pane's side
# dividers stay salmon. The reliable full-pane signal is the copy/zoom chip on
# the pane's own title line (see pane-border-format in agentic.conf; @chip_copy
# below); this border tint just reinforces it where tmux can render it.
active_border_color="#{?@resize_mode,${gnohj_color06},#{?client_prefix,${gnohj_color06},#{?#{||:#{pane_in_mode},#{window_zoomed_flag}},${gnohj_color06},${gnohj_color24}}}}"

# Inactive panes: a muted slate blue (gnohj_color13, #536571), thin (fg only, no
# bg fill), on every window — blue-toned so it recedes but still reads distinct
# from the active border.
inactive_border_fmt="fg=${gnohj_color13}"

# Active-pane border: a bright colored line (fg only, no bg fill) so it stays
# thin like the inactive borders but pops by color — the sidebar green
# (gnohj_color24), retinted to the salmon-red (gnohj_color06) in
# prefix/resize/copy/zoom. (Filling bg with the color would make a solid, heavier
# band like tubular's "extra bold"; too heavy here.)
active_border_fmt="fg=${active_border_color}"

# Window list rendered natively (`#{W:inactive,active}`) so the highlight repaints on select-window instead of lagging behind the `#()` job. Each entry keeps a `range=window|<idx>` marker for click-to-select; 2-space separator leads every entry except window 1. Active: mint (gnohj_color03) + `*`; inactive: slate (gnohj_color08).
win_sep="#{?#{==:#{window_index},1},,  }"
window_list_fmt="#{W:${win_sep}#[range=window|#{window_index}]#[fg=${gnohj_color08}]#{window_index}:#{window_name}#[norange],${win_sep}#[range=window|#{window_index}]#[fg=${gnohj_color03}]#{window_index}:#{window_name}*#[norange]}"

# Session cell rendered NATIVELY (#S + prefix-aware color) so it repaints the instant you switch sessions - same reason the window list is native. Previously the session name lived inside the #() job (a tmux display-message for #S), so it couldn't update until the whole script re-ran on the next status-interval tick. Only the git segment (glyph + gitmux) stays in the #() below, lazy-loaded. Keeps the `range=user|sesh` click target for the sesh picker; prefix-active tints via #{?client_prefix,...}.
session_cell_fmt="#{?client_prefix,#[fg=${gnohj_color06}],#[fg=${gnohj_color04}]}#[range=user|sesh]#S#[norange] "

# Git-context glyph (🌿 checkout / 🌳 worktree) rendered NATIVELY from the pane option @git_ctx that generate-status-line.sh publishes. Native so it sits BEFORE the session name (order: 🌿 session git) and repaints instantly on revisit (the option persists per pane). Empty when the pane isn't a git repo, so this collapses to nothing.
glyph_cell_fmt="#[fg=${gnohj_color03},nobold]#{@git_ctx}"

# Host cell (leads the left cluster, native — no #() job) tracking the client's ACTIVE pane: 🖥️ + blue host — the REMOTE @ssh_host that generate-status-line.sh publishes when the pane is SSHed out (#{host_short} alone always reads the Mac since the tmux server never leaves it), else #{host_short}.
host_cell_fmt="#[fg=${gnohj_color05}]🖥️#[fg=${gnohj_color14}]#{?@ssh_host,#{@ssh_host},#{host_short}#{?@host_city,@#{@host_city},}} "

cat >"$OUTPUT_FILE" <<EOF
# Auto-generated tmux colors from active colorscheme
# Generated at: $(date)

# Status bar colors (transparent background)
set -g status-style "bg=default,fg=${gnohj_color14}"
set -g status-left-style "fg=${gnohj_color04},bg=default"
set -g status-right-style "fg=${gnohj_color09},bg=default"

# Use status-format for complete control - session name + window list are NATIVE (#S / #{W:...}) so they repaint instantly on switch; only the git segment (context glyph + gitmux status) is the cached #() job, lazy-loaded stale-while-revalidate. Host cell leads the LEFT-aligned cluster, followed by glyph + session + gitmux + window list.
set -g status-format[0] "#[align=left]${host_cell_fmt}${glyph_cell_fmt}${session_cell_fmt}#($HOME/.config/tmux/generate-status-line.sh '#{pane_id}')${window_list_fmt}"

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

# Pane border colors — inactive panes dim to muted slate so the active pane
# stands out by color on pane switch; the active pane matches the tmux-dash
# sidebar green accent (gnohj_color24) normally, retinted to the salmon-red
# (gnohj_color06) in prefix/resize/copy/zoom. See inactive_border_fmt /
# active_border_fmt above.
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
# Mode pill — the top-border copy (📋) / zoom (🔍) indicator on the active pane
# (see pane-border-format in agentic.conf). Shares the salmon-red (gnohj_color06)
# with the mode-tinted border line so the pill and the border agree in
# copy/zoom.
set -g @chip_copy "${gnohj_color06}"
# Resize-mode pill — the top-border ⤢ indicator on the active pane while \`prefix
# r\` resize mode is active (see pane-border-format in agentic.conf, gated on the
# @resize_mode session option). Same salmon-red (gnohj_color06) as the mode
# border line and the copy/zoom pill.
set -g @chip_resize "${gnohj_color06}"

# Message colors (display-message)
set -g message-style "bg=default,fg=${gnohj_color04}"
set -g message-command-style "bg=default,fg=${gnohj_color04}"

# Copy mode colors (selection highlight)
set -g mode-style "bg=${gnohj_color13},fg=${gnohj_color02}"
EOF

# echo "Tmux colors generated at $OUTPUT_FILE"

if tmux info &>/dev/null; then
  tmux source-file "$OUTPUT_FILE" 2>/dev/null
fi
