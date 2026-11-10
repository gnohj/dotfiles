#!/bin/bash
# dev-box metrics as its own resource-watch recorder logged them, so bar and report cannot disagree.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"
VPS_COLOR="$BLUE"

# fleet-dev-box has no port forwards, so it never clashes with an interactive session.
while read -r name value tier; do
  if [ "$name" = uptime ]; then uptime="$value"
  elif [ "$name" = cpu ]; then cpu="$value" cpu_tier="$tier"
  elif [ "$name" = memory ]; then mem="$value" mem_tier="$tier"
  elif [ "$name" = disk ]; then disk="$value" disk_tier="$tier"
  elif [ "$name" = temp ]; then temp="$value" temp_tier="$tier"
  fi
done < <(ssh -o BatchMode=yes -o ConnectTimeout=4 -o ServerAliveInterval=2 -o ServerAliveCountMax=2 fleet-dev-box \
  '/usr/bin/python3 ~/.local/bin/resource-watch beat; echo "uptime $(cut -d. -f1 /proc/uptime)"' 2>/dev/null)

# colour05 is the Lua yellow, which colors.sh has no name for.
tier_color() {
  if [ "$1" = 3 ]; then echo "$RED"
  elif [ "$1" = 2 ]; then echo "$ORANGE"
  elif [ "$1" = 1 ]; then echo "0xff${gnohj_color05#\#}"
  fi
}

temp_color=""
if [[ "$temp" =~ ^[0-9]+$ ]]; then
  temp_color=$(tier_color "$temp_tier")
  temp_label="${temp}°"
else
  temp_label="--°"
fi

uptime_label="--"
if [[ "$uptime" =~ ^[0-9]+$ ]]; then
  days=$(( uptime / 86400 ))
  uptime_label=$(printf '%02dd' $(( days > 999 ? 999 : days )))
fi

if [[ "$cpu" =~ ^[0-9]+$ && "$mem" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ ]]; then
  cpu=$((10#$cpu)) mem=$((10#$mem)) disk=$((10#$disk))
  cpu_color=$(tier_color "$cpu_tier") mem_color=$(tier_color "$mem_tier") disk_color=$(tier_color "$disk_tier")
  sketchybar --set widgets.vps_uptime label="$uptime_label" \
             --set widgets.vps_cpu label="${cpu}%  " icon.color="${cpu_color:-$ICON_BLUE}" label.color="${cpu_color:-$VPS_COLOR}" \
             --set widgets.vps_memory label="${mem}%  " icon.color="${mem_color:-$ICON_BLUE}" label.color="${mem_color:-$VPS_COLOR}" \
             --set widgets.vps_disk label="${disk}%  " icon.color="${disk_color:-$ICON_BLUE}" label.color="${disk_color:-$VPS_COLOR}" \
             --set widgets.vps_temp label="$temp_label" icon.color="${temp_color:-$ICON_BLUE}" label.color="${temp_color:-$VPS_COLOR}" \
             --trigger group_refresh
else
  sketchybar --set widgets.vps_uptime label="$uptime_label" \
             --set widgets.vps_cpu label="--" icon.color="$ICON_BLUE" label.color="$GREY" \
             --set widgets.vps_memory label="--" icon.color="$ICON_BLUE" label.color="$GREY" \
             --set widgets.vps_disk label="--" icon.color="$ICON_BLUE" label.color="$GREY" \
             --set widgets.vps_temp label="--°" icon.color="$ICON_BLUE" label.color="$GREY" \
             --trigger group_refresh
fi
