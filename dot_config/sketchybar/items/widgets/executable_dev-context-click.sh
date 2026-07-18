#!/usr/bin/env bash
# Build the dev-context picker popup (Local + SSH aliases + online Tailscale nodes); a row runs `dev-context set <token>` and closes the popup.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dev_context}"

GLYPH_LOCAL="󰌢"
GLYPH_SSH="󰒋"
GLYPH_TS="󰛳"

HEADER_FONT="MesloLGM Nerd Font:Bold:13.0"
OPT_INDENT=18
DIM="0x80${GREY#0x??}" # half-alpha grey for non-clickable info rows

# Fast path: right-click or a click while the menu is open just closes it, skipping the tailscale re-enumeration.
drawing="$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.popup.drawing // "off"')"
if [ "$BUTTON" = "right" ] || [ "$drawing" = "on" ]; then
  sketchybar --set "$NAME" popup.drawing=off --remove "/${NAME}.opt\.*/"
  exit 0
fi

CUR="$(dev-context get 2>/dev/null || echo local)"

# Menu was closed: enumerate rows and open.
args=(--remove "/${NAME}.opt\.*/" --set "$NAME" popup.drawing=on)
i=0

add_option() { # token label color
  local color="$3"
  [ "$1" = "$CUR" ] && color="$MAGENTA"
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$2" label.color="$color" label.padding_left="$OPT_INDENT" icon.drawing=off
    click_script="dev-context set $1 && sketchybar --set $NAME popup.drawing=off --remove /${NAME}.opt\.*/")
  i=$((i + 1))
}

add_header() { # text
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$1" label.color="$GREY" label.font="$HEADER_FONT" icon.drawing=off)
  i=$((i + 1))
}

# Non-clickable, dimmed row for nodes you can't launch dev sessions against (phones, TVs).
add_info() { # text
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$1" label.color="$DIM" label.padding_left="$OPT_INDENT" icon.drawing=off)
  i=$((i + 1))
}

add_option "local" "$GLYPH_LOCAL  Local" "$WHITE"

ssh_hosts="$(awk 'tolower($1)=="host"{for(n=2;n<=NF;n++) if($n !~ /[*?]/ && $n != "github.com") print $n}' "$HOME/.ssh/config" 2>/dev/null | awk '!seen[$0]++')"
if [ -n "$ssh_hosts" ]; then
  add_header "SSH"
  while IFS= read -r host; do
    [ -n "$host" ] && add_option "ssh:$host" "$GLYPH_SSH  $host" "$BLUE"
  done <<<"$ssh_hosts"
fi

# Tailnet nodes (Self + online peers), cached 60s and timeout-capped so a slow daemon can't stall the popup.
CACHE="${TMPDIR:-/tmp}/dev-context-ts-nodes.cache"
now="$(date +%s)"
mtime=0
[ -f "$CACHE" ] && mtime="$(stat -f %m "$CACHE" 2>/dev/null || echo 0)"
if [ -s "$CACHE" ] && [ $((now - mtime)) -lt 60 ]; then
  ts_nodes="$(cat "$CACHE")"
else
  TS="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
  TIMEOUT="$(command -v timeout || command -v gtimeout || true)"
  if [ -n "$TIMEOUT" ]; then
    raw="$("$TIMEOUT" 3 "$TS" status --json 2>/dev/null)"
  else
    raw="$("$TS" status --json 2>/dev/null)"
  fi
  # Emit "name<TAB>OS<TAB>isSelf". iOS reports HostName "localhost", so prefer the first DNSName label.
  ts_nodes="$(printf '%s' "$raw" | jq -r '([.Self + {__self: true}] + [.Peer[]? | select(.Online==true)]) | .[] | (((.DNSName // "") | split(".")[0]) // .HostName) as $n | select($n != "" and $n != "localhost") | "\($n)\t\(.OS)\t\(.__self // false)"' 2>/dev/null | awk '!seen[$0]++')"
  printf '%s\n' "$ts_nodes" >"$CACHE"
fi

if [ -n "$ts_nodes" ]; then
  add_header "TAILSCALE"
  while IFS=$'\t' read -r host os self; do
    [ -z "$host" ] && continue
    # Self is this machine (== Local) and mobile/appliance OSes aren't dev targets: both are dimmed info.
    if [ "$self" = "true" ]; then
      add_info "$host"
    else
      case "$os" in
        iOS | iPadOS | android | tvOS) add_info "$host" ;;
        *) add_option "ts:$host" "$GLYPH_TS  $host" "$GREEN" ;;
      esac
    fi
  done <<<"$ts_nodes"
fi

sketchybar -m "${args[@]}" >/dev/null
