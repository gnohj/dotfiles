#!/usr/bin/env bash
# ccusage statusline recolored to the palette green, since ccusage has no color options.

# Claude Code renders with a minimal PATH; without bun + mise shims ccusage is not found and the line goes blank.
export PATH="$HOME/.local/share/mise/shims:$HOME/.bun/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

# Quota tiers reuse baby-menu's palette slots: 11 danger, 06 orange, 12 warning, 02 live.
palette="#a7cfbd #da858e #dc988e #ccd19d #b7ce97"
active="$HOME/.config/colorscheme/active/active-colorscheme.sh"
if [ -r "$active" ]; then
  palette="$( (. "$active" >/dev/null 2>&1; . "$HOME/.config/colorscheme/omarchy-palette.sh" >/dev/null 2>&1 || true; printf '%s %s %s %s %s' "${gnohj_color03:-#a7cfbd}" "${gnohj_color11:-#da858e}" "${gnohj_color06:-#dc988e}" "${gnohj_color12:-#ccd19d}" "${gnohj_color02:-#b7ce97}") )"
fi
e=$(printf '\033')
sgr() {
  local hex="${1#\#}"
  printf '%s[38;2;%d;%d;%dm' "$e" $((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))
}
read -r c_green c_danger c_orange c_warning c_live <<<"$palette"
green_sgr="$(sgr "$c_green")"
danger_sgr="$(sgr "$c_danger")"
orange_sgr="$(sgr "$c_orange")"
warning_sgr="$(sgr "$c_warning")"
live_sgr="$(sgr "$c_live")"

# `ccusage` on PATH is only a node shim around this binary; calling it direct skips a node boot per render (~48 MB, 13x faster).
ccusage_bin=ccusage
for candidate in "$HOME"/.bun/install/global/node_modules/@ccusage/ccusage-*/bin/ccusage; do
  [ -x "$candidate" ] && ccusage_bin="$candidate" && break
done

# Strip every SGR ccusage emits and wrap the whole line in palette green; stdin is read once and reused below.
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
  line2="$(printf '%s' "$_in" | jq -r --arg green "$green_sgr" --arg danger "$danger_sgr" --arg orange "$orange_sgr" --arg warning "$warning_sgr" --arg live "$live_sgr" '
    def rel($t): if $t == null then "" else (($t - now) as $d
      | if $d <= 0 then "now"
        elif $d >= 86400 then "\((($d + 43200)/86400)|floor)d"
        elif $d >= 3600 then "\((($d + 1800)/3600)|floor)h"
        else "\((($d + 30)/60)|floor)m" end) end;
    def tier($left): if $left <= 15 then $danger elif $left <= 35 then $orange elif $left <= 60 then $warning else $live end;
    def win($w; $name): if ($w.used_percentage == null) then empty
      else (100 - $w.used_percentage | if . < 0 then 0 else . end | round) as $left
      | "\($name) " + tier($left) + "\($left)% left" + $green + (rel($w.resets_at) | if . == "" then "" else " ⟳" + . end) end;
    [ win(.rate_limits.five_hour // {}; "5h"),
      win(.rate_limits.seven_day // {}; "7d"),
      (if .cost.total_cost_usd == null then empty else "$\((.cost.total_cost_usd*100|round)/100)" end)
    ] | join(" · ")' 2>/dev/null)"
  if [ -n "$line2" ]; then
    printf '\n%s%s%s[0m' "${green_sgr}" "$line2" "${e}"
  fi
fi
