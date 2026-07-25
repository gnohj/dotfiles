#!/usr/bin/env bash
# Background refresher for the Claude plan-usage statusline segments.
#
# Writes one pre-rendered, theme-green segment PER ACCOUNT to
# ~/.cache/claude-usage/segment-<account> (e.g. segment-personal, segment-work),
# so the statusline can show whichever account the current session runs under.
# The wrapper only `cat`s a segment file, so nothing here runs on the render path
# and it can never block or blank the status line. Invoked by the
# claude-usage-limits launchd agent (macOS) or a systemd timer (Linux VPS).
#
# Per account, source priority:
#   1. Fresh desktop-app history (~/Library/Application Support/<profile>/
#      plan-usage-history.json, <=15 min old) - free, no rate limit. But it only
#      updates while that desktop app is running.
#   2. The /api/oauth/usage endpoint (per-account OAuth token) - app-independent,
#      supplies Fable + reset timestamps, and is the sole source on Linux.
#      Rate-limit + cooldown + exponential-backoff guarded.
#   3. Last-known local sample (stale) - so a closed app degrades to old numbers
#      with an honest timestamp rather than a blank line.
export PATH="$HOME/.local/share/mise/shims:$HOME/.bun/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

dir="$HOME/.cache/claude-usage"
endpoint="https://api.anthropic.com/api/oauth/usage"
stale_after=900  # a desktop sample older than 15 min means the app isn't polling

mkdir -p "$dir" 2>/dev/null
now="$(date +%s)"
mt() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

