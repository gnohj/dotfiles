#!/bin/bash
# Bluetooth widget backend: bar icon on `update`, popup rows on `list`, actions for the popup clicks.
#
#   bluetooth.sh              # update the bar item (routine / bluetooth_change)
#   bluetooth.sh list         # TSV the Lua side turns into popup rows
#   bluetooth.sh toggle       # flip controller power
#   bluetooth.sh connect <addr>
#   bluetooth.sh disconnect <addr>
#   bluetooth.sh scan         # Classic-BT inquiry, cached for `list` to pick up
#
# system_profiler reads (no dependency, ~60ms); blueutil is only needed to write, and without it the panel is read-only.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.bluetooth}"
CACHE_DIR="$HOME/.cache/sketchybar"
SCAN_CACHE="$CACHE_DIR/bluetooth_scan"
mkdir -p "$CACHE_DIR"

BLUEUTIL="$(command -v blueutil || true)"

# nf-md glyphs as raw UTF-8: macOS bash 3.2 has no $'\u'.
ICON_BT=$'\xf3\xb0\x82\xaf'
ICON_BT_CONNECTED=$'\xf3\xb0\x82\xb1'
ICON_BT_OFF=$'\xf3\xb0\x82\xb2'

profile() { system_profiler SPBluetoothDataType -json 2>/dev/null; }

power_state() {
  if [ -n "$BLUEUTIL" ]; then
    [ "$("$BLUEUTIL" -p 2>/dev/null)" = "1" ] && echo on || echo off
    return
  fi
  case "$(profile | jq -r '.SPBluetoothDataType[0].controller_properties.controller_state // ""')" in
    attrib_on) echo on ;;
    *) echo off ;;
  esac
}

# TSV rows; battery is whatever macOS publishes - AirPods report per-bud, most HID peripherals report nothing.
DEVICE_ROWS='
  def battery:
    (.device_batteryLevelMain // "") as $m
    | (.device_batteryLevelLeft // "") as $l
    | (.device_batteryLevelRight // "") as $r
    | if $m != "" then $m
      elif $l != "" and $r != "" then ($l | rtrimstr("%")) + "/" + $r
      elif $l != "" then $l
      elif $r != "" then $r
      else "" end;
  def rows($section):
    (. // []) | .[] | to_entries[]
    | [ $section, .key, (.value.device_address // ""), (.value.device_minorType // ""), (.value | battery) ]
    | @tsv;
  .SPBluetoothDataType[0] as $bt
  | ($bt.device_connected | rows("connected")), ($bt.device_not_connected | rows("paired"))
'

list() {
  printf 'power\t%s\t\t\t\n' "$(power_state)"
  printf 'blueutil\t%s\t\t\t\n' "$([ -n "$BLUEUTIL" ] && echo yes || echo no)"
  profile | jq -r "$DEVICE_ROWS" 2>/dev/null
  # Scan results are a cached snapshot; already-paired devices are dropped since the inquiry re-reports them.
  if [ -s "$SCAN_CACHE" ]; then
    paired="$(profile | jq -r '.SPBluetoothDataType[0] | (.device_connected + .device_not_connected // []) | .[] | to_entries[] | .value.device_address // empty' 2>/dev/null | tr 'A-Z' 'a-z')"
    while IFS=$'\t' read -r addr devname; do
      [ -n "$addr" ] || continue
      printf '%s\n' "$paired" | grep -qi -- "$(printf '%s' "$addr" | tr 'A-Z' 'a-z')" && continue
      printf 'available\t%s\t%s\t\t\n' "${devname:-$addr}" "$addr"
    done <"$SCAN_CACHE"
  fi
}

# Opt-in: --inquiry blocks for its full duration and finds Classic-BT only, so BLE peripherals never answer.
scan() {
  [ -n "$BLUEUTIL" ] || exit 0
  : >"$SCAN_CACHE"
  "$BLUEUTIL" --inquiry 6 --format json 2>/dev/null |
    jq -r '.[]? | [ (.address // ""), (.name // "") ] | @tsv' >"$SCAN_CACHE" 2>/dev/null
}

# Popup rows act through click_script, so the redraw comes back the other way: Lua listens on this event.
notify() { sketchybar --trigger bluetooth_refresh; }

update() {
  local state count icon color
  state="$(power_state)"
  count="$(profile | jq -r '(.SPBluetoothDataType[0].device_connected // []) | length' 2>/dev/null)"
  case "$count" in '' | *[!0-9]*) count=0 ;; esac

  if [ "$state" = off ]; then
    icon="$ICON_BT_OFF"
    color="$RED"
  elif [ "$count" -gt 0 ]; then
    icon="$ICON_BT_CONNECTED"
    color="$ICON_BLUE"
  else
    icon="$ICON_BT"
    color="$GREY"
  fi

  sketchybar --set "$NAME" icon="$icon" icon.color="$color"
}

case "${1:-update}" in
  list) list ;;
  scan) scan; notify ;;
  toggle)
    if [ -n "$BLUEUTIL" ]; then
      [ "$(power_state)" = on ] && "$BLUEUTIL" -p 0 || "$BLUEUTIL" -p 1
      sleep 1
      update
      notify
    else
      open "x-apple.systempreferences:com.apple.BluetoothSettings"
    fi
    ;;
  connect | disconnect)
    # Address shape enforced before it reaches blueutil: it arrives from a click_script string.
    case "${2:-}" in '' | *[!0-9A-Fa-f:-]*) exit 0 ;; esac
    if [ -n "$BLUEUTIL" ]; then
      "$BLUEUTIL" "--$1" "$2" >/dev/null 2>&1
      sleep 1
      update
      notify
    else
      open "x-apple.systempreferences:com.apple.BluetoothSettings"
    fi
    ;;
  *) update ;;
esac
