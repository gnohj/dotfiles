#!/bin/bash
# Wi-Fi panel backend: cached sampling on a timer, fast row emission on popup open, plus the actions.
#
#   wifi-panel.sh sample        # slow probes (ping, system_profiler) -> cache; runs on the routine
#   wifi-panel.sh list          # TSV rows for the popup, reads the cache for anything slow
#   wifi-panel.sh toggle        # Wi-Fi power
#   wifi-panel.sh dns <preset>  # dhcp | cloudflare | google
#   wifi-panel.sh join <ssid>   # re-join a known network
#
# The SSID is derived, not read: every API redacts it without Location Services, so the interface's
# private MAC is matched against CachedPrivateMACAddress (see nix-darwin/modules/wifi-ssid-sudoers.nix).

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.wifi}"
IFACE="${WIFI_IFACE:-en0}"
SERVICE="${WIFI_SERVICE:-Wi-Fi}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/wifi_panel"
KNOWN_LIMIT=8
mkdir -p "$(dirname "$CACHE")"

cache_get() { [ -f "$CACHE" ] && awk -F'=' -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$CACHE"; }

human_bytes() {
  awk -v b="${1:-0}" 'BEGIN {
    split("B KB MB GB TB", u, " ")
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i]
  }'
}

KNOWN_NETWORKS_PLIST=/Library/Preferences/com.apple.wifi.known-networks.plist

# sudo -n so a missing rule fails instantly instead of blocking the sample on a password prompt.
current_ssid() {
  local mac
  mac="$(ifconfig "$IFACE" 2>/dev/null | awk '/ether/ { print $2; exit }')"
  [ -n "$mac" ] || return 0
  sudo -n /usr/bin/plutil -p "$KNOWN_NETWORKS_PLIST" 2>/dev/null |
    awk -v mac="$mac" '
      /^  "wifi\.network\.ssid\./ {
        name = $0
        sub(/^  "wifi\.network\.ssid\./, "", name)
        sub(/" => \{$/, "", name)
      }
      index($0, "\"CachedPrivateMACAddress\" => \"" mac "\"") { print name; exit }
    '
}

power_state() {
  case "$(networksetup -getairportpower "$IFACE" 2>/dev/null)" in
    *": On") echo on ;;
    *) echo off ;;
  esac
}

# Everything slow lives here so `list` never blocks the popup: ping costs ~2s and system_profiler ~5s.
sample() {
  local ping_out avg loss air channel signal ssid now bytes rx tx prev_now prev_rx prev_tx rx_rate tx_rate

  ping_out="$(ping -c 3 -t 4 1.1.1.1 2>/dev/null)"
  avg="$(printf '%s' "$ping_out" | awk -F'/' '/round-trip/ { printf "%.1f", $5 }')"
  loss="$(printf '%s' "$ping_out" | awk -F'[,%]' '/packet loss/ { gsub(/[^0-9.]/, "", $3); print $3 }')"

  air="$(system_profiler SPAirPortDataType 2>/dev/null | sed -n '/Current Network Information/,/Other Local/p')"
  channel="$(printf '%s' "$air" | awk -F': ' '/Channel:/ { print $2; exit }')"
  signal="$(printf '%s' "$air" | awk -F': ' '/Signal \/ Noise:/ { split($2, s, " / "); print s[1]; exit }')"

  ssid="$(current_ssid)"

  now="$(date +%s)"
  bytes="$(netstat -ib -I "$IFACE" 2>/dev/null | awk 'NR > 1 { print $7, $10; exit }')"
  rx="${bytes% *}"
  tx="${bytes#* }"
  prev_now="$(cache_get sampled_at)"
  prev_rx="$(cache_get rx_total)"
  prev_tx="$(cache_get tx_total)"

  rx_rate=""
  tx_rate=""
  if [ -n "$prev_now" ] && [ -n "$prev_rx" ] && [ "$now" -gt "$prev_now" ] && [ "$rx" -ge "$prev_rx" ]; then
    rx_rate=$(((rx - prev_rx) / (now - prev_now)))
    tx_rate=$(((tx - prev_tx) / (now - prev_now)))
  fi

  cat >"$CACHE" <<EOF
sampled_at=$now
ssid=$ssid
ping=$avg
loss=$loss
channel=$channel
signal=$signal
rx_total=$rx
tx_total=$tx
rx_rate=$rx_rate
tx_rate=$tx_rate
EOF
}

