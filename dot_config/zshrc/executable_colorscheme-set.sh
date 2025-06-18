#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display error messages
error() {
  echo "Error: $1" >&2
  exit 1
}

# Ensure a colorscheme profile is provided
if [ -z "$1" ]; then
  error "No colorscheme profile provided"
fi

colorscheme_profile="$1"

# Define paths
colorscheme_file="$HOME/.config/colorscheme/list/$colorscheme_profile"
active_file="$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Check if the colorscheme file exists
if [ ! -f "$colorscheme_file" ]; then
  error "Colorscheme file '$colorscheme_file' does not exist."
fi

# If active-colorscheme.sh doesn't exist, create it
if [ ! -f "$active_file" ]; then
  echo "Active colorscheme file not found. Creating '$active_file'."
  cp "$colorscheme_file" "$active_file"
  UPDATED=true
else
  # Compare the new colorscheme with the active one
  if ! diff -q "$active_file" "$colorscheme_file" >/dev/null; then
    UPDATED=true
  else
    UPDATED=false
  fi
fi

generate_ghostty_theme() {
  ghostty_conf_file="$HOME/.config/ghostty/ghostty-theme"

  cat >"$ghostty_conf_file" <<EOF
# Auto-generated ghostty configuration
background = $gnohj_color10
foreground = $gnohj_color14

cursor-color = $gnohj_color24

# black
palette = 0=$gnohj_color10
palette = 8=$gnohj_color08
# red
palette = 1=$gnohj_color11
palette = 9=$gnohj_color11
# green
palette = 2=$gnohj_color02
palette = 10=$gnohj_color02
# yellow
palette = 3=$gnohj_color05
palette = 11=$gnohj_color05
# blue
palette = 4=$gnohj_color04
palette = 12=$gnohj_color04
# purple
palette = 5=$gnohj_color01
palette = 13=$gnohj_color01
# aqua
palette = 6=$gnohj_color03
palette = 14=$gnohj_color03
# white
palette = 7=$gnohj_color14
palette = 15=$gnohj_color14
EOF

  echo "Ghostty configuration updated at '$ghostty_conf_file'."
}

generate_btop_theme() {
  btop_conf_file="$HOME/.config/btop/themes/btop-theme.theme"

  cat >"$btop_conf_file" <<EOF

# Auto-generated btop theme configuration
# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]=""

# Main text color
theme[main_fg]="$gnohj_color14"

# Title color for boxes
theme[title]="$gnohj_color14"

# Highlight color for keyboard shortcuts
theme[hi_fg]="$gnohj_color02"

# Background color of selected item in processes box
theme[selected_bg]="$gnohj_color04"

# Foreground color of selected item in processes box
theme[selected_fg]="$gnohj_color14"

# Color of inactive/disabled text
theme[inactive_fg]="$gnohj_color09"

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="$gnohj_color14"

# Background color of the percentage meters
theme[meter_bg]="$gnohj_color17"

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="$gnohj_color01"

# Cpu box outline color
theme[cpu_box]="$gnohj_color04"

# Memory/disks box outline color
theme[mem_box]="$gnohj_color02"

# Net up/down box outline color
theme[net_box]="$gnohj_color03"

# Processes box outline color
theme[proc_box]="$gnohj_color05"

# Box divider line and small boxes line color
theme[div_line]="$gnohj_color17"

# Temperature graph colors
theme[temp_start]="$gnohj_color01"
theme[temp_mid]="$gnohj_color16"
theme[temp_end]="$gnohj_color06"

# CPU graph colors
theme[cpu_start]="$gnohj_color01"
theme[cpu_mid]="$gnohj_color05"
theme[cpu_end]="$gnohj_color02"

# Mem/Disk free meter
theme[free_start]="$gnohj_color18"
theme[free_mid]="$gnohj_color16"
theme[free_end]="$gnohj_color06"

# Mem/Disk cached meter
theme[cached_start]="$gnohj_color03"
theme[cached_mid]="$gnohj_color05"
theme[cached_end]="$gnohj_color08"

# Mem/Disk available meter
theme[available_start]="$gnohj_color21"
theme[available_mid]="$gnohj_color01"
theme[available_end]="$gnohj_color04"

# Mem/Disk used meter
theme[used_start]="$gnohj_color19"
theme[used_mid]="$gnohj_color05"
theme[used_end]="$gnohj_color02"

# Download graph colors
theme[download_start]="$gnohj_color01"
theme[download_mid]="$gnohj_color02"
theme[download_end]="$gnohj_color05"

# Upload graph colors
theme[upload_start]="$gnohj_color08"
theme[upload_mid]="$gnohj_color16"
theme[upload_end]="$gnohj_color06"

# Process box color gradient for threads, mem and cpu usage
theme[process_start]="$gnohj_color03"
theme[process_mid]="$gnohj_color02"
theme[process_end]="$gnohj_color06"
EOF

  echo "Btop theme updated at '$btop_conf_file'."
}

