#!/bin/bash
# dev-box CPU + memory from the box's own herdr-sysinfo.py, so the bar and the herdr sidebar can never disagree.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

# fleet-dev-box has no port forwards, so it never clashes with an interactive session.
read -r cpu mem < <(ssh -o BatchMode=yes -o ConnectTimeout=4 -o ServerAliveInterval=2 -o ServerAliveCountMax=2 fleet-dev-box \
  'HERDR_SYSINFO_RES="{cpu} {memp}" HERDR_REPOS_FORMAT= HERDR_SYNC_FORMAT= ~/.local/bin/mux/herdr/herdr-sysinfo.py --print' 2>/dev/null | sed -n 2p)

cpu="${cpu%\%}" mem="${mem%\%}"
if [[ "$cpu" =~ ^[0-9]+$ && "$mem" =~ ^[0-9]+$ ]]; then
  sketchybar --set widgets.vps_cpu label="$((10#$cpu))%  " label.color="$GREEN" \
             --set widgets.vps_memory label="$((10#$mem))%  " label.color="$GREEN"
else
  sketchybar --set widgets.vps_cpu label="--" label.color="$GREY" \
             --set widgets.vps_memory label="--" label.color="$GREY"
fi
