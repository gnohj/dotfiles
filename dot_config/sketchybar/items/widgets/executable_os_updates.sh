#!/bin/bash
export PATH="/usr/sbin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

paint() {
  sketchybar --set "widgets.group_glyph.$1" background.color="$([[ $2 == yes ]] && echo "$GREEN" || echo "$ICON_BLUE")"
}

case "$1" in
mac)
  if softwareupdate -l 2>/dev/null | grep -q '^\* Label:'; then paint system yes; else paint system no; fi
  ;;
omarchy)
  # omarchy-update-available dies under set -u without OMARCHY_PATH and exits 0 only on a pending update.
  ssh -o BatchMode=yes -o ConnectTimeout=4 fleet-dev-box 'OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}" omarchy-update-available' >/dev/null 2>&1
  case $? in
  0) paint vps yes ;;
  1) paint vps no ;;
  esac
  ;;
esac