generate_starship_config() {
  # Define the paths
  starship_conf_file="$HOME/.config/starship/starship.toml"
  starship_radioctl_conf_file="$HOME/.config/starship/starship-radioctl.toml"

  # Generate the main Starship configuration file
  cat >"$starship_conf_file" <<EOF
#
# ███████╗████████╗ █████╗ ██████╗ ███████╗██╗  ██╗██╗██████╗
# ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔══██╗
# ███████╗   ██║   ███████║██████╔╝███████╗███████║██║██████╔╝
# ╚════██║   ██║   ██╔══██║██╔══██╗╚════██║██╔══██║██║██╔═══╝
# ███████║   ██║   ██║  ██║██║  ██║███████║██║  ██║██║██║
# ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝
# The minimal, blazing-fast, and infinitely customizable prompt
# Auto-generated starship config
# https://starship.rs
"\$schema" = 'https://starship.rs/config-schema.json'
format = '''
\$directory\$git_branch\$git_status\$cmd_duration\${custom.bitwarden}
[﬌](bold green) 
'''
# [username]
# style_user = "green bold"
# style_root = "red bold"
# format = "[\$user](\$style) "
# disabled = false
# show_always = false
# configure directory
[directory]
read_only = " "
truncation_length = 10
truncate_to_repo = true    # truncates directory to root folder if in github repo
style = "bold italic blue"
[git_branch]
style = "bold ${gnohj_color03}"
[package]
display_private = true
[cmd_duration]
min_time = 4
show_milliseconds = false
disabled = false
format = '[\$duration](bold italic ${gnohj_color02})'
[env_var.RADIO_CTL]
default = ''
variable = "RADIO_CTL"
format = "[\$symbol(\$env_value)](yellow dimmed)"
[custom.bitwarden]
description = "Output the current Bitwarden vault status."
command = 'echo \$(rbw unlocked >/dev/null 2>&1 && echo "" || echo "🔒")'
format = "[\$symbol( \$output)](\$style)"
when = 'command -v rbw'

EOF

  # Generate the radio control Starship configuration file
  cat >"$starship_radioctl_conf_file" <<EOF
#
# ███████╗████████╗ █████╗ ██████╗ ███████╗██╗  ██╗██╗██████╗
# ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔══██╗
# ███████╗   ██║   ███████║██████╔╝███████╗███████║██║██████╔╝
# ╚════██║   ██║   ██╔══██║██╔══██╗╚════██║██╔══██║██║██╔═══╝
# ███████║   ██║   ██║  ██║██║  ██║███████║██║  ██║██║██║
# ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝
# The minimal, blazing-fast, and infinitely customizable prompt
# Auto-generated starship config for radio control
# https://starship.rs
"\$schema" = 'https://starship.rs/config-schema.json'
format = '''
(\${env_var.RADIO_CTL})
\$directory\$git_branch\$git_status\$cmd_duration\${custom.bitwarden}
[﬌](bold green) 
'''
# [username]
# style_user = "green bold"
# style_root = "red bold"
# format = "[\$user](\$style) "
# disabled = false
# show_always = false
# configure directory
[directory]
read_only = " "
truncation_length = 10
truncate_to_repo = true    # truncates directory to root folder if in github repo
style = "bold italic blue"
[git_branch]
style = "bold ${gnohj_color03}"
[package]
display_private = true
[cmd_duration]
min_time = 4
show_milliseconds = false
disabled = false
format = '[\$duration](bold italic ${gnohj_color02})'
[env_var.RADIO_CTL]
default = ''
variable = "RADIO_CTL"
format = "[\$symbol(\$env_value)](yellow dimmed)"
[custom.bitwarden]
description = "Output the current Bitwarden vault status."
command = 'echo \$(rbw unlocked >/dev/null 2>&1 && echo "" || echo "🔒")'
format = "[\$symbol( \$output)](\$style)"
when = 'command -v rbw'
EOF

  echo "Starship configuration updated at '$starship_conf_file'."
  echo "Starship radio control configuration updated at '$starship_radioctl_conf_file'."
}

generate_lazygit_config() {
  lazygit_conf_file="$HOME/.config/lazygit/config.yml"

  cat >"$lazygit_conf_file" <<EOF
# LazyGit configuration with custom colors
# Auto-generated lazygit config
notARepository: "quit"
quitOnTopLevelReturn: true
git:
  overrideGpg: true
os:
  editPreset: nvim
gui:
  showBottomLine: false
  theme:
    activeBorderColor:
      - "${gnohj_color03}"
    selectedLineBgColor:
      - "${gnohj_color16}"
    unstagedChangesColor:
      - "${gnohj_color12}"
  border: rounded
  nerdFontsVersion: "3"
customCommands:
  - key: "x"
    description: "Commit and bypass hooks"
    prompts:
      - type: "input"
        title: "Commit and bypass hooks"
        initialValue: ""
    command: HUSKY=0 git commit -m "{{index .PromptResponses 0}}" --no-verify
    context: "global"
    subprocess: yes

  - key: "X"
    description: "Amend last commit and bypass hooks"
    command: "HUSKY=0 git commit --amend --date=now --no-edit"
    context: "global"
    subprocess: yes

  - key: "z"
    description: "Stash commit and bypass hooks"
    command: "HUSKY=0 git stash --no-verify"
    context: "global"
    subprocess: yes
EOF
}

