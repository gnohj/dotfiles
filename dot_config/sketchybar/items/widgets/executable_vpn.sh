#!/bin/bash
# Refresh the VPN widget from the Private Internet Access CLI (piactl).
#   piactl get connectionstate  -> Connected | Connecting | Disconnected | ...
#   piactl get region           -> region id, e.g. "ca-toronto", "us-georgia"
#
# Color = connection state (green connected, yellow transitioning, red exposed).
# Label  = "<COUNTRY>" or, for US/Canada, "<COUNTRY>-<STATE>" (e.g. US-GA, CA-ON).
# PIA region suffixes are a mix of state names (us-georgia), city names
# (us-atlanta -> GA), and directionals (us-east -> US-E); region_label maps them.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.vpn}"

# Nerd Font shield glyphs (mirror config/icons.lua vpn.on / vpn.off)
ICON_ON="󰦝"
ICON_OFF="󰦞"

# Map a PIA region id to a display label. US/CA regions resolve to a
# country + 2-letter state/province abbreviation; everything else is just the
# uppercased country prefix.
region_label() {
  local region="$1"
  local country="${region%%-*}"           # "us-georgia" -> "us"
  local rest="${region#*-}"               # "us-georgia" -> "georgia"
  [ "$rest" = "$region" ] && rest=""       # no separator -> no sub-region
  rest="${rest%-streaming-optimized}"      # drop PIA's streaming qualifier
  local cc sub
  cc="$(printf '%s' "$country" | tr '[:lower:]' '[:upper:]')"
  [ -z "$cc" ] && cc="??"

  case "$country-$rest" in
    us-alabama) sub=AL ;; us-alaska) sub=AK ;; us-arkansas) sub=AR ;;
    us-atlanta) sub=GA ;; us-baltimore) sub=MD ;; us-california) sub=CA ;;
    us-chicago) sub=IL ;; us-connecticut) sub=CT ;; us-denver) sub=CO ;;
    us-east) sub=E ;; us-florida) sub=FL ;; us-honolulu) sub=HI ;;
    us-houston) sub=TX ;; us-idaho) sub=ID ;; us-indiana) sub=IN ;;
    us-iowa) sub=IA ;; us-kansas) sub=KS ;; us-kentucky) sub=KY ;;
    us-las-vegas) sub=NV ;; us-louisiana) sub=LA ;; us-maine) sub=ME ;;
    us-massachusetts) sub=MA ;; us-michigan) sub=MI ;; us-minnesota) sub=MN ;;
    us-mississippi) sub=MS ;; us-missouri) sub=MO ;; us-montana) sub=MT ;;
    us-nebraska) sub=NE ;; us-new-hampshire) sub=NH ;; us-new-mexico) sub=NM ;;
    us-new-york) sub=NY ;; us-north-carolina) sub=NC ;; us-north-dakota) sub=ND ;;
    us-ohio) sub=OH ;; us-oklahoma) sub=OK ;; us-oregon) sub=OR ;;
    us-pennsylvania) sub=PA ;; us-rhode-island) sub=RI ;;
    us-salt-lake-city) sub=UT ;; us-seattle) sub=WA ;; us-silicon-valley) sub=CA ;;
    us-south-carolina) sub=SC ;; us-south-dakota) sub=SD ;; us-tennessee) sub=TN ;;
    us-texas) sub=TX ;; us-vermont) sub=VT ;; us-virginia) sub=VA ;;
    us-washington-dc) sub=DC ;; us-west) sub=W ;; us-west-virginia) sub=WV ;;
    us-wilmington) sub=DE ;; us-wisconsin) sub=WI ;; us-wyoming) sub=WY ;;
    ca-montreal) sub=QC ;; ca-ontario) sub=ON ;; ca-toronto) sub=ON ;;
    ca-vancouver) sub=BC ;;
    *) sub="" ;;
  esac

  if [ -n "$sub" ]; then printf '%s-%s' "$cc" "$sub"; else printf '%s' "$cc"; fi
}

PIACTL="$(command -v piactl || echo '/Applications/Private Internet Access.app/Contents/MacOS/piactl')"

if [ ! -x "$PIACTL" ]; then
  sketchybar --set "$NAME" icon="$ICON_OFF" icon.color="$GREY" \
    label="n/a" label.color="$GREY" label.drawing=on
  exit 0
fi

state="$("$PIACTL" get connectionstate 2>/dev/null)"
region="$("$PIACTL" get region 2>/dev/null)"
label="$(region_label "$region")"

case "$state" in
  Connected)
    sketchybar --set "$NAME" icon="$ICON_ON" icon.color="$GREEN" \
      icon.padding_right=2 \
      label="$label" label.color="$GREEN" label.drawing=on ;;
  Connecting | Disconnecting | DisconnectingToReconnect | Interrupting | StillNeedsRetry)
    sketchybar --set "$NAME" icon="$ICON_OFF" icon.color="$YELLOW" \
      icon.padding_right=2 \
      label="…" label.color="$YELLOW" label.drawing=on ;;
  *)
    # Disconnected / Interrupted / unknown -> not protected. Red shield only;
    # the exit region is moot when not connected, so hide the label entirely.
    sketchybar --set "$NAME" icon="$ICON_OFF" icon.color="$RED" \
      icon.padding_right=0 \
      label.drawing=off ;;
esac
