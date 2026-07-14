#!/usr/bin/env bash
# ccusage statusline with ANSI yellow remapped to the palette green (gnohj_color03).
#
# Why: ccusage colors high burn-rate / cost segments in ANSI "yellow". The terminal
# maps ANSI yellow (palette 3) to gnohj_color05 (#dab183), which reads as brown/tan.
# ccusage exposes no color options, so we recolor its output on the fly. Claude Code
# re-runs this per status render and passes the hook JSON on stdin (forwarded to
# ccusage below). If ccusage emits no color, the sed matches nothing and this is a
# transparent passthrough - it can never break the status line, only recolor it.
#
# Green is read live from the active colorscheme so it tracks colorscheme switches.
#
# PATH: Claude Code renders the status line with a minimal PATH, not the interactive
# shell's. ccusage lives in ~/.bun/bin and its #!/usr/bin/env node shebang needs node,
# provided here via mise shims. Without these two dirs the `ccusage` call below fails
# with "command not found" and the status line silently goes blank.
export PATH="$HOME/.local/share/mise/shims:$HOME/.bun/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

green="#a7cfbd"
active="$HOME/.config/colorscheme/active/active-colorscheme.sh"
if [ -r "$active" ]; then
  green="$( (. "$active" >/dev/null 2>&1; printf '%s' "${gnohj_color03:-#a7cfbd}") )"
fi
hex="${green#\#}"
r=$((16#${hex:0:2}))
g=$((16#${hex:2:2}))
b=$((16#${hex:4:2}))
e=$(printf '\033')
green_sgr="${e}[38;2;${r};${g};${b}m"

# ccusage colors some segments (context %, and in other versions burn-rate/cost) with
# its own ANSI codes, and its plain segments inherit the terminal's default foreground.
# We want the WHOLE line to be the palette green. So: strip every SGR ccusage emits,
# then wrap the entire line in the green truecolor SGR with a reset at the end. Emoji
# keep their own glyph colors; all text becomes uniform green regardless of ccusage's
# own coloring or version.
out="$(ccusage statusline --offline "$@" | sed -E "s/${e}\[[0-9;]*m//g")"

[ -n "$out" ] && printf '%s%s%s[0m' "${green_sgr}" "$out" "${e}"