green="#a7cfbd"
active="$HOME/.config/colorscheme/active/active-colorscheme.sh"
[ -r "$active" ] && green="$( (. "$active" >/dev/null 2>&1; printf '%s' "${gnohj_color03:-#a7cfbd}") )"
hex="${green#\#}"; gr=$((16#${hex:0:2})); gg=$((16#${hex:2:2})); gb=$((16#${hex:4:2}))
esc=$(printf '\033')

reset_rel() {  # $1=apidata file, $2=key(five_hour/seven_day) → "2h"/"1d"/"45m"/""
  jq -r --arg k "$2" '
    (.[$k].resets_at // "") as $x
    | if ($x | type) == "string" and ($x | length) > 0
      then (($x | sub("\\.[0-9]+"; "") | fromdateiso8601) - now) as $d
        | if $d <= 0 then "now"
          elif $d >= 86400 then "\((($d + 43200) / 86400) | floor)d"
          elif $d >= 3600  then "\((($d + 1800)  / 3600)  | floor)h"
          else "\((($d + 30) / 60) | floor)m" end
      else "" end' "$1" 2>/dev/null
}

clock_at() {  # $1=epoch seconds → "5:58pm CDT"
  local c z
  c="$(date -r "$1" +"%I:%M%p" 2>/dev/null || date -d "@$1" +"%I:%M%p" 2>/dev/null)"
  z="$(date -r "$1" +"%Z" 2>/dev/null || date -d "@$1" +"%Z" 2>/dev/null)"
  printf '%s %s' "$(printf '%s' "${c#0}" | tr 'APM' 'apm')" "$z"
}

refresh_account() {  # $1=account label  $2=keychain service  $3=history file
  local acct="$1" svc="$2" history="$3"
  local segment="$dir/segment-$acct" apidata="$dir/apidata-$acct.json"
  local cooldown="$dir/cooldown-$acct" failcount="$dir/failcount-$acct"
  local fh="" sd="" fable="" ts="" r5h="" r7d=""
  local lfh="" lsd="" lts="" lt lage

  if [ -r "$history" ]; then
    read -r lfh lsd lt < <(jq -r '.samples | max_by(.t) | "\(.u.fh) \(.u.sd) \(.t)"' "$history" 2>/dev/null)
    if [ -n "$lt" ] && [ "$lt" != "null" ]; then
      lts=$(( lt / 1000 )); lage=$(( now - lts ))
      if [ "$lage" -ge 0 ] && [ "$lage" -le "$stale_after" ]; then fh="$lfh"; sd="$lsd"; ts="$lts"; fi
    fi
  fi

  local api_fresh need_api=0 cooling=0 u
  if [ -n "$fh" ] && [ -n "$sd" ]; then api_fresh=3600; else api_fresh=300; fi
  { [ -z "$fh" ] || [ -z "$sd" ]; } && need_api=1
  [ -f "$apidata" ] || need_api=1
  [ -f "$apidata" ] && [ $(( now - $(mt "$apidata" 2>/dev/null || echo 0) )) -gt "$api_fresh" ] && need_api=1
  if [ -f "$cooldown" ]; then u="$(cat "$cooldown" 2>/dev/null)"; [ -n "$u" ] && [ "$now" -lt "$u" ] && cooling=1; fi

  if [ "$need_api" = 1 ] && [ "$cooling" = 0 ]; then
    local tok tmp hdr code retry n pow backoff
    tok="$(security find-generic-password -s "$svc" -w 2>/dev/null)"
    [ -z "$tok" ] && [ -r "$HOME/.claude/.credentials.json" ] && tok="$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)"
    if [ -n "$tok" ]; then
      tmp="$(mktemp "$dir/body.XXXXXX")"; hdr="$(mktemp "$dir/hdr.XXXXXX")"
      code="$(curl -s --max-time 8 -o "$tmp" -w '%{http_code}' -D "$hdr" \
        -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20" "$endpoint" 2>/dev/null)"
      if [ "$code" = "200" ] && jq -e '.five_hour' "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "$apidata"; rm -f "$cooldown" "$failcount"
      else
        rm -f "$tmp"
        if [ "$code" = "429" ]; then
          retry="$(grep -i '^retry-after:' "$hdr" 2>/dev/null | tr -dc '0-9')"; [ -z "$retry" ] && retry=3600
          n="$(cat "$failcount" 2>/dev/null || echo 0)"; n=$(( n + 1 )); echo "$n" > "$failcount"
          pow=$(( n > 4 ? 3 : n - 1 )); [ "$pow" -lt 0 ] && pow=0
          backoff=$(( retry * (1 << pow) )); [ "$backoff" -gt 43200 ] && backoff=43200
          echo $(( now + backoff )) > "$cooldown"
        fi
      fi
      rm -f "$hdr"
    fi
  fi

  if [ -r "$apidata" ]; then
    if [ -z "$fh" ] || [ -z "$sd" ]; then
      fh="$(jq -r '(.five_hour.utilization // 0) | round' "$apidata" 2>/dev/null)"
      sd="$(jq -r '(.seven_day.utilization // 0) | round' "$apidata" 2>/dev/null)"
      ts="$(mt "$apidata" 2>/dev/null)"
    fi
    fable="$(jq -r '((.seven_day_opus // .seven_day_fable // .seven_day_premium // {}).utilization // 0) | round' "$apidata" 2>/dev/null)"
    r5h="$(reset_rel "$apidata" five_hour)"; r7d="$(reset_rel "$apidata" seven_day)"
  fi

  if [ -z "$fh" ] && [ -n "$lfh" ]; then fh="$lfh"; sd="$lsd"; ts="$lts"; fi
  [ -z "$fable" ] && fable=0
  [ -z "$fh$sd" ] && return

  local updated=""; [ -n "$ts" ] && updated="$(clock_at "$ts")"
  local seg="5h ${fh:-0}%"; [ -n "$r5h" ] && seg="$seg ⟳$r5h"
  seg="$seg · 7d ${sd:-0}%"; [ -n "$r7d" ] && seg="$seg ⟳$r7d"
  seg="$seg · fable ${fable}%"
  [ -n "$updated" ] && seg="$seg · $updated"

  printf '%s[38;2;%s;%s;%sm%s%s[0m' "$esc" "$gr" "$gg" "$gb" "$seg" "$esc" > "$segment"
}

# Personal only: work is a team plan, so /api/oauth/usage 403s and has no individual 5h/weekly limits.
refresh_account personal claude-oauth-personal "$HOME/Library/Application Support/Claude/plan-usage-history.json"
