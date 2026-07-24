#!/usr/bin/env bash
# Background refresher for the Claude plan-usage statusline segment.
#
# Writes a pre-rendered, theme-green segment to ~/.cache/claude-usage/segment,
# e.g:  5h 5% ⟳2h · 7d 39% ⟳1d · fable 0% · 1m ago
# The statusline wrapper only ever `cat`s that file, so nothing here runs on the
# render path and it can never block or blank the status line. Invoked by the
# claude-usage-limits launchd agent (macOS) or a systemd timer (Linux VPS).
#
# Sources, in order of preference:
#   1. macOS desktop app history (~/Library/Application Support/Claude/
#      plan-usage-history.json) — refreshed ~every 5 min with 5h (fh) + 7d (sd)
#      utilization plus a timestamp. Free, never rate-limits. Gives the two
#      percentages and the "updated Xm ago" freshness.
#   2. The /api/oauth/usage endpoint — supplies the Fable/Opus weekly and the
#      reset timestamps (resets_at), neither of which the desktop history keeps,
#      and is the sole source on Linux. Rate-limit + cooldown guarded. Because
#      resets_at is absolute, one successful fetch lets us recompute the reset
#      countdowns every run without re-polling.
export PATH="$HOME/.local/share/mise/shims:$HOME/.bun/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

service="claude-oauth-personal"
dir="$HOME/.cache/claude-usage"
segment="$dir/segment"
apidata="$dir/personal.json"
cooldown="$dir/cooldown"
history="$HOME/Library/Application Support/Claude/plan-usage-history.json"
endpoint="https://api.anthropic.com/api/oauth/usage"
api_fresh=3600  # only re-poll the API (Fable + resets) when its cache is over 1h old

mkdir -p "$dir" 2>/dev/null
now="$(date +%s)"
mt() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

fh=""; sd=""; fable=""; updated=""

# 1. Preferred: the desktop app's local history (macOS). Latest sample = current.
if [ -r "$history" ]; then
  read -r fh sd lt < <(jq -r '.samples | max_by(.t) | "\(.u.fh) \(.u.sd) \(.t)"' "$history" 2>/dev/null)
  [ "$fh" = "null" ] && fh=""
  [ "$sd" = "null" ] && sd=""
  if [ -n "$lt" ] && [ "$lt" != "null" ]; then
    ts=$(( lt / 1000 ))
    clock="$(date -r "$ts" +"%I:%M%p" 2>/dev/null || date -d "@$ts" +"%I:%M%p" 2>/dev/null)"
    zone="$(date -r "$ts" +"%Z" 2>/dev/null || date -d "@$ts" +"%Z" 2>/dev/null)"
    updated="$(printf '%s' "${clock#0}" | tr 'APM' 'apm') $zone"
  fi
fi

# 2. Hit the API when we still need 5h/7d (Linux) or the cache is stale, unless inside a retry-after cooldown.
need_api=0
{ [ -z "$fh" ] || [ -z "$sd" ]; } && need_api=1
[ -f "$apidata" ] || need_api=1
[ -f "$apidata" ] && [ $(( now - $(mt "$apidata" 2>/dev/null || echo 0) )) -gt "$api_fresh" ] && need_api=1
cooling=0
if [ -f "$cooldown" ]; then u="$(cat "$cooldown" 2>/dev/null)"; [ -n "$u" ] && [ "$now" -lt "$u" ] && cooling=1; fi

if [ "$need_api" = 1 ] && [ "$cooling" = 0 ]; then
  tok="$(security find-generic-password -s "$service" -w 2>/dev/null)"
  [ -z "$tok" ] && [ -r "$HOME/.claude/.credentials.json" ] && tok="$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)"
  if [ -n "$tok" ]; then
    tmp="$(mktemp "$dir/body.XXXXXX")"; hdr="$(mktemp "$dir/hdr.XXXXXX")"
    code="$(curl -s --max-time 8 -o "$tmp" -w '%{http_code}' -D "$hdr" \
      -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20" \
      "$endpoint" 2>/dev/null)"
    if [ "$code" = "200" ] && jq -e '.five_hour' "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$apidata"; rm -f "$cooldown" "$dir/failcount"
    else
      rm -f "$tmp"
      if [ "$code" = "429" ]; then
        retry="$(grep -i '^retry-after:' "$hdr" 2>/dev/null | tr -dc '0-9')"; [ -z "$retry" ] && retry=3600
        n="$(cat "$dir/failcount" 2>/dev/null || echo 0)"; n=$(( n + 1 )); echo "$n" > "$dir/failcount"
        pow=$(( n > 4 ? 3 : n - 1 )); [ "$pow" -lt 0 ] && pow=0
        backoff=$(( retry * (1 << pow) )); [ "$backoff" -gt 43200 ] && backoff=43200
        echo $(( now + backoff )) > "$cooldown"
      fi
    fi
    rm -f "$hdr"
  fi
fi

# 3. Fill gaps from the API cache: 5h/7d if local history was absent (Linux), Fable weekly, and reset countdowns recomputed from absolute resets_at.
reset_rel() {  # $1 = key (five_hour/seven_day); prints "2h"/"1d"/"45m"/""
  [ -r "$apidata" ] || return
  jq -r --arg k "$1" '
    (.[$k].resets_at // "") as $x
    | if ($x | type) == "string" and ($x | length) > 0
      then (($x | sub("\\.[0-9]+"; "") | sub("Z$"; "Z") | fromdateiso8601) - now) as $d
        | if $d <= 0 then "now"
          elif $d >= 86400 then "\((($d + 43200) / 86400) | floor)d"
          elif $d >= 3600  then "\((($d + 1800)  / 3600)  | floor)h"
          else "\((($d + 30) / 60) | floor)m" end
      else "" end' "$apidata" 2>/dev/null
}
r5h=""; r7d=""
if [ -r "$apidata" ]; then
  [ -z "$fh" ] && fh="$(jq -r '(.five_hour.utilization // 0) | round' "$apidata" 2>/dev/null)"
  [ -z "$sd" ] && sd="$(jq -r '(.seven_day.utilization // 0) | round' "$apidata" 2>/dev/null)"
  fable="$(jq -r '((.seven_day_opus // .seven_day_fable // .seven_day_premium // {}).utilization // 0) | round' "$apidata" 2>/dev/null)"
  r5h="$(reset_rel five_hour)"; r7d="$(reset_rel seven_day)"
fi
[ -z "$fable" ] && fable=0

# Nothing to show yet — leave any existing segment in place.
[ -z "$fh$sd" ] && exit 0

seg="5h ${fh:-0}%"; [ -n "$r5h" ] && seg="$seg ⟳$r5h"
seg="$seg · 7d ${sd:-0}%"; [ -n "$r7d" ] && seg="$seg ⟳$r7d"
seg="$seg · fable ${fable}%"
[ -n "$updated" ] && seg="$seg · $updated"

green="#a7cfbd"
active="$HOME/.config/colorscheme/active/active-colorscheme.sh"
[ -r "$active" ] && green="$( (. "$active" >/dev/null 2>&1; printf '%s' "${gnohj_color03:-#a7cfbd}") )"
hex="${green#\#}"; r=$((16#${hex:0:2})); g=$((16#${hex:2:2})); b=$((16#${hex:4:2}))
e=$(printf '\033')
printf '%s[38;2;%s;%s;%sm%s%s[0m' "$e" "$r" "$g" "$b" "$seg" "$e" > "$segment"
