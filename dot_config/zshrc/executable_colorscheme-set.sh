#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure Homebrew is in PATH
export PATH="/opt/homebrew/bin:$PATH"

# Nix packages (bat) are in PATH via nix-daemon.sh

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

generate_kitty_theme() {
  kitty_conf_file="$HOME/.config/kitty/kitty-theme.conf"
  temp_file=$(mktemp)

  cat >"$temp_file" <<EOF
# Auto-generated kitty theme configuration
background $gnohj_color10
foreground $gnohj_color14

cursor $gnohj_color24

# black
color0 $gnohj_color10
color8 $gnohj_color08
# red
color1 $gnohj_color11
color9 $gnohj_color11
# green
color2 $gnohj_color02
color10 $gnohj_color02
# yellow
color3 $gnohj_color05
color11 $gnohj_color05
# blue
color4 $gnohj_color04
color12 $gnohj_color04
# purple
color5 $gnohj_color01
color13 $gnohj_color01
# aqua
color6 $gnohj_color03
color14 $gnohj_color03
# white
color7 $gnohj_color14
color15 $gnohj_color14

# Selection colors
selection_foreground $gnohj_color10
selection_background $gnohj_color04

# Tab bar colors
active_tab_foreground $gnohj_color10
active_tab_background $gnohj_color02
inactive_tab_foreground $gnohj_color14
inactive_tab_background $gnohj_color08

# Border colors
active_border_color $gnohj_color04
inactive_border_color $gnohj_color08
EOF

  # Move temp file to final location (atomically)
  mv -f "$temp_file" "$kitty_conf_file"

  # Remove macOS extended attributes that trigger file opening
  xattr -c "$kitty_conf_file" 2>/dev/null || true

  # Send SIGUSR1 to kitty to reload config
  pkill -USR1 -x kitty 2>/dev/null || true
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
  starship_infra_conf_file="$HOME/.config/starship/starship-infra.toml"

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
\$directory\$cmd_duration[❯](bold ${gnohj_color02}) 
'''
right_format = ""
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
truncate_to_repo = true       # truncates directory to root folder if in github repo
style = "bold italic ${gnohj_color04}"
[git_branch]
style = "bold ${gnohj_color06}"
[package]
display_private = true
[cmd_duration]
min_time = 4000
show_milliseconds = false
disabled = false
format = '[\$duration ](bold italic ${gnohj_color02})'
[git_status]
disabled = true
[git_commit]
disabled = true
EOF

  # Generate the infrastructure Starship configuration file
  cat >"$starship_infra_conf_file" <<EOF

#
# ███████╗████████╗ █████╗ ██████╗ ███████╗██╗  ██╗██╗██████╗
# ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔══██╗
# ███████╗   ██║   ███████║██████╔╝███████╗███████║██║██████╔╝
# ╚════██║   ██║   ██╔══██║██╔══██╗╚════██║██╔══██║██║██╔═══╝
# ███████║   ██║   ██║  ██║██║  ██║███████║██║  ██║██║██║
# ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝
# The minimal, blazing-fast, and infinitely customizable prompt - Infrastructure variant
# Auto-generated starship config for infrastructure repos
# https://starship.rs
"\$schema" = 'https://starship.rs/config-schema.json'
format = '''
\${env_var.RADIO_CTL}
\${env_var.AWS_PROFILE}
\$directory\$cmd_duration[❯ ](bold ${gnohj_color02})
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
truncate_to_repo = true       # truncates directory to root folder if in github repo
style = "bold italic ${gnohj_color04}"
[git_branch]
style = "bold ${gnohj_color06}"
[package]
display_private = true
[cmd_duration]
min_time = 4000
show_milliseconds = false
disabled = false
format = '[\$duration ](bold italic ${gnohj_color02})'
[env_var.AWS_PROFILE]
default = ''
variable = "AWS_PROFILE"
format = '[\\[aws:\$env_value\\] ](\$style)'
style = 'bold ${gnohj_color03}'
[env_var.RADIO_CTL]
default = ''
variable = "RADIO_CTL"
format = "[\$symbol(\$env_value)](bold ${gnohj_color05})"
[git_status]
disabled = true
[git_commit]
disabled = true
EOF

  echo "Starship configuration updated at '$starship_conf_file'."
  echo "Starship infrastructure configuration updated at '$starship_infra_conf_file'."
}

