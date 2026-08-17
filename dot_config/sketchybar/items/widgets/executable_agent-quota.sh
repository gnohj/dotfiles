#!/usr/bin/env bash
# Agent quota: tightest remaining window across Claude (both accounts), Codex and Copilot.

export PATH="/opt/homebrew/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

CACHE="$HOME/.logs/sketchybar/agent_quota.tsv"
mkdir -p "$(dirname "$CACHE")"

# sketchybar runs from launchd with a minimal PATH, so fall back to the real binary rather than a mise shim.
QUOTA_AXI="$(command -v quota-axi 2>/dev/null || true)"
[ -n "$QUOTA_AXI" ] || QUOTA_AXI="$HOME/.local/share/mise/installs/npm-quota-axi/latest/bin/quota-axi"

RESET_FMT='
def reset_in($s):
  if ($s // "") == "" then ""
  else ($s | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z")) as $c
  | ($c | try fromdateiso8601 catch null) as $e
  | if $e == null or $e <= 0 then ""
    else (($e - now) | floor) as $d
    | if $d <= 0 then "now"
      elif $d < 3600 then "\($d / 60 | floor)m"
      elif $d < 86400 then "\($d / 3600 | floor)h\((($d % 3600) / 60) | floor)m"
      else "\($d / 86400 | floor)d" end
    end
  end;'

# Only the work config dir holds a Claude Code OAuth blob; personal uses a token quota-axi cannot read.
snap=$(CLAUDE_CONFIG_DIR="$HOME/.claude-work" "$QUOTA_AXI" --json 2>/dev/null || true)

rows=$(printf '%s' "$snap" | jq -r "$RESET_FMT"'
  .providers[]?
  | (if .provider == "claude" then "Claude work" else .label end) as $name
  | .windows[]?
  | select(.percentRemaining != null)
  | [$name, .label, (.percentRemaining | tostring), reset_in(.resetsAt)]
  | @tsv' 2>/dev/null || true)

# Only live personal source; u.fh/u.sd are percent USED and it records no Fable field.
PU="$HOME/Library/Application Support/Claude/plan-usage-history.json"
personal=$(jq -r '
  (.samples[-1] // empty)
  | select((now - (.t / 1000)) < 21600)
  | "Claude personal\tsession\t\(100 - (.u.fh // 0))\t",
    "Claude personal\tweek\t\(100 - (.u.sd // 0))\t",
    "Claude personal\tFable week\t-\t"' "$PU" 2>/dev/null || true)

all=$(printf '%s\n%s\n' "$rows" "$personal" | grep -v '^[[:space:]]*$' || true)

# Claude's quota endpoint rate limits, so a throttled provider keeps its last-known rows marked stale rather than vanishing.
if [ -n "$all" ] && [ -s "$CACHE" ]; then
  all=$(awk -F'\t' -v OFS='\t' '
    FNR == NR { seen[$1] = 1; print; next }
    !($1 in seen) { $4 = "stale"; print }' <(printf '%s\n' "$all") "$CACHE")
fi

if [ -z "$all" ]; then
  sketchybar -m --set agent_quota icon.color="$GREY"
  : >"$CACHE"
  exit 0
fi

printf '%s\n' "$all" >"$CACHE"

# A `-` row is uncertainty, not headroom, so it never sets the floor.
low=$(printf '%s\n' "$all" | awk -F'\t' '$3 ~ /^[0-9]+$/ { if (m == "" || $3 < m) m = $3 } END { print (m == "" ? -1 : m) }')

if [ "$low" -lt 0 ]; then
  sketchybar -m --set agent_quota icon.color="$GREY"
  exit 0
fi

if [ "$low" -le 15 ]; then
  COLOR="$RED"
elif [ "$low" -le 35 ]; then
  COLOR="$ORANGE"
else
  COLOR="$ICON_BLUE"
fi

sketchybar -m --set agent_quota icon.color="$COLOR"