generate_bat_config() {
  bat_config_dir="$HOME/.config/bat"
  bat_themes_dir="$bat_config_dir/themes"
  bat_config_file="$bat_config_dir/config"
  bat_theme_file="$bat_themes_dir/gnohj-theme.tmTheme"

  # Create directories
  mkdir -p "$bat_themes_dir"

  # Generate the bat theme file (based on your plist structure)
  cat >"$bat_theme_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>author</key>
  <string>Auto-Generated bat theme</string>
  <key>name</key>
  <string>gnohj-theme</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key>
        <string>$gnohj_color10</string>
        <key>foreground</key>
        <string>$gnohj_color14</string>
        <key>caret</key>
        <string>$gnohj_color24</string>
        <key>selection</key>
        <string>$gnohj_color16</string>
        <key>lineHighlight</key>
        <string>$gnohj_color13</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Comment</string>
      <key>scope</key>
      <string>comment</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$gnohj_color09</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>String</string>
      <key>scope</key>
      <string>string</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$gnohj_color02</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Keyword</string>
      <key>scope</key>
      <string>keyword</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$gnohj_color04</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Function</string>
      <key>scope</key>
      <string>entity.name.function</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$gnohj_color03</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF

  # Generate the bat config file
  cat >"$bat_config_file" <<EOF
# ██████╗  █████╗ ████████╗
# ██╔══██╗██╔══██╗╚══██╔══╝
# ██████╔╝███████║   ██║
# ██╔══██╗██╔══██║   ██║
# ██████╔╝██║  ██║   ██║
# ╚═════╝ ╚═╝  ╚═╝   ╚═╝
# A cat(1) clone with wings.
# https://github.com/sharkdp/bat
# Auto-generated bat config
--theme="gnohj-theme"
EOF

  # Rebuild bat cache to include the new theme
  bat cache --build >/dev/null 2>&1

  echo "Bat configuration updated with theme 'gnohj-theme'."
}

generate_borders_config() {
  borders_script="$HOME/.config/borders/bordersrc"

  # Generate the borders configuration script
  cat >"$borders_script" <<EOF
#!/bin/bash
# Auto-generated borders config
options=(
  style=round
  width=2.5
  hidpi=off
  active_color=0xff${gnohj_color03#\#}
  inactive_color=0x33${gnohj_color09#\#}
)
borders "\${options[@]}"
EOF

  chmod +x "$borders_script"
  echo "Borders configuration updated at '$borders_script'."

  echo "Stopping borders... auto restarting with new colors."
  pkill -f "/opt/homebrew/opt/borders/bin/borders" 2>/dev/null || true
  # sleep 1

  # # Force kill if still running
  # if pgrep -f "/opt/homebrew/opt/borders/bin/borders" >/dev/null; then
  #   echo "Force killing borders..."
  #   pkill -9 -f "/opt/homebrew/opt/borders/bin/borders" 2>/dev/null || true
  #   sleep 1
  # fi

  # Restart borders with new configuration
  # echo "Starting borders with new colors..."
  # "$borders_script" &
  # echo "Borders restarted with new colors."
}

# If there's an update, replace the active colorscheme and perform necessary actions
if [ "$UPDATED" = true ]; then
  echo "Updating active colorscheme to '$colorscheme_profile'."

  # Replace the contents of active-colorscheme.sh
  cp "$colorscheme_file" "$active_file"

  cp "$colorscheme_file" "$HOME/.config/nvim/lua/config/active-colorscheme.sh"

  # Source the active colorscheme to load variables
  source "$active_file"

  # Set the tmux colors
  "$HOME/.config/tmux/set_tmux_colors.sh"
  tmux source-file ~/.config/tmux/tmux.conf
  echo "Tmux colors set and tmux configuration reloaded."

  # Reload sketchybar - reads active-colorscheme.sh on load
  sketchybar --reload

  # Generate starsihp config files, think it reloads automatically?
  generate_starship_config

  # Generate lazygit config
  generate_lazygit_config

  # Generate the ghostty theme file, then reload config
  generate_ghostty_theme
  osascript "$HOME/.config/ghostty/reload-config.scpt"

  # Generate the btop theme
  generate_btop_theme
  # Generate bat config
  generate_bat_config

  # Generate borders config
  generate_borders_config

  # Set the wallpaper
  if [ -z "$wallpaper" ]; then
    wallpaper="$HOME/Pictures/wallpapers/yes.png"
  fi
  osascript -e '
  tell application "System Events"
      repeat with d in desktops
          set picture of d to "'"$wallpaper"'"
      end repeat
  end tell'
fi