generate_lazygit_config() {
  lazygit_conf_file="$HOME/.config/lazygit/config.yml"

  cat >"$lazygit_conf_file" <<EOF
# LazyGit configuration with custom colors
# Auto-generated lazygit config
# https://github.com/aidancz/lazygit/blob/master/docs/Config.md
showRandomTip: false
notARepository: "quit"
quitOnTopLevelReturn: true
git:
  overrideGpg: true
  paging:
    colorArg: always
    pager: delta --dark --paging=never
os:
  editPreset: nvim
gui:
  showBottomLine: false
  theme:
    activeBorderColor:
      - "${gnohj_color02}"
      - bold
    inactiveBorderColor:
      - "${gnohj_color04}"
    selectedLineBgColor:
      - "${gnohj_color13}"
    unstagedChangesColor:
      - "${gnohj_color06}"
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

  - key: "<c-g>"
    prompts:
      - type: "menuFromCommand"
        title: "AI Commit"
        key: "Msg"
        command: "aic generate"
    command: git commit -m "{{.Form.Msg}}"
    context: "files"
    description: "Generate commit message with AI"

  - key: "<c-a>"
    prompts:
      - type: "menuFromCommand"
        title: "AI Commit (Gitmoji)"
        key: "Msg"
        command: "aic-gitmoji.sh"
    command: git commit -m "{{.Form.Msg}}"
    context: "files"
    description: "Generate commit message with gitmoji"

  - key: "<c-p>"
    command: gh pr create --draft --editor --assignee @me --reviewer iheartradio/web-engineers
    loadingText: "Creating draft PR..."
    context: "global"
    subprocess: yes
    description: "Create draft PR with editor (assigned to you, reviewer} iheartradio/web-engineers"
EOF
}

