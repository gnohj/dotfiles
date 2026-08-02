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

# `ccusage` on PATH is only a node shim around this binary; calling it direct skips a node boot per render (~48 MB, 13x faster).
ccusage_bin=ccusage
for candidate in "$HOME"/.bun/install/global/node_modules/@ccusage/ccusage-*/bin/ccusage; do
  [ -x "$candidate" ] && ccusage_bin="$candidate" && break
done

# ccusage colors some segments (context %, and in other versions burn-rate/cost) with
# its own ANSI codes, and its plain segments inherit the terminal's default foreground.
# We want the WHOLE line to be the palette green. So: strip every SGR ccusage emits,
# then wrap the entire line in the green truecolor SGR with a reset at the end. Emoji
# keep their own glyph colors; all text becomes uniform green regardless of ccusage's
# own coloring or version.
# stdin is consumed once and reused: ccusage reads it, and the plan-usage line below parses it out of the same copy.
_in="$(cat)"
out="$(printf '%s' "$_in" | "$ccusage_bin" statusline --offline "$@" | sed -E "s/${e}\[[0-9;]*m//g")"

# Mirrors claude-account's precedence (env > pin > path) without forking it: a personal session leaves CLAUDE_ACCOUNT unset, so the path rule alone would mislabel a pinned-personal pane in a work repo.
acct="${CLAUDE_ACCOUNT:-}"
pin="$HOME/.local/state/claude/account-override"
[ -z "$acct" ] && [ -r "$pin" ] && acct="$(tr -d '[:space:]' <"$pin")"
case "$acct" in
personal | work) ;;
*) case "$PWD" in */Developer/web* | */Developer/inferno* | */Developer/actions* | */.treehouse/*) acct=work ;; *) acct=personal ;; esac ;;
esac

# A glyph, not a word: it survives a narrow pane and reads at a glance across a wall of them.
case "$acct" in work) glyph='🏢' ;; *) glyph='🏠' ;; esac

# The glyph prints even when ccusage yields nothing, so a broken status line stays visibly distinct from an absent one - the failure mode that hid a missing ccusage binary for weeks.
if [ -n "$out" ]; then
  printf '%s%s %s%s[0m' "${green_sgr}" "$glyph" "$out" "${e}"
else
  printf '%s%s%s[0m' "${green_sgr}" "$glyph" "${e}"
fi

# Second line: plan usage + session cost off the harness payload (replacing an out-of-band /api/oauth/usage refresher), every field optional since rate_limits is Pro/Max only and each window may be absent.
if command -v jq >/dev/null 2>&1; then
  line2="$(printf '%s' "$_in" | jq -r '
    def rel($t): if $t == null then "" else (($t - now) as $d
      | if $d <= 0 then "now"
        elif $d >= 86400 then "\((($d + 43200)/86400)|floor)d"
        elif $d >= 3600 then "\((($d + 1800)/3600)|floor)h"
        else "\((($d + 30)/60)|floor)m" end) end;
    def win($w; $name): if ($w.used_percentage == null) then empty
      else "\($name) \($w.used_percentage)%" + (rel($w.resets_at) | if . == "" then "" else " ⟳" + . end) end;
    [ win(.rate_limits.five_hour // {}; "5h"),
      win(.rate_limits.seven_day // {}; "7d"),
      (if .cost.total_cost_usd == null then empty else "$\((.cost.total_cost_usd*100|round)/100)" end)
    ] | join(" · ")' 2>/dev/null)"
  if [ -n "$line2" ]; then
    printf '\n%s%s%s[0m' "${green_sgr}" "$line2" "${e}"
  fi
fi
