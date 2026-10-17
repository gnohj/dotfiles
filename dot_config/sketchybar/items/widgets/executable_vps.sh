#!/bin/bash
# dev-box CPU, memory, disk and temperature from the box's own herdr-sysinfo.py, so the bar and the herdr sidebar can never disagree.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"
VPS_COLOR="$WHITE"

# fleet-dev-box has no port forwards, so it never clashes with an interactive session.
read -r cpu mem disk temp < <(ssh -o BatchMode=yes -o ConnectTimeout=4 -o ServerAliveInterval=2 -o ServerAliveCountMax=2 fleet-dev-box \
  'HERDR_SYSINFO_RES="{cpu} {memp} {disk} {temp}" HERDR_REPOS_FORMAT= HERDR_SYNC_FORMAT= ~/.local/bin/mux/herdr/herdr-sysinfo.py --print' 2>/dev/null | sed -n 2p)

cpu="${cpu%\%}" mem="${mem%\%}" disk="${disk%\%}" temp="${temp%°}"

# Same steps as cpu_temp.lua but resting on the VPS glyph colour; colour05 is the Lua yellow, which colors.sh has no name for.
temp_color="$VPS_COLOR"
if [[ "$temp" =~ ^[0-9]+$ ]]; then
  if (( temp >= 90 )); then temp_color="$RED"
  elif (( temp >= 80 )); then temp_color="$ORANGE"
  elif (( temp >= 65 )); then temp_color="0xff${gnohj_color05#\#}"
  fi
  temp_label="${temp}°"
else
  temp_label="--°"
fi

# Same tiers as lib/tiers.lua: cpu warns from 60/75/90, memory from 70/80/90, disk from 50/75.
tier() {
  if (( $1 >= $4 )); then echo "$RED"
  elif (( $1 >= $3 )); then echo "$ORANGE"
  elif (( $1 >= $2 )); then echo "0xff${gnohj_color05#\#}"
  else echo "$VPS_COLOR"
  fi
}

disk_tier() {
  if (( $1 >= 75 )); then echo "$RED"
  elif (( $1 >= 50 )); then echo "$ORANGE"
  else echo "$VPS_COLOR"
  fi
}

if [[ "$cpu" =~ ^[0-9]+$ && "$mem" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ ]]; then
  cpu=$((10#$cpu)) mem=$((10#$mem)) disk=$((10#$disk))
  sketchybar --set widgets.vps_cpu label="${cpu}%  " label.color="$(tier "$cpu" 60 75 90)" \
             --set widgets.vps_memory label="${mem}%  " label.color="$(tier "$mem" 70 80 90)" \
             --set widgets.vps_disk label="${disk}%  " label.color="$(disk_tier "$disk")" \
             --set widgets.vps_temp label="$temp_label" label.color="$temp_color"
else
  sketchybar --set widgets.vps_cpu label="--" label.color="$GREY" \
             --set widgets.vps_memory label="--" label.color="$GREY" \
             --set widgets.vps_disk label="--" label.color="$GREY" \
             --set widgets.vps_temp label="--°" label.color="$GREY"
fi