generate_lazydocker_config() {
  lazydocker_conf_dir="$HOME/.config/lazydocker"
  lazydocker_conf_file="$lazydocker_conf_dir/config.yml"

  # Create directory if it doesn't exist
  mkdir -p "$lazydocker_conf_dir"

  cat >"$lazydocker_conf_file" <<EOF
# LazyDocker configuration with custom colors
# Auto-generated lazydocker config
# Docs: https://github.com/jesseduffield/lazydocker/blob/master/docs/Config.md
gui:
  scrollHeight: 2
  language: 'en'
  theme:
    activeBorderColor:
      - '${gnohj_color02}'
      - bold
    inactiveBorderColor:
      - '${gnohj_color03}'
    selectedLineBgColor:
      - '${gnohj_color49}'
    optionsTextColor:
      - '${gnohj_color03}'
  border: rounded
  showAllContainers: false
  returnImmediately: false
  wrapMainPanel: true
reporting: 'off'
confirmOnQuit: false
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
  width=5
  hidpi=on
  active_color=0xff${gnohj_color03#\#}
  inactive_color=0x33${gnohj_color09#\#}
  blacklist="alacritty,Alacritty"
)
/opt/homebrew/bin/borders "\${options[@]}"
EOF

  chmod +x "$borders_script"
  echo "Borders configuration updated at '$borders_script'."

  # Ensure file is flushed to disk before restarting
  sync

  echo "Stopping borders... auto restarting with new colors."
  pkill -f "/opt/homebrew/bin/borders" 2>/dev/null || true

  # Wait for borders to restart via LaunchAgent (max 3 seconds)
  for i in {1..6}; do
    sleep 0.5
    if pgrep -f "/opt/homebrew/bin/borders" >/dev/null 2>&1; then
      echo "Borders restarted successfully."
      # Force borders to render by triggering window focus
      # Get current focused window and refocus it to trigger borders redraw
      /opt/homebrew/bin/aerospace list-windows --focused --format '%{window-id}' | head -1 | xargs -I {} /opt/homebrew/bin/aerospace focus --window-id {} 2>/dev/null || true
      break
    fi
  done

  # Restart borders with new configuration
  # echo "Starting borders with new colors..."
  # "$borders_script" &
  # echo "Borders restarted with new colors."
}

generate_delta_config() {
  delta_themes_file="$HOME/.config/delta/themes/themes.gitconfig"

  # Create the directory if it doesn't exist
  mkdir -p "$(dirname "$delta_themes_file")"

  cat >"$delta_themes_file" <<EOF
# Auto-generated delta themes configuration

[delta "gnohj-theme"]
	blame-palette = "$gnohj_color10 $gnohj_color07 $gnohj_color13 $gnohj_color16 $gnohj_color08"
	commit-decoration-style = box ul
	dark = true
	file-decoration-style = "$gnohj_color14"
	file-style = "$gnohj_color14"
	hunk-header-decoration-style = box ul
	hunk-header-file-style = bold
	hunk-header-line-number-style = bold "$gnohj_color09"
	hunk-header-style = file line-number syntax
	line-numbers-left-style = "$gnohj_color09"
	line-numbers-minus-style = bold "$gnohj_color11"
	line-numbers-plus-style = bold "$gnohj_color02"
	line-numbers-right-style = "$gnohj_color09"
	line-numbers-zero-style = "$gnohj_color09"
	# Much more visible red for deletions
	minus-emph-style = bold syntax "#4a1f2a"
	minus-style = syntax "#2a1319"
	# Much more visible green for additions
	plus-emph-style = bold syntax "#1f4a2a"
	plus-style = syntax "#132a19"
	map-styles = \\
		bold purple => syntax "$gnohj_color16", \\
		bold blue => syntax "$gnohj_color17", \\
		bold cyan => syntax "$gnohj_color13", \\
		bold yellow => syntax "$gnohj_color07"
	# Should match the name of the bat theme
	syntax-theme = gnohj-theme
EOF
  echo "Delta themes configuration updated at '$delta_themes_file'."
}

generate_yazi_theme() {
  yazi_theme_file="$HOME/.config/yazi/theme.toml"

  cat >"$yazi_theme_file" <<EOF
# Yazi theme configuration
# Auto-generated yazi theme - Gnohj color scheme
# Docs: https://yazi-rs.github.io/docs/configuration/theme
"\$schema" = "https://yazi-rs.github.io/schemas/theme.json"

[mgr]
# current working dir
cwd = { fg = "$gnohj_color02" }

# Hovered
hovered         = { reversed = true }
preview_hovered = { underline = true }

# find
find_keyword = { fg = "$gnohj_color03", bold = true, italic = true, underline = true }
find_position = { fg = "$gnohj_color03", bold = true, italic = true }

# Symlink
symlink_target = { italic = true }

# marker
marker_copied = { fg = "$gnohj_color10", bg = "$gnohj_color02" }
marker_cut = { fg = "$gnohj_color10", bg = "$gnohj_color11" }
marker_marked = { fg = "$gnohj_color10", bg = "$gnohj_color03" }
marker_selected = { fg = "$gnohj_color10", bg = "$gnohj_color05" }

# count
count_copied = { fg = "$gnohj_color10", bg = "$gnohj_color02" }
count_cut = { fg = "$gnohj_color09", bg = "$gnohj_color11" }
count_selected = { fg = "$gnohj_color10", bg = "$gnohj_color05" }

# border
border_symbol = "│"
border_style = { fg = "$gnohj_color03" }

[tabs]
active   = { fg = "$gnohj_color10", bg = "$gnohj_color02", bold = true }
inactive   = { fg = "$gnohj_color02", bg = "$gnohj_color10" }
sep_inner = { open = "", close = "" }
sep_outer = { open = "", close = "" }

[mode]
normal_main = { fg = "$gnohj_color10", bg = "$gnohj_color02", bold = true }
normal_alt = { fg = "$gnohj_color03", bg = "$gnohj_color17", bold = true }

select_main = { fg = "$gnohj_color10", bg = "$gnohj_color03", bold = true }
select_alt = { fg = "$gnohj_color10", bg = "$gnohj_color03", bold = true }

unset_main = { fg = "$gnohj_color10", bg = "$gnohj_color11", bold = true }
unset_alt = { fg = "$gnohj_color10", bg = "$gnohj_color11", bold = true }

[status]
overall   = {}
sep_left  = { open = "", close = "" }
sep_right = { open = "", close = "" }

# Progress
progress_label = { fg = "$gnohj_color10", bold = true }
progress_normal = { fg = "$gnohj_color02", bg = "$gnohj_color10" }
progress_error = { fg = "$gnohj_color11", bg = "$gnohj_color10" }

# permissions
perm_type = { fg = "$gnohj_color14" }
perm_write = { fg = "$gnohj_color11" }
perm_exec = { fg = "$gnohj_color02" }
perm_read = { fg = "$gnohj_color03" }
perm_sep = { fg = "$gnohj_color09" }

[select]
border = { fg = "$gnohj_color02" }
active = { fg = "$gnohj_color11", bold = true }
inactive = { fg = "$gnohj_color09", bg = "$gnohj_color10" }

[input]
border = { fg = "$gnohj_color02" }
value = { fg = "$gnohj_color09" }

[completion]
border = { fg = "$gnohj_color02", bg = "$gnohj_color10" }

[tasks]
border = { fg = "$gnohj_color02" }
title = { fg = "$gnohj_color09" }
hovered = { fg = "$gnohj_color02", underline = true }

[which]
cols = 3
mask = { bg = "$gnohj_color10" }
cand = { fg = "$gnohj_color02" }
rest = { fg = "$gnohj_color10" }
desc = { fg = "$gnohj_color09" }
separator = " ⯈ "
separator_style = { fg = "$gnohj_color09" }

[help]
on = { fg = "$gnohj_color02" }
run = { fg = "$gnohj_color02" }
footer = { fg = "$gnohj_color10", bg = "$gnohj_color09" }

[notify]
title_info = { fg = "$gnohj_color02" }
title_warn = { fg = "$gnohj_color05" }
title_error = { fg = "$gnohj_color11" }

[filetype]
rules = [
    # directories
    { name = "*/", fg = "$gnohj_color04" },

    # executables
    { name = "*", is = "exec", fg = "$gnohj_color02" },

    # images
    { mime = "image/*", fg = "$gnohj_color05" },

    # media
    { mime = "{audio,video}/*", fg = "$gnohj_color02" },

    # archives
    { mime = "application/{,g}zip", fg = "$gnohj_color11" },
    { mime = "application/x-{tar,bzip*,7z-compressed,xz,rar}", fg = "$gnohj_color11" },

    # documents
    { mime = "application/{pdf,doc,rtf,vnd.*}", fg = "$gnohj_color03" },

    # scripts and code
    { mime = "application/{x-shellscript,x-python,x-ruby,x-javascript}", fg = "$gnohj_color05" },
    { mime = "text/x-{c,c++}", fg = "$gnohj_color04" },

    # config files
    { name = "*.json", fg = "$gnohj_color05" },
    { name = "*.yml", fg = "$gnohj_color04" },
    { name = "*.toml", fg = "$gnohj_color01" },

    # special files
    { name = "*", is = "orphan", bg = "$gnohj_color10" },

    # dummy files
    { name = "*", is = "dummy", bg = "$gnohj_color10" },

    # fallback
    { name = "*/", fg = "$gnohj_color04" },
]
EOF

  echo "Yazi theme updated at '$yazi_theme_file'."
}

generate_ghosttyfetch_config() {
  ghosttyfetch_conf_dir="$HOME/.config/ghosttyfetch"
  ghosttyfetch_conf_file="$ghosttyfetch_conf_dir/config.json"

  # Create directory if it doesn't exist
  mkdir -p "$ghosttyfetch_conf_dir"

  cat >"$ghosttyfetch_conf_file" <<EOF
{
  "_comment": "Auto-generated ghosttyfetch config via colorscheme-set.sh",
  "sysinfo": {
    "enabled": true,
    "modules": [
      "OS",
      "Host",
      "Kernel",
      "Uptime",
      "Packages",
      "Shell",
      "Display",
      "CPU",
      "GPU",
      "Memory",
      "Swap",
      "Disk",
      "WM",
      "WMTheme",
      "Cursor",
      "Terminal",
      "TerminalFont",
      "LocalIp"
    ]
  },
  "fps": 30.0,
  "color": "${gnohj_color04}",
  "force_color": true,
  "no_color": false,
  "white_gradient_colors": [
    "${gnohj_color02}",
    "${gnohj_color03}",
    "${gnohj_color05}",
    "${gnohj_color06}",
    "${gnohj_color11}",
    "${gnohj_color01}",
    "${gnohj_color04}"
  ],
  "white_gradient_scroll": true,
  "white_gradient_scroll_speed": 20
}
EOF

  echo "GhosttyFetch configuration updated at '$ghosttyfetch_conf_file'."
}

generate_gitmux_config() {
  gitmux_conf_file="$HOME/.config/gitmux/gitmux.yml"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$gitmux_conf_file")"

  cat >"$gitmux_conf_file" <<EOF
#
#  ██████╗ ██╗████████╗███╗   ███╗██╗   ██╗██╗  ██╗
# ██╔════╝ ██║╚══██╔══╝████╗ ████║██║   ██║╚██╗██╔╝
# ██║  ███╗██║   ██║   ██╔████╔██║██║   ██║ ╚███╔╝
# ██║   ██║██║   ██║   ██║╚██╔╝██║██║   ██║ ██╔██╗
# ╚██████╔╝██║   ██║   ██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗
#  ╚═════╝ ╚═╝   ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝
#
# Git in your tmux status bar
# Auto-generated gitmux config
# https://github.com/arl/gitmux
tmux:
  symbols:

    ahead: "👆"
    behind: "👇"
    clean: ""
    branch: " "
    hashprefix: ":"
    staged: "●"
    conflict: "✖"
    modified: "✚"
    untracked: "󱀶 "
    stashed: " "
    insertions: " "
    deletions: " "
  styles:
    state: "#[fg=${gnohj_color11},nobold]"
    branch: "#[fg=${gnohj_color06},nobold]"
    staged: "#[fg=${gnohj_color02},nobold]"
    conflict: "#[fg=${gnohj_color11},nobold]"
    modified: "#[fg=${gnohj_color04},nobold]"
    untracked: "#[fg=${gnohj_color05},nobold]"
    stashed: "#[fg=${gnohj_color01},nobold]"
    clean: "#[fg=${gnohj_color02},nobold]"
    divergence: "#[fg=${gnohj_color05},nobold]"
    # state: "#[fg=\${gnohj_color59},nobold]"
    # branch: "#[fg=\${gnohj_color04},nobold]"
    # staged: "#[fg=\${gnohj_color60},nobold]"
    # conflict: "#[fg=\${gnohj_color59},nobold]"
    # modified: "#[fg=\${gnohj_color61},nobold]"
    # untracked: "#[fg=\${gnohj_color62},nobold]"
    # stashed: "#[fg=\${gnohj_color59},nobold]"
    # clean: "#[fg=\${gnohj_color60},nobold]"
    # divergence: "#[fg=\${gnohj_color63},nobold]"
    # insertions: "#[fg=\${gnohj_color60},nobold]"
    # deletions: "#[fg=\${gnohj_color62},nobold]"
  layout: [branch, divergence, stats, flags]
  # layout: [stats, flags, divergence, branch]
  options:
    branch_max_len: 0
    hide_clean: false
EOF

  echo "Gitmux configuration updated at '$gitmux_conf_file'."
}

# If there's an update, replace the active colorscheme and perform necessary actions
if [ "$UPDATED" = true ]; then
  echo "Updating active colorscheme to '$colorscheme_profile'."

  # Replace the contents of active-colorscheme.sh
  cp "$colorscheme_file" "$active_file"

  cp "$colorscheme_file" "$HOME/.config/nvim/lua/config/active-colorscheme.sh"

  # Source the active colorscheme to load variables
  source "$active_file"

  # Reload sketchybar to pick up new colors
  sketchybar --reload

  # Generate Starship config files (kept for easy switching)
  generate_starship_config

  # Generate lazygit config
  generate_lazygit_config

  # Generate lazydocker config
  generate_lazydocker_config

  # Generate the ghostty theme file, then reload config
  generate_ghostty_theme
  osascript "$HOME/.config/ghostty/reload-config.scpt" &

  # Generate the kitty theme file
  generate_kitty_theme

  # Generate the btop theme
  generate_btop_theme

  # Generate bat config
  generate_bat_config

  # Generate delta config
  generate_delta_config

  # Generate borders config
  generate_borders_config

  # Generate gitmux config
  generate_gitmux_config

  # Generate yazi theme
  generate_yazi_theme

  # Generate ghosttyfetch config
  generate_ghosttyfetch_config

  # Generate LS_COLORS for fd, ls, eza (if generate_ls_colors function exists)
  if typeset -f generate_ls_colors >/dev/null 2>&1; then
    generate_ls_colors
    echo "LS_COLORS updated for fd, ls, and eza."
  fi

  # Generate tmux colors and reload if tmux is running
  if [ -f "$HOME/.config/tmux/generate-tmux-colors.sh" ]; then
    "$HOME/.config/tmux/generate-tmux-colors.sh"
  fi

  # Set the wallpaper (skip if file doesn't exist)
  if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
    osascript -e '
    tell application "System Events"
        repeat with d in desktops
            set picture of d to "'"$wallpaper"'"
        end repeat
    end tell' 2>/dev/null || true
  fi
fi