# "132 (5GHz, 80MHz)" reads better as the band first - that is the part worth seeing at a glance.
format_band() {
  awk -v c="$1" 'BEGIN {
    if (c == "") { print ""; exit }
    n = c; sub(/ .*/, "", n)
    band = c; sub(/^[^(]*\(/, "", band); sub(/\).*/, "", band)
    split(band, p, ", ")
    printf "%s ch%s %s", p[1], n, p[2]
  }'
}

dns_preset() {
  case "$(networksetup -getdnsservers "$SERVICE" 2>/dev/null | tr '\n' ' ')" in
    "1.1.1.1 1.0.0.1 " | "1.1.1.1 ") echo cloudflare ;;
    "8.8.8.8 8.8.4.4 " | "8.8.8.8 ") echo google ;;
    *"aren't any DNS Servers"*) echo dhcp ;;
    *) echo custom ;;
  esac
}

row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# The join argument is shell-quoted HERE, never in Lua: an SSID is whatever a nearby AP broadcasts, and
# one containing a double quote would otherwise break out of the click_script and run as a command.
# Single-quoted rather than %q, which backslash-escapes every space - and a stored backslash makes
# `sketchybar --query` emit JSON that jq refuses to parse.
shquote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
row_network() { printf 'network\t%s\t%s\t%s\n' "$1" "$2" "$(shquote "$1")"; }

list() {
  local ping loss rx_rate tx_rate rx_total tx_total band signal current count connected

  row power "$(power_state)" "$(cache_get ssid)"

  ping="$(cache_get ping)"
  loss="$(cache_get loss)"
  row stat "Ping" "${ping:+$ping ms}"
  row stat "Packet Loss" "${loss:+$loss%}"

  rx_rate="$(cache_get rx_rate)"
  tx_rate="$(cache_get tx_rate)"
  row stat "Receiving" "${rx_rate:+$(human_bytes "$rx_rate")/s}"
  row stat "Sending" "${tx_rate:+$(human_bytes "$tx_rate")/s}"

  rx_total="$(cache_get rx_total)"
  tx_total="$(cache_get tx_total)"
  row stat "Downloaded" "${rx_total:+$(human_bytes "$rx_total")}"
  row stat "Uploaded" "${tx_total:+$(human_bytes "$tx_total")}"

  row stat "IP Address" "$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
  row stat "Gateway" "$(route -n get default 2>/dev/null | awk '/gateway/ { print $2; exit }')"

  band="$(format_band "$(cache_get channel)")"
  signal="$(cache_get signal)"
  row stat "Band" "$band"
  row stat "Signal" "$signal"

  current="$(dns_preset)"
  row dns "DHCP" "$([ "$current" = dhcp ] && echo active)"
  row dns "Cloudflare" "$([ "$current" = cloudflare ] && echo active)"
  row dns "Google" "$([ "$current" = google ] && echo active)"
  [ "$current" = custom ] && row dns "Custom" active

  # Capped so 33 preferred networks cannot bury the rows above; the connected one leads and is exempt.
  connected="$(cache_get ssid)"
  [ -n "$connected" ] && row_network "$connected" connected
  count=0
  while IFS= read -r ssid; do
    [ -n "$ssid" ] || continue
    [ "$ssid" = "$connected" ] && continue
    count=$((count + 1))
    [ "$count" -le "$KNOWN_LIMIT" ] && row_network "$ssid" ""
  done <<<"$(networksetup -listpreferredwirelessnetworks "$IFACE" 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//')"

  return 0
}

notify() { sketchybar --trigger wifi_refresh; }

case "${1:-list}" in
  sample) sample ;;
  list) list ;;
  toggle)
    [ "$(power_state)" = on ] && networksetup -setairportpower "$IFACE" off || networksetup -setairportpower "$IFACE" on
    sleep 1
    notify
    ;;
  dns)
    case "${2:-}" in
      dhcp) networksetup -setdnsservers "$SERVICE" Empty ;;
      cloudflare) networksetup -setdnsservers "$SERVICE" 1.1.1.1 1.0.0.1 ;;
      google) networksetup -setdnsservers "$SERVICE" 8.8.8.8 8.8.4.4 ;;
    esac
    notify
    ;;
  join)
    [ -n "${2:-}" ] && networksetup -setairportnetwork "$IFACE" "$2" >/dev/null 2>&1
    sleep 2
    notify
    ;;
esac
