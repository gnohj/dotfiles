#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090

set -e

# /opt/homebrew stays first so macOS resolution is unchanged; the Linux dirs
# (linuxbrew / mise shims / ~/.local/bin) are appended for a headless Linux VPS.
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

error() {
  echo "Error: $1" >&2
  exit 1
}

if [ -z "$1" ]; then
  error "No colorscheme profile provided"
fi

colorscheme_profile="$1"

colorscheme_file="$HOME/.config/colorscheme/list/$colorscheme_profile"
active_file="$HOME/.config/colorscheme/active/active-colorscheme.sh"

if [ ! -f "$colorscheme_file" ]; then
  error "Colorscheme file '$colorscheme_file' does not exist."
fi

if [ ! -f "$active_file" ]; then
  echo "Active colorscheme file not found. Creating '$active_file'."
  cp "$colorscheme_file" "$active_file"
  UPDATED=true
else
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
# foreground = gnohj blue (gnohj_color04) instead of the near-white gnohj_color14,
# so terminal text (incl. the Claude Code pane) reads steel blue. Global: tints all
# default terminal text. ANSI white stays gnohj_color14 (palette 7/15 below).
foreground = $gnohj_color04

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
# foreground = gnohj blue (gnohj_color04) instead of near-white gnohj_color14, so
# terminal text (incl. the Claude Code pane) reads steel blue. Matches ghostty.
foreground $gnohj_color04

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
# Auto-generated by colorscheme-set.sh - do not edit directly
"\$schema" = 'https://starship.rs/config-schema.json'
add_newline = false
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
# Auto-generated by colorscheme-set.sh (infrastructure variant) - do not edit directly
"\$schema" = 'https://starship.rs/config-schema.json'
add_newline = false
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
  autoFetch: true
  fetchAll: false # fetch origin only — faster than --all on large repos
  paging:
    colorArg: always
    pager: delta --dark --paging=never
refresher:
  fetchInterval: 30
  refreshInterval: 10
os:
  editPreset: nvim
gui:
  showFileTree: true
  showBottomLine: false
  showCommandLog: false
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

  # <c-e> (Emoji), not <c-a>: <c-a> is herdr's prefix, so it never reaches
  # lazygit inside a herdr pane. Trigger with LEFT ctrl (;-hold layer) — skhd's
  # rctrl-e (tmux-dash focus) is RIGHT-ctrl only, so left-ctrl+e is clear.
  - key: "<c-e>"
    prompts:
      - type: "menuFromCommand"
        title: "AI Commit (Gitmoji)"
        key: "Msg"
        command: "aic-gitmoji.sh"
    command: git commit -m "{{.Form.Msg}}"
    context: "files"
    description: "Generate commit message with gitmoji"

  - key: "<c-s>"
    prompts:
      - type: "menuFromCommand"
        title: "AI Commit (Plain)"
        key: "Msg"
        command: "aic-plain.sh"
    command: git commit -m "{{.Form.Msg}}"
    context: "files"
    description: "Generate plain/simple commit message"

  # Open file in the host nvim instance (the one behind the lazygit
  # popup) via RPC. Skips the clipboard → exit lazygit → snacks-picker
  # paste round-trip. Path is also copied to clipboard as a side-effect
  # so it remains available for other contexts (PR descriptions, etc.).
  # Uses ~/.local/bin/lazygit-nvim-edit which talks to nvim's RPC
  # socket (~/.config/nvim/init.lua sets one per tmux pane).
  #
  # Note: this does NOT auto-close the lazygit popup. Press q yourself
  # after the file opens — auto-close was tried with several methods
  # (inline send-keys, backgrounded subshell, tmux run-shell -b) but
  # all interacted poorly with lazygit's customCommand wait/output:log
  # plumbing, leaving the spinner stuck.
  - key: "<c-o>"
    command: 'printf "%s" "{{.SelectedFile.Name}}" | { pbcopy 2>/dev/null || wl-copy 2>/dev/null || true; }; lazygit-nvim-edit "{{.SelectedFile.Name}}"'
    context: "files"
    description: "Copy path + open in host nvim"
    output: log

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
# Auto-generated by colorscheme-set.sh - do not edit directly
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

generate_hunk_config() {
  hunk_conf_file="$HOME/.config/hunk/config.toml"

  # Create the directory if it doesn't exist
  mkdir -p "$(dirname "$hunk_conf_file")"

  # Full-file ownership: hunk has no separate theme file, so the whole
  # config.toml (preferences + custom_theme) is generated here from the
  # gnohj_color* palette. Custom theme inherits from a built-in base and
  # overrides colors with palette values (colors 27-33 are the "Nvim -
  # Diffview colors" group: 30/32 = added/removed bg, 02/11 = added/removed fg).
  cat >"$hunk_conf_file" <<EOF
# Auto-generated hunk config — edit generate_hunk_config in colorscheme-set.sh
theme = "custom"
mode = "stack"
vcs = "git"
watch = false
exclude_untracked = false
line_numbers = true
wrap_lines = false
menu_bar = true
agent_notes = true
transparent_background = true

[custom_theme]
base = "github-dark-default"
label = "gnohj"
accent = "$gnohj_color04"
accentMuted = "$gnohj_color13"
text = "$gnohj_color14"
muted = "$gnohj_color09"
border = "$gnohj_color17"
selectedHunk = "$gnohj_color13"
lineNumberFg = "$gnohj_color09"
addedBg = "#132a19"
addedContentBg = "#1f4a2a"
addedSignColor = "$gnohj_color02"
removedBg = "#2a1319"
removedContentBg = "#4a1f2a"
removedSignColor = "$gnohj_color11"
movedAddedBg = "#132a19"
movedRemovedBg = "#2a1319"
badgeAdded = "$gnohj_color02"
badgeRemoved = "$gnohj_color11"
badgeNeutral = "$gnohj_color13"
fileNew = "$gnohj_color02"
fileModified = "$gnohj_color05"
fileDeleted = "$gnohj_color11"
fileRenamed = "$gnohj_color04"
fileUntracked = "$gnohj_color09"
noteBorder = "$gnohj_color01"
noteTitleText = "$gnohj_color14"

[custom_theme.syntax]
keyword = "$gnohj_color01"
string = "$gnohj_color02"
comment = "$gnohj_color09"
operator = "$gnohj_color03"
variable = "$gnohj_color14"
function = "$gnohj_color04"
type = "$gnohj_color05"
number = "$gnohj_color06"
constant = "$gnohj_color06"
property = "$gnohj_color04"
tag = "$gnohj_color11"
attribute = "$gnohj_color05"
EOF
  echo "hunk configuration updated at '$hunk_conf_file'."
}

generate_yazi_theme() {
  yazi_theme_file="$HOME/.config/yazi/theme.toml"

  cat >"$yazi_theme_file" <<EOF
# Yazi theme configuration
# Auto-generated yazi theme - Gnohj color scheme
# Docs: https://yazi-rs.github.io/docs/configuration/theme

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
    { url = "*/", fg = "$gnohj_color04" },

    # executables
    { url = "*", is = "exec", fg = "$gnohj_color02" },

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
    { url = "*.json", fg = "$gnohj_color05" },
    { url = "*.yml", fg = "$gnohj_color04" },
    { url = "*.toml", fg = "$gnohj_color01" },

    # special files
    { url = "*", is = "orphan", bg = "$gnohj_color10" },

    # dummy files
    { url = "*", is = "dummy", bg = "$gnohj_color10" },

    # fallback
    { url = "*/", fg = "$gnohj_color04" },
]

[icon]
prepend_dirs = [
	{ name = ".config", text = "", fg = "$gnohj_color06" },
	{ name = ".git", text = "", fg = "$gnohj_color03" },
	{ name = ".github", text = "", fg = "$gnohj_color03" },
	{ name = ".npm", text = "", fg = "$gnohj_color03" },
	{ name = "Desktop", text = "", fg = "$gnohj_color03" },
	{ name = "Development", text = "", fg = "$gnohj_color03" },
	{ name = "Documents", text = "", fg = "$gnohj_color03" },
	{ name = "Downloads", text = "", fg = "$gnohj_color03" },
	{ name = "Library", text = "", fg = "$gnohj_color03" },
	{ name = "Movies", text = "", fg = "$gnohj_color03" },
	{ name = "Music", text = "", fg = "$gnohj_color03" },
	{ name = "Pictures", text = "", fg = "$gnohj_color03" },
	{ name = "Public", text = "", fg = "$gnohj_color03" },
	{ name = "Videos", text = "", fg = "$gnohj_color03" },
]
prepend_files = [
	{ name = ".babelrc", text = "", fg = "$gnohj_color05" },
	{ name = ".bash_profile", text = "", fg = "$gnohj_color02" },
	{ name = ".bashrc", text = "", fg = "$gnohj_color02" },
	{ name = ".clang-format", text = "", fg = "$gnohj_color09" },
	{ name = ".clang-tidy", text = "", fg = "$gnohj_color09" },
	{ name = ".codespellrc", text = "󰓆", fg = "$gnohj_color02" },
	{ name = ".condarc", text = "", fg = "$gnohj_color02" },
	{ name = ".dockerignore", text = "󰡨", fg = "$gnohj_color04" },
	{ name = ".ds_store", text = "", fg = "$gnohj_color03" },
	{ name = ".editorconfig", text = "", fg = "$gnohj_color11" },
	{ name = ".env", text = "", fg = "$gnohj_color05" },
	{ name = ".eslintignore", text = "", fg = "$gnohj_color04" },
	{ name = ".eslintrc", text = "", fg = "$gnohj_color04" },
	{ name = ".git-blame-ignore-revs", text = "", fg = "$gnohj_color11" },
	{ name = ".gitattributes", text = "", fg = "$gnohj_color11" },
	{ name = ".gitconfig", text = "", fg = "$gnohj_color11" },
	{ name = ".gitignore", text = "", fg = "$gnohj_color11" },
	{ name = ".gitlab-ci.yml", text = "", fg = "$gnohj_color11" },
	{ name = ".gitmodules", text = "", fg = "$gnohj_color11" },
	{ name = ".gtkrc-2.0", text = "", fg = "$gnohj_color14" },
	{ name = ".gvimrc", text = "", fg = "$gnohj_color02" },
	{ name = ".justfile", text = "", fg = "$gnohj_color09" },
	{ name = ".luacheckrc", text = "", fg = "$gnohj_color04" },
	{ name = ".luaurc", text = "", fg = "$gnohj_color04" },
	{ name = ".mailmap", text = "󰊢", fg = "$gnohj_color11" },
	{ name = ".nanorc", text = "", fg = "$gnohj_color01" },
	{ name = ".npmignore", text = "", fg = "$gnohj_color11" },
	{ name = ".npmrc", text = "", fg = "$gnohj_color11" },
	{ name = ".nuxtrc", text = "󱄆", fg = "$gnohj_color02" },
	{ name = ".nvmrc", text = "", fg = "$gnohj_color02" },
	{ name = ".pnpmfile.cjs", text = "", fg = "$gnohj_color06" },
	{ name = ".pre-commit-config.yaml", text = "󰛢", fg = "$gnohj_color06" },
	{ name = ".prettierignore", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.cjs", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.js", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.json", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.json5", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.mjs", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.toml", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.yaml", text = "", fg = "$gnohj_color04" },
	{ name = ".prettierrc.yml", text = "", fg = "$gnohj_color04" },
	{ name = ".pylintrc", text = "", fg = "$gnohj_color09" },
	{ name = ".settings.json", text = "", fg = "$gnohj_color01" },
	{ name = ".SRCINFO", text = "󰣇", fg = "$gnohj_color03" },
	{ name = ".vimrc", text = "", fg = "$gnohj_color02" },
	{ name = ".Xauthority", text = "", fg = "$gnohj_color06" },
	{ name = ".xinitrc", text = "", fg = "$gnohj_color06" },
	{ name = ".Xresources", text = "", fg = "$gnohj_color06" },
	{ name = ".xsession", text = "", fg = "$gnohj_color06" },
	{ name = ".zprofile", text = "", fg = "$gnohj_color02" },
	{ name = ".zshenv", text = "", fg = "$gnohj_color02" },
	{ name = ".zshrc", text = "", fg = "$gnohj_color02" },
	{ name = "_gvimrc", text = "", fg = "$gnohj_color02" },
	{ name = "_vimrc", text = "", fg = "$gnohj_color02" },
	{ name = "AUTHORS", text = "", fg = "$gnohj_color01" },
	{ name = "AUTHORS.txt", text = "", fg = "$gnohj_color01" },
	{ name = "brewfile", text = "", fg = "$gnohj_color11" },
	{ name = "bspwmrc", text = "", fg = "$gnohj_color08" },
	{ name = "build", text = "", fg = "$gnohj_color02" },
	{ name = "build.gradle", text = "", fg = "$gnohj_color03" },
	{ name = "build.zig.zon", text = "", fg = "$gnohj_color06" },
	{ name = "bun.lock", text = "", fg = "$gnohj_color06" },
	{ name = "bun.lockb", text = "", fg = "$gnohj_color06" },
	{ name = "cantorrc", text = "", fg = "$gnohj_color04" },
	{ name = "checkhealth", text = "󰓙", fg = "$gnohj_color04" },
	{ name = "cmakelists.txt", text = "", fg = "$gnohj_color04" },
	{ name = "code_of_conduct", text = "", fg = "$gnohj_color11" },
	{ name = "code_of_conduct.md", text = "", fg = "$gnohj_color11" },
	{ name = "commit_editmsg", text = "", fg = "$gnohj_color11" },
	{ name = "commitlint.config.js", text = "󰜘", fg = "$gnohj_color03" },
	{ name = "commitlint.config.ts", text = "󰜘", fg = "$gnohj_color03" },
	{ name = "compose.yaml", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "compose.yml", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "config", text = "", fg = "$gnohj_color09" },
	{ name = "containerfile", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "copying", text = "", fg = "$gnohj_color05" },
	{ name = "copying.lesser", text = "", fg = "$gnohj_color05" },
	{ name = "Directory.Build.props", text = "", fg = "$gnohj_color04" },
	{ name = "Directory.Build.targets", text = "", fg = "$gnohj_color04" },
	{ name = "Directory.Packages.props", text = "", fg = "$gnohj_color04" },
	{ name = "docker-compose.yaml", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "docker-compose.yml", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "dockerfile", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "eslint.config.cjs", text = "", fg = "$gnohj_color04" },
	{ name = "eslint.config.js", text = "", fg = "$gnohj_color04" },
	{ name = "eslint.config.mjs", text = "", fg = "$gnohj_color04" },
	{ name = "eslint.config.ts", text = "", fg = "$gnohj_color04" },
	{ name = "ext_typoscript_setup.txt", text = "", fg = "$gnohj_color06" },
	{ name = "favicon.ico", text = "", fg = "$gnohj_color05" },
	{ name = "fp-info-cache", text = "", fg = "$gnohj_color14" },
	{ name = "fp-lib-table", text = "", fg = "$gnohj_color14" },
	{ name = "FreeCAD.conf", text = "", fg = "$gnohj_color11" },
	{ name = "Gemfile", text = "", fg = "$gnohj_color11" },
	{ name = "gnumakefile", text = "", fg = "$gnohj_color09" },
	{ name = "go.mod", text = "", fg = "$gnohj_color03" },
	{ name = "go.sum", text = "", fg = "$gnohj_color03" },
	{ name = "go.work", text = "", fg = "$gnohj_color03" },
	{ name = "gradle-wrapper.properties", text = "", fg = "$gnohj_color03" },
	{ name = "gradle.properties", text = "", fg = "$gnohj_color03" },
	{ name = "gradlew", text = "", fg = "$gnohj_color03" },
	{ name = "groovy", text = "", fg = "$gnohj_color04" },
	{ name = "gruntfile.babel.js", text = "", fg = "$gnohj_color06" },
	{ name = "gruntfile.coffee", text = "", fg = "$gnohj_color06" },
	{ name = "gruntfile.js", text = "", fg = "$gnohj_color06" },
	{ name = "gruntfile.ts", text = "", fg = "$gnohj_color06" },
	{ name = "gtkrc", text = "", fg = "$gnohj_color14" },
	{ name = "gulpfile.babel.js", text = "", fg = "$gnohj_color11" },
	{ name = "gulpfile.coffee", text = "", fg = "$gnohj_color11" },
	{ name = "gulpfile.js", text = "", fg = "$gnohj_color11" },
	{ name = "gulpfile.ts", text = "", fg = "$gnohj_color11" },
	{ name = "hypridle.conf", text = "", fg = "$gnohj_color03" },
	{ name = "hyprland.conf", text = "", fg = "$gnohj_color03" },
	{ name = "hyprlandd.conf", text = "", fg = "$gnohj_color03" },
	{ name = "hyprlock.conf", text = "", fg = "$gnohj_color03" },
	{ name = "hyprpaper.conf", text = "", fg = "$gnohj_color03" },
	{ name = "hyprsunset.conf", text = "", fg = "$gnohj_color03" },
	{ name = "i18n.config.js", text = "󰗊", fg = "$gnohj_color04" },
	{ name = "i18n.config.ts", text = "󰗊", fg = "$gnohj_color04" },
	{ name = "i3blocks.conf", text = "", fg = "$gnohj_color04" },
	{ name = "i3status.conf", text = "", fg = "$gnohj_color04" },
	{ name = "index.theme", text = "", fg = "$gnohj_color02" },
	{ name = "ionic.config.json", text = "", fg = "$gnohj_color04" },
	{ name = "Jenkinsfile", text = "", fg = "$gnohj_color11" },
	{ name = "justfile", text = "", fg = "$gnohj_color09" },
	{ name = "kalgebrarc", text = "", fg = "$gnohj_color04" },
	{ name = "kdeglobals", text = "", fg = "$gnohj_color04" },
	{ name = "kdenlive-layoutsrc", text = "", fg = "$gnohj_color04" },
	{ name = "kdenliverc", text = "", fg = "$gnohj_color04" },
	{ name = "kritadisplayrc", text = "", fg = "$gnohj_color01" },
	{ name = "kritarc", text = "", fg = "$gnohj_color01" },
	{ name = "license", text = "", fg = "$gnohj_color05" },
	{ name = "license.md", text = "", fg = "$gnohj_color05" },
	{ name = "lxde-rc.xml", text = "", fg = "$gnohj_color09" },
	{ name = "lxqt.conf", text = "", fg = "$gnohj_color03" },
	{ name = "makefile", text = "", fg = "$gnohj_color09" },
	{ name = "mix.lock", text = "", fg = "$gnohj_color01" },
	{ name = "mpv.conf", text = "", fg = "$gnohj_color01" },
	{ name = "next.config.cjs", text = "", fg = "$gnohj_color14" },
	{ name = "next.config.js", text = "", fg = "$gnohj_color14" },
	{ name = "next.config.ts", text = "", fg = "$gnohj_color14" },
	{ name = "node_modules", text = "", fg = "$gnohj_color11" },
	{ name = "nuxt.config.cjs", text = "󱄆", fg = "$gnohj_color02" },
	{ name = "nuxt.config.js", text = "󱄆", fg = "$gnohj_color02" },
	{ name = "nuxt.config.mjs", text = "󱄆", fg = "$gnohj_color02" },
	{ name = "nuxt.config.ts", text = "󱄆", fg = "$gnohj_color02" },
	{ name = "package-lock.json", text = "", fg = "$gnohj_color11" },
	{ name = "package.json", text = "", fg = "$gnohj_color11" },
	{ name = "PKGBUILD", text = "", fg = "$gnohj_color03" },
	{ name = "platformio.ini", text = "", fg = "$gnohj_color06" },
	{ name = "playwright.config.cjs", text = "", fg = "$gnohj_color02" },
	{ name = "playwright.config.cts", text = "", fg = "$gnohj_color02" },
	{ name = "playwright.config.js", text = "", fg = "$gnohj_color02" },
	{ name = "playwright.config.mjs", text = "", fg = "$gnohj_color02" },
	{ name = "playwright.config.mts", text = "", fg = "$gnohj_color02" },
	{ name = "playwright.config.ts", text = "", fg = "$gnohj_color02" },
	{ name = "pnpm-lock.yaml", text = "", fg = "$gnohj_color06" },
	{ name = "pnpm-workspace.yaml", text = "", fg = "$gnohj_color06" },
	{ name = "pom.xml", text = "", fg = "$gnohj_color11" },
	{ name = "prettier.config.cjs", text = "", fg = "$gnohj_color04" },
	{ name = "prettier.config.js", text = "", fg = "$gnohj_color04" },
	{ name = "prettier.config.mjs", text = "", fg = "$gnohj_color04" },
	{ name = "prettier.config.ts", text = "", fg = "$gnohj_color04" },
	{ name = "prisma.config.mts", text = "", fg = "$gnohj_color04" },
	{ name = "prisma.config.ts", text = "", fg = "$gnohj_color04" },
	{ name = "procfile", text = "", fg = "$gnohj_color01" },
	{ name = "PrusaSlicer.ini", text = "", fg = "$gnohj_color06" },
	{ name = "PrusaSlicerGcodeViewer.ini", text = "", fg = "$gnohj_color06" },
	{ name = "py.typed", text = "", fg = "$gnohj_color06" },
	{ name = "QtProject.conf", text = "", fg = "$gnohj_color02" },
	{ name = "rakefile", text = "", fg = "$gnohj_color11" },
	{ name = "readme", text = "󰂺", fg = "$gnohj_color14" },
	{ name = "readme.md", text = "󰂺", fg = "$gnohj_color14" },
	{ name = "rmd", text = "", fg = "$gnohj_color03" },
	{ name = "robots.txt", text = "󰚩", fg = "$gnohj_color04" },
	{ name = "security", text = "󰒃", fg = "$gnohj_color09" },
	{ name = "security.md", text = "󰒃", fg = "$gnohj_color09" },
	{ name = "settings.gradle", text = "", fg = "$gnohj_color03" },
	{ name = "svelte.config.js", text = "", fg = "$gnohj_color11" },
	{ name = "sxhkdrc", text = "", fg = "$gnohj_color08" },
	{ name = "sym-lib-table", text = "", fg = "$gnohj_color14" },
	{ name = "tailwind.config.js", text = "󱏿", fg = "$gnohj_color03" },
	{ name = "tailwind.config.mjs", text = "󱏿", fg = "$gnohj_color03" },
	{ name = "tailwind.config.ts", text = "󱏿", fg = "$gnohj_color03" },
	{ name = "tmux.conf", text = "", fg = "$gnohj_color02" },
	{ name = "tmux.conf.local", text = "", fg = "$gnohj_color02" },
	{ name = "tsconfig.json", text = "", fg = "$gnohj_color03" },
	{ name = "unlicense", text = "", fg = "$gnohj_color05" },
	{ name = "vagrantfile", text = "", fg = "$gnohj_color04" },
	{ name = "vercel.json", text = "", fg = "$gnohj_color14" },
	{ name = "vite.config.cjs", text = "", fg = "$gnohj_color06" },
	{ name = "vite.config.cts", text = "", fg = "$gnohj_color06" },
	{ name = "vite.config.js", text = "", fg = "$gnohj_color06" },
	{ name = "vite.config.mjs", text = "", fg = "$gnohj_color06" },
	{ name = "vite.config.mts", text = "", fg = "$gnohj_color06" },
	{ name = "vite.config.ts", text = "", fg = "$gnohj_color06" },
	{ name = "vitest.config.cjs", text = "", fg = "$gnohj_color02" },
	{ name = "vitest.config.cts", text = "", fg = "$gnohj_color02" },
	{ name = "vitest.config.js", text = "", fg = "$gnohj_color02" },
	{ name = "vitest.config.mjs", text = "", fg = "$gnohj_color02" },
	{ name = "vitest.config.mts", text = "", fg = "$gnohj_color02" },
	{ name = "vitest.config.ts", text = "", fg = "$gnohj_color02" },
	{ name = "vlcrc", text = "󰕼", fg = "$gnohj_color06" },
	{ name = "webpack", text = "󰜫", fg = "$gnohj_color03" },
	{ name = "weston.ini", text = "", fg = "$gnohj_color06" },
	{ name = "workspace", text = "", fg = "$gnohj_color02" },
	{ name = "wrangler.jsonc", text = "", fg = "$gnohj_color06" },
	{ name = "wrangler.toml", text = "", fg = "$gnohj_color06" },
	{ name = "xdph.conf", text = "", fg = "$gnohj_color03" },
	{ name = "xmobarrc", text = "", fg = "$gnohj_color11" },
	{ name = "xmobarrc.hs", text = "", fg = "$gnohj_color11" },
	{ name = "xmonad.hs", text = "", fg = "$gnohj_color11" },
	{ name = "xorg.conf", text = "", fg = "$gnohj_color06" },
	{ name = "xsettingsd.conf", text = "", fg = "$gnohj_color06" },
]
prepend_exts = [
	{ name = "3gp", text = "", fg = "$gnohj_color06" },
	{ name = "3mf", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "7z", text = "", fg = "$gnohj_color06" },
	{ name = "a", text = "", fg = "$gnohj_color09" },
	{ name = "aac", text = "", fg = "$gnohj_color03" },
	{ name = "ada", text = "", fg = "$gnohj_color04" },
	{ name = "adb", text = "", fg = "$gnohj_color04" },
	{ name = "ads", text = "", fg = "$gnohj_color01" },
	{ name = "ai", text = "", fg = "$gnohj_color05" },
	{ name = "aif", text = "", fg = "$gnohj_color03" },
	{ name = "aiff", text = "", fg = "$gnohj_color03" },
	{ name = "android", text = "", fg = "$gnohj_color02" },
	{ name = "ape", text = "", fg = "$gnohj_color03" },
	{ name = "apk", text = "", fg = "$gnohj_color02" },
	{ name = "apl", text = "", fg = "$gnohj_color02" },
	{ name = "app", text = "", fg = "$gnohj_color11" },
	{ name = "applescript", text = "", fg = "$gnohj_color09" },
	{ name = "asc", text = "󰦝", fg = "$gnohj_color04" },
	{ name = "asm", text = "", fg = "$gnohj_color03" },
	{ name = "ass", text = "󰨖", fg = "$gnohj_color06" },
	{ name = "astro", text = "", fg = "$gnohj_color11" },
	{ name = "avif", text = "", fg = "$gnohj_color01" },
	{ name = "awk", text = "", fg = "$gnohj_color09" },
	{ name = "azcli", text = "", fg = "$gnohj_color04" },
	{ name = "bak", text = "󰁯", fg = "$gnohj_color09" },
	{ name = "bash", text = "", fg = "$gnohj_color02" },
	{ name = "bat", text = "", fg = "$gnohj_color02" },
	{ name = "bazel", text = "", fg = "$gnohj_color02" },
	{ name = "bib", text = "󱉟", fg = "$gnohj_color05" },
	{ name = "bicep", text = "", fg = "$gnohj_color03" },
	{ name = "bicepparam", text = "", fg = "$gnohj_color01" },
	{ name = "bin", text = "", fg = "$gnohj_color11" },
	{ name = "blade.php", text = "", fg = "$gnohj_color11" },
	{ name = "blend", text = "󰂫", fg = "$gnohj_color06" },
	{ name = "blp", text = "󰺾", fg = "$gnohj_color04" },
	{ name = "bmp", text = "", fg = "$gnohj_color01" },
	{ name = "bqn", text = "", fg = "$gnohj_color02" },
	{ name = "brep", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "bz", text = "", fg = "$gnohj_color06" },
	{ name = "bz2", text = "", fg = "$gnohj_color06" },
	{ name = "bz3", text = "", fg = "$gnohj_color06" },
	{ name = "bzl", text = "", fg = "$gnohj_color02" },
	{ name = "c", text = "", fg = "$gnohj_color04" },
	{ name = "c++", text = "", fg = "$gnohj_color11" },
	{ name = "cache", text = "", fg = "$gnohj_color14" },
	{ name = "cast", text = "", fg = "$gnohj_color06" },
	{ name = "cbl", text = "", fg = "$gnohj_color04" },
	{ name = "cc", text = "", fg = "$gnohj_color11" },
	{ name = "ccm", text = "", fg = "$gnohj_color11" },
	{ name = "cfc", text = "", fg = "$gnohj_color03" },
	{ name = "cfg", text = "", fg = "$gnohj_color09" },
	{ name = "cfm", text = "", fg = "$gnohj_color03" },
	{ name = "cjs", text = "", fg = "$gnohj_color05" },
	{ name = "clj", text = "", fg = "$gnohj_color02" },
	{ name = "cljc", text = "", fg = "$gnohj_color02" },
	{ name = "cljd", text = "", fg = "$gnohj_color03" },
	{ name = "cljs", text = "", fg = "$gnohj_color03" },
	{ name = "cmake", text = "", fg = "$gnohj_color04" },
	{ name = "cob", text = "", fg = "$gnohj_color04" },
	{ name = "cobol", text = "", fg = "$gnohj_color04" },
	{ name = "coffee", text = "", fg = "$gnohj_color05" },
	{ name = "conda", text = "", fg = "$gnohj_color02" },
	{ name = "conf", text = "", fg = "$gnohj_color09" },
	{ name = "config.ru", text = "", fg = "$gnohj_color11" },
	{ name = "cow", text = "󰆚", fg = "$gnohj_color06" },
	{ name = "cp", text = "", fg = "$gnohj_color03" },
	{ name = "cpp", text = "", fg = "$gnohj_color03" },
	{ name = "cppm", text = "", fg = "$gnohj_color03" },
	{ name = "cpy", text = "", fg = "$gnohj_color04" },
	{ name = "cr", text = "", fg = "$gnohj_color09" },
	{ name = "crdownload", text = "", fg = "$gnohj_color02" },
	{ name = "cs", text = "󰌛", fg = "$gnohj_color05" },
	{ name = "csh", text = "", fg = "$gnohj_color09" },
	{ name = "cshtml", text = "󱦗", fg = "$gnohj_color04" },
	{ name = "cson", text = "", fg = "$gnohj_color05" },
	{ name = "csproj", text = "󰪮", fg = "$gnohj_color04" },
	{ name = "css", text = "", fg = "$gnohj_color01" },
	{ name = "csv", text = "", fg = "$gnohj_color02" },
	{ name = "cts", text = "", fg = "$gnohj_color03" },
	{ name = "cu", text = "", fg = "$gnohj_color02" },
	{ name = "cue", text = "󰲹", fg = "$gnohj_color11" },
	{ name = "cuh", text = "", fg = "$gnohj_color01" },
	{ name = "cxx", text = "", fg = "$gnohj_color03" },
	{ name = "cxxm", text = "", fg = "$gnohj_color03" },
	{ name = "d", text = "", fg = "$gnohj_color11" },
	{ name = "d.ts", text = "", fg = "$gnohj_color06" },
	{ name = "dart", text = "", fg = "$gnohj_color04" },
	{ name = "db", text = "", fg = "$gnohj_color14" },
	{ name = "dconf", text = "", fg = "$gnohj_color14" },
	{ name = "desktop", text = "", fg = "$gnohj_color01" },
	{ name = "diff", text = "", fg = "$gnohj_color03" },
	{ name = "dll", text = "", fg = "$gnohj_color06" },
	{ name = "doc", text = "󰈬", fg = "$gnohj_color04" },
	{ name = "Dockerfile", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "dockerignore", text = "󰡨", fg = "$gnohj_color04" },
	{ name = "docx", text = "󰈬", fg = "$gnohj_color04" },
	{ name = "dot", text = "󱁉", fg = "$gnohj_color04" },
	{ name = "download", text = "", fg = "$gnohj_color02" },
	{ name = "drl", text = "", fg = "$gnohj_color11" },
	{ name = "dropbox", text = "", fg = "$gnohj_color04" },
	{ name = "dump", text = "", fg = "$gnohj_color14" },
	{ name = "dwg", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "dxf", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "ebook", text = "", fg = "$gnohj_color06" },
	{ name = "ebuild", text = "", fg = "$gnohj_color04" },
	{ name = "edn", text = "", fg = "$gnohj_color03" },
	{ name = "eex", text = "", fg = "$gnohj_color01" },
	{ name = "ejs", text = "", fg = "$gnohj_color05" },
	{ name = "el", text = "", fg = "$gnohj_color04" },
	{ name = "elc", text = "", fg = "$gnohj_color04" },
	{ name = "elf", text = "", fg = "$gnohj_color11" },
	{ name = "elm", text = "", fg = "$gnohj_color03" },
	{ name = "eln", text = "", fg = "$gnohj_color04" },
	{ name = "env", text = "", fg = "$gnohj_color05" },
	{ name = "eot", text = "", fg = "$gnohj_color14" },
	{ name = "epp", text = "", fg = "$gnohj_color06" },
	{ name = "epub", text = "", fg = "$gnohj_color06" },
	{ name = "erb", text = "", fg = "$gnohj_color11" },
	{ name = "erl", text = "", fg = "$gnohj_color11" },
	{ name = "ex", text = "", fg = "$gnohj_color01" },
	{ name = "exe", text = "", fg = "$gnohj_color11" },
	{ name = "exs", text = "", fg = "$gnohj_color01" },
	{ name = "f#", text = "", fg = "$gnohj_color03" },
	{ name = "f3d", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "f90", text = "󱈚", fg = "$gnohj_color01" },
	{ name = "fbx", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "fcbak", text = "", fg = "$gnohj_color11" },
	{ name = "fcmacro", text = "", fg = "$gnohj_color11" },
	{ name = "fcmat", text = "", fg = "$gnohj_color11" },
	{ name = "fcparam", text = "", fg = "$gnohj_color11" },
	{ name = "fcscript", text = "", fg = "$gnohj_color11" },
	{ name = "fcstd", text = "", fg = "$gnohj_color11" },
	{ name = "fcstd1", text = "", fg = "$gnohj_color11" },
	{ name = "fctb", text = "", fg = "$gnohj_color11" },
	{ name = "fctl", text = "", fg = "$gnohj_color11" },
	{ name = "fdmdownload", text = "", fg = "$gnohj_color02" },
	{ name = "feature", text = "", fg = "$gnohj_color02" },
	{ name = "fish", text = "", fg = "$gnohj_color09" },
	{ name = "flac", text = "", fg = "$gnohj_color03" },
	{ name = "flc", text = "", fg = "$gnohj_color14" },
	{ name = "flf", text = "", fg = "$gnohj_color14" },
	{ name = "fnl", text = "", fg = "$gnohj_color06" },
	{ name = "fodg", text = "", fg = "$gnohj_color05" },
	{ name = "fodp", text = "", fg = "$gnohj_color06" },
	{ name = "fods", text = "", fg = "$gnohj_color02" },
	{ name = "fodt", text = "", fg = "$gnohj_color03" },
	{ name = "frag", text = "", fg = "$gnohj_color04" },
	{ name = "fs", text = "", fg = "$gnohj_color03" },
	{ name = "fsi", text = "", fg = "$gnohj_color03" },
	{ name = "fsscript", text = "", fg = "$gnohj_color03" },
	{ name = "fsx", text = "", fg = "$gnohj_color03" },
	{ name = "gcode", text = "󰐫", fg = "$gnohj_color04" },
	{ name = "gd", text = "", fg = "$gnohj_color09" },
	{ name = "gemspec", text = "", fg = "$gnohj_color11" },
	{ name = "geom", text = "", fg = "$gnohj_color04" },
	{ name = "gif", text = "", fg = "$gnohj_color01" },
	{ name = "git", text = "", fg = "$gnohj_color11" },
	{ name = "glb", text = "", fg = "$gnohj_color06" },
	{ name = "gleam", text = "", fg = "$gnohj_color01" },
	{ name = "glsl", text = "", fg = "$gnohj_color04" },
	{ name = "gnumakefile", text = "", fg = "$gnohj_color09" },
	{ name = "go", text = "", fg = "$gnohj_color03" },
	{ name = "godot", text = "", fg = "$gnohj_color09" },
	{ name = "gpr", text = "", fg = "$gnohj_color09" },
	{ name = "gql", text = "", fg = "$gnohj_color11" },
	{ name = "gradle", text = "", fg = "$gnohj_color03" },
	{ name = "graphql", text = "", fg = "$gnohj_color11" },
	{ name = "gresource", text = "", fg = "$gnohj_color14" },
	{ name = "gv", text = "󱁉", fg = "$gnohj_color04" },
	{ name = "gz", text = "", fg = "$gnohj_color06" },
	{ name = "h", text = "", fg = "$gnohj_color01" },
	{ name = "haml", text = "", fg = "$gnohj_color05" },
	{ name = "hbs", text = "", fg = "$gnohj_color06" },
	{ name = "heex", text = "", fg = "$gnohj_color01" },
	{ name = "hex", text = "", fg = "$gnohj_color04" },
	{ name = "hh", text = "", fg = "$gnohj_color01" },
	{ name = "hpp", text = "", fg = "$gnohj_color01" },
	{ name = "hrl", text = "", fg = "$gnohj_color11" },
	{ name = "hs", text = "", fg = "$gnohj_color01" },
	{ name = "htm", text = "", fg = "$gnohj_color11" },
	{ name = "html", text = "", fg = "$gnohj_color11" },
	{ name = "http", text = "", fg = "$gnohj_color03" },
	{ name = "huff", text = "󰡘", fg = "$gnohj_color04" },
	{ name = "hurl", text = "", fg = "$gnohj_color11" },
	{ name = "hx", text = "", fg = "$gnohj_color06" },
	{ name = "hxx", text = "", fg = "$gnohj_color01" },
	{ name = "ical", text = "", fg = "$gnohj_color04" },
	{ name = "icalendar", text = "", fg = "$gnohj_color04" },
	{ name = "ico", text = "", fg = "$gnohj_color05" },
	{ name = "ics", text = "", fg = "$gnohj_color04" },
	{ name = "ifb", text = "", fg = "$gnohj_color04" },
	{ name = "ifc", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "ige", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "iges", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "igs", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "image", text = "", fg = "$gnohj_color11" },
	{ name = "img", text = "", fg = "$gnohj_color11" },
	{ name = "import", text = "", fg = "$gnohj_color14" },
	{ name = "info", text = "", fg = "$gnohj_color05" },
	{ name = "ini", text = "", fg = "$gnohj_color09" },
	{ name = "ino", text = "", fg = "$gnohj_color03" },
	{ name = "ipynb", text = "", fg = "$gnohj_color06" },
	{ name = "iso", text = "", fg = "$gnohj_color11" },
	{ name = "ixx", text = "", fg = "$gnohj_color03" },
	{ name = "jar", text = "", fg = "$gnohj_color06" },
	{ name = "java", text = "", fg = "$gnohj_color11" },
	{ name = "jl", text = "", fg = "$gnohj_color01" },
	{ name = "jpeg", text = "", fg = "$gnohj_color01" },
	{ name = "jpg", text = "", fg = "$gnohj_color01" },
	{ name = "js", text = "", fg = "$gnohj_color05" },
	{ name = "json", text = "", fg = "$gnohj_color05" },
	{ name = "json5", text = "", fg = "$gnohj_color05" },
	{ name = "jsonc", text = "", fg = "$gnohj_color05" },
	{ name = "jsx", text = "", fg = "$gnohj_color03" },
	{ name = "jwmrc", text = "", fg = "$gnohj_color04" },
	{ name = "jxl", text = "", fg = "$gnohj_color01" },
	{ name = "kbx", text = "󰯄", fg = "$gnohj_color08" },
	{ name = "kdb", text = "", fg = "$gnohj_color02" },
	{ name = "kdbx", text = "", fg = "$gnohj_color02" },
	{ name = "kdenlive", text = "", fg = "$gnohj_color04" },
	{ name = "kdenlivetitle", text = "", fg = "$gnohj_color04" },
	{ name = "kicad_dru", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_mod", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_pcb", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_prl", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_pro", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_sch", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_sym", text = "", fg = "$gnohj_color14" },
	{ name = "kicad_wks", text = "", fg = "$gnohj_color14" },
	{ name = "ko", text = "", fg = "$gnohj_color09" },
	{ name = "kpp", text = "", fg = "$gnohj_color01" },
	{ name = "kra", text = "", fg = "$gnohj_color01" },
	{ name = "krz", text = "", fg = "$gnohj_color01" },
	{ name = "ksh", text = "", fg = "$gnohj_color09" },
	{ name = "kt", text = "", fg = "$gnohj_color04" },
	{ name = "kts", text = "", fg = "$gnohj_color04" },
	{ name = "lck", text = "", fg = "$gnohj_color09" },
	{ name = "leex", text = "", fg = "$gnohj_color01" },
	{ name = "less", text = "", fg = "$gnohj_color01" },
	{ name = "lff", text = "", fg = "$gnohj_color14" },
	{ name = "lhs", text = "", fg = "$gnohj_color01" },
	{ name = "lib", text = "", fg = "$gnohj_color06" },
	{ name = "license", text = "", fg = "$gnohj_color05" },
	{ name = "liquid", text = "", fg = "$gnohj_color02" },
	{ name = "lock", text = "", fg = "$gnohj_color09" },
	{ name = "log", text = "󰌱", fg = "$gnohj_color14" },
	{ name = "lrc", text = "󰨖", fg = "$gnohj_color06" },
	{ name = "lua", text = "", fg = "$gnohj_color04" },
	{ name = "luac", text = "", fg = "$gnohj_color04" },
	{ name = "luau", text = "", fg = "$gnohj_color04" },
	{ name = "m", text = "", fg = "$gnohj_color04" },
	{ name = "m3u", text = "󰲹", fg = "$gnohj_color11" },
	{ name = "m3u8", text = "󰲹", fg = "$gnohj_color11" },
	{ name = "m4a", text = "", fg = "$gnohj_color03" },
	{ name = "m4v", text = "", fg = "$gnohj_color06" },
	{ name = "magnet", text = "", fg = "$gnohj_color11" },
	{ name = "makefile", text = "", fg = "$gnohj_color09" },
	{ name = "markdown", text = "", fg = "$gnohj_color14" },
	{ name = "material", text = "", fg = "$gnohj_color11" },
	{ name = "md", text = "", fg = "$gnohj_color14" },
	{ name = "md5", text = "󰕥", fg = "$gnohj_color04" },
	{ name = "mdx", text = "", fg = "$gnohj_color03" },
	{ name = "mint", text = "󰌪", fg = "$gnohj_color02" },
	{ name = "mjs", text = "", fg = "$gnohj_color05" },
	{ name = "mk", text = "", fg = "$gnohj_color09" },
	{ name = "mkv", text = "", fg = "$gnohj_color06" },
	{ name = "ml", text = "", fg = "$gnohj_color06" },
	{ name = "mli", text = "", fg = "$gnohj_color06" },
	{ name = "mm", text = "", fg = "$gnohj_color03" },
	{ name = "mo", text = "", fg = "$gnohj_color04" },
	{ name = "mobi", text = "", fg = "$gnohj_color06" },
	{ name = "mojo", text = "", fg = "$gnohj_color11" },
	{ name = "mov", text = "", fg = "$gnohj_color06" },
	{ name = "mp3", text = "", fg = "$gnohj_color03" },
	{ name = "mp4", text = "", fg = "$gnohj_color06" },
	{ name = "mpp", text = "", fg = "$gnohj_color03" },
	{ name = "msf", text = "", fg = "$gnohj_color04" },
	{ name = "mts", text = "", fg = "$gnohj_color03" },
	{ name = "mustache", text = "", fg = "$gnohj_color06" },
	{ name = "nfo", text = "", fg = "$gnohj_color05" },
	{ name = "nim", text = "", fg = "$gnohj_color05" },
	{ name = "nix", text = "", fg = "$gnohj_color04" },
	{ name = "norg", text = "", fg = "$gnohj_color04" },
	{ name = "nswag", text = "", fg = "$gnohj_color02" },
	{ name = "nu", text = "", fg = "$gnohj_color02" },
	{ name = "o", text = "", fg = "$gnohj_color11" },
	{ name = "obj", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "odf", text = "", fg = "$gnohj_color11" },
	{ name = "odg", text = "", fg = "$gnohj_color05" },
	{ name = "odin", text = "󰟢", fg = "$gnohj_color04" },
	{ name = "odp", text = "", fg = "$gnohj_color06" },
	{ name = "ods", text = "", fg = "$gnohj_color02" },
	{ name = "odt", text = "", fg = "$gnohj_color03" },
	{ name = "oga", text = "", fg = "$gnohj_color03" },
	{ name = "ogg", text = "", fg = "$gnohj_color03" },
	{ name = "ogv", text = "", fg = "$gnohj_color06" },
	{ name = "ogx", text = "", fg = "$gnohj_color06" },
	{ name = "opus", text = "", fg = "$gnohj_color03" },
	{ name = "org", text = "", fg = "$gnohj_color02" },
	{ name = "otf", text = "", fg = "$gnohj_color14" },
	{ name = "out", text = "", fg = "$gnohj_color11" },
	{ name = "part", text = "", fg = "$gnohj_color02" },
	{ name = "patch", text = "", fg = "$gnohj_color03" },
	{ name = "pck", text = "", fg = "$gnohj_color09" },
	{ name = "pcm", text = "", fg = "$gnohj_color03" },
	{ name = "pdf", text = "", fg = "$gnohj_color11" },
	{ name = "php", text = "", fg = "$gnohj_color01" },
	{ name = "pl", text = "", fg = "$gnohj_color03" },
	{ name = "pls", text = "󰲹", fg = "$gnohj_color11" },
	{ name = "ply", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "pm", text = "", fg = "$gnohj_color03" },
	{ name = "png", text = "", fg = "$gnohj_color01" },
	{ name = "po", text = "", fg = "$gnohj_color03" },
	{ name = "pot", text = "", fg = "$gnohj_color03" },
	{ name = "pp", text = "", fg = "$gnohj_color06" },
	{ name = "ppt", text = "󰈧", fg = "$gnohj_color11" },
	{ name = "pptx", text = "󰈧", fg = "$gnohj_color11" },
	{ name = "prisma", text = "", fg = "$gnohj_color04" },
	{ name = "pro", text = "", fg = "$gnohj_color06" },
	{ name = "ps1", text = "󰨊", fg = "$gnohj_color04" },
	{ name = "psb", text = "", fg = "$gnohj_color03" },
	{ name = "psd", text = "", fg = "$gnohj_color03" },
	{ name = "psd1", text = "󰨊", fg = "$gnohj_color04" },
	{ name = "psm1", text = "󰨊", fg = "$gnohj_color04" },
	{ name = "pub", text = "󰷖", fg = "$gnohj_color06" },
	{ name = "pxd", text = "", fg = "$gnohj_color04" },
	{ name = "pxi", text = "", fg = "$gnohj_color04" },
	{ name = "py", text = "", fg = "$gnohj_color06" },
	{ name = "pyc", text = "", fg = "$gnohj_color06" },
	{ name = "pyd", text = "", fg = "$gnohj_color06" },
	{ name = "pyi", text = "", fg = "$gnohj_color06" },
	{ name = "pyo", text = "", fg = "$gnohj_color06" },
	{ name = "pyw", text = "", fg = "$gnohj_color04" },
	{ name = "pyx", text = "", fg = "$gnohj_color04" },
	{ name = "qm", text = "", fg = "$gnohj_color03" },
	{ name = "qml", text = "", fg = "$gnohj_color02" },
	{ name = "qrc", text = "", fg = "$gnohj_color02" },
	{ name = "qss", text = "", fg = "$gnohj_color02" },
	{ name = "query", text = "", fg = "$gnohj_color02" },
	{ name = "R", text = "󰟔", fg = "$gnohj_color04" },
	{ name = "r", text = "󰟔", fg = "$gnohj_color04" },
	{ name = "rake", text = "", fg = "$gnohj_color11" },
	{ name = "rar", text = "", fg = "$gnohj_color06" },
	{ name = "rasi", text = "", fg = "$gnohj_color05" },
	{ name = "razor", text = "󱦘", fg = "$gnohj_color04" },
	{ name = "rb", text = "", fg = "$gnohj_color11" },
	{ name = "res", text = "", fg = "$gnohj_color11" },
	{ name = "resi", text = "", fg = "$gnohj_color11" },
	{ name = "rlib", text = "", fg = "$gnohj_color06" },
	{ name = "rmd", text = "", fg = "$gnohj_color03" },
	{ name = "rproj", text = "󰗆", fg = "$gnohj_color02" },
	{ name = "rs", text = "", fg = "$gnohj_color06" },
	{ name = "rss", text = "", fg = "$gnohj_color06" },
	{ name = "s", text = "", fg = "$gnohj_color04" },
	{ name = "sass", text = "", fg = "$gnohj_color11" },
	{ name = "sbt", text = "", fg = "$gnohj_color11" },
	{ name = "sc", text = "", fg = "$gnohj_color11" },
	{ name = "scad", text = "", fg = "$gnohj_color05" },
	{ name = "scala", text = "", fg = "$gnohj_color11" },
	{ name = "scm", text = "󰘧", fg = "$gnohj_color14" },
	{ name = "scss", text = "", fg = "$gnohj_color11" },
	{ name = "sh", text = "", fg = "$gnohj_color09" },
	{ name = "sha1", text = "󰕥", fg = "$gnohj_color04" },
	{ name = "sha224", text = "󰕥", fg = "$gnohj_color04" },
	{ name = "sha256", text = "󰕥", fg = "$gnohj_color04" },
	{ name = "sha384", text = "󰕥", fg = "$gnohj_color04" },
	{ name = "sha512", text = "󰕥", fg = "$gnohj_color04" },
	{ name = "sig", text = "󰘧", fg = "$gnohj_color06" },
	{ name = "signature", text = "󰘧", fg = "$gnohj_color06" },
	{ name = "skp", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "sldasm", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "sldprt", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "slim", text = "", fg = "$gnohj_color11" },
	{ name = "sln", text = "", fg = "$gnohj_color01" },
	{ name = "slnx", text = "", fg = "$gnohj_color01" },
	{ name = "slvs", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "sml", text = "󰘧", fg = "$gnohj_color06" },
	{ name = "so", text = "", fg = "$gnohj_color09" },
	{ name = "sol", text = "", fg = "$gnohj_color03" },
	{ name = "spec.js", text = "", fg = "$gnohj_color05" },
	{ name = "spec.jsx", text = "", fg = "$gnohj_color03" },
	{ name = "spec.ts", text = "", fg = "$gnohj_color03" },
	{ name = "spec.tsx", text = "", fg = "$gnohj_color04" },
	{ name = "spx", text = "", fg = "$gnohj_color03" },
	{ name = "sql", text = "", fg = "$gnohj_color14" },
	{ name = "sqlite", text = "", fg = "$gnohj_color14" },
	{ name = "sqlite3", text = "", fg = "$gnohj_color14" },
	{ name = "srt", text = "󰨖", fg = "$gnohj_color06" },
	{ name = "ssa", text = "󰨖", fg = "$gnohj_color06" },
	{ name = "ste", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "step", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "stl", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "stories.js", text = "", fg = "$gnohj_color11" },
	{ name = "stories.jsx", text = "", fg = "$gnohj_color11" },
	{ name = "stories.mjs", text = "", fg = "$gnohj_color11" },
	{ name = "stories.svelte", text = "", fg = "$gnohj_color11" },
	{ name = "stories.ts", text = "", fg = "$gnohj_color11" },
	{ name = "stories.tsx", text = "", fg = "$gnohj_color11" },
	{ name = "stories.vue", text = "", fg = "$gnohj_color11" },
	{ name = "stp", text = "󰻫", fg = "$gnohj_color02" },
	{ name = "strings", text = "", fg = "$gnohj_color03" },
	{ name = "styl", text = "", fg = "$gnohj_color02" },
	{ name = "sub", text = "󰨖", fg = "$gnohj_color06" },
	{ name = "sublime", text = "", fg = "$gnohj_color06" },
	{ name = "suo", text = "", fg = "$gnohj_color01" },
	{ name = "sv", text = "󰍛", fg = "$gnohj_color02" },
	{ name = "svelte", text = "", fg = "$gnohj_color11" },
	{ name = "svg", text = "󰜡", fg = "$gnohj_color06" },
	{ name = "svgz", text = "󰜡", fg = "$gnohj_color06" },
	{ name = "svh", text = "󰍛", fg = "$gnohj_color02" },
	{ name = "swift", text = "", fg = "$gnohj_color06" },
	{ name = "t", text = "", fg = "$gnohj_color03" },
	{ name = "tbc", text = "󰛓", fg = "$gnohj_color04" },
	{ name = "tcl", text = "󰛓", fg = "$gnohj_color04" },
	{ name = "templ", text = "", fg = "$gnohj_color05" },
	{ name = "terminal", text = "", fg = "$gnohj_color02" },
	{ name = "test.js", text = "", fg = "$gnohj_color05" },
	{ name = "test.jsx", text = "", fg = "$gnohj_color03" },
	{ name = "test.ts", text = "", fg = "$gnohj_color03" },
	{ name = "test.tsx", text = "", fg = "$gnohj_color04" },
	{ name = "tex", text = "", fg = "$gnohj_color02" },
	{ name = "tf", text = "", fg = "$gnohj_color04" },
	{ name = "tfvars", text = "", fg = "$gnohj_color04" },
	{ name = "tgz", text = "", fg = "$gnohj_color06" },
	{ name = "tmpl", text = "", fg = "$gnohj_color05" },
	{ name = "tmux", text = "", fg = "$gnohj_color02" },
	{ name = "toml", text = "", fg = "$gnohj_color06" },
	{ name = "torrent", text = "", fg = "$gnohj_color02" },
	{ name = "tres", text = "", fg = "$gnohj_color09" },
	{ name = "ts", text = "", fg = "$gnohj_color03" },
	{ name = "tscn", text = "", fg = "$gnohj_color09" },
	{ name = "tsconfig", text = "", fg = "$gnohj_color06" },
	{ name = "tsx", text = "", fg = "$gnohj_color04" },
	{ name = "ttf", text = "", fg = "$gnohj_color14" },
	{ name = "twig", text = "", fg = "$gnohj_color02" },
	{ name = "txt", text = "󰈙", fg = "$gnohj_color02" },
	{ name = "txz", text = "", fg = "$gnohj_color06" },
	{ name = "typ", text = "", fg = "$gnohj_color03" },
	{ name = "typoscript", text = "", fg = "$gnohj_color06" },
	{ name = "ui", text = "", fg = "$gnohj_color04" },
	{ name = "v", text = "󰍛", fg = "$gnohj_color02" },
	{ name = "vala", text = "", fg = "$gnohj_color01" },
	{ name = "vert", text = "", fg = "$gnohj_color04" },
	{ name = "vh", text = "󰍛", fg = "$gnohj_color02" },
	{ name = "vhd", text = "󰍛", fg = "$gnohj_color02" },
	{ name = "vhdl", text = "󰍛", fg = "$gnohj_color02" },
	{ name = "vi", text = "", fg = "$gnohj_color05" },
	{ name = "vim", text = "", fg = "$gnohj_color02" },
	{ name = "vsh", text = "", fg = "$gnohj_color04" },
	{ name = "vsix", text = "", fg = "$gnohj_color01" },
	{ name = "vue", text = "", fg = "$gnohj_color02" },
	{ name = "wasm", text = "", fg = "$gnohj_color04" },
	{ name = "wav", text = "", fg = "$gnohj_color03" },
	{ name = "webm", text = "", fg = "$gnohj_color06" },
	{ name = "webmanifest", text = "", fg = "$gnohj_color05" },
	{ name = "webp", text = "", fg = "$gnohj_color01" },
	{ name = "webpack", text = "󰜫", fg = "$gnohj_color03" },
	{ name = "wma", text = "", fg = "$gnohj_color03" },
	{ name = "wmv", text = "", fg = "$gnohj_color06" },
	{ name = "woff", text = "", fg = "$gnohj_color14" },
	{ name = "woff2", text = "", fg = "$gnohj_color14" },
	{ name = "wrl", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "wrz", text = "󰆧", fg = "$gnohj_color09" },
	{ name = "wv", text = "", fg = "$gnohj_color03" },
	{ name = "wvc", text = "", fg = "$gnohj_color03" },
	{ name = "x", text = "", fg = "$gnohj_color04" },
	{ name = "xaml", text = "󰙳", fg = "$gnohj_color04" },
	{ name = "xcf", text = "", fg = "$gnohj_color06" },
	{ name = "xcplayground", text = "", fg = "$gnohj_color06" },
	{ name = "xcstrings", text = "", fg = "$gnohj_color03" },
	{ name = "xls", text = "󰈛", fg = "$gnohj_color02" },
	{ name = "xlsx", text = "󰈛", fg = "$gnohj_color02" },
	{ name = "xm", text = "", fg = "$gnohj_color03" },
	{ name = "xml", text = "󰗀", fg = "$gnohj_color06" },
	{ name = "xpi", text = "", fg = "$gnohj_color11" },
	{ name = "xslt", text = "󰗀", fg = "$gnohj_color03" },
	{ name = "xul", text = "", fg = "$gnohj_color06" },
	{ name = "xz", text = "", fg = "$gnohj_color06" },
	{ name = "yaml", text = "", fg = "$gnohj_color09" },
	{ name = "yml", text = "", fg = "$gnohj_color09" },
	{ name = "zig", text = "", fg = "$gnohj_color06" },
	{ name = "zip", text = "", fg = "$gnohj_color06" },
	{ name = "zsh", text = "", fg = "$gnohj_color02" },
	{ name = "zst", text = "", fg = "$gnohj_color06" },
	{ name = "🔥", text = "", fg = "$gnohj_color11" },
]
prepend_conds = [
	# Special files
	# Special files
	{ if = "orphan", text = "", fg = "$gnohj_color14" },
	{ if = "link", text = "", fg = "$gnohj_color09" },
	{ if = "block", text = "", fg = "$gnohj_color05" },
	{ if = "char", text = "", fg = "$gnohj_color05" },
	{ if = "fifo", text = "", fg = "$gnohj_color05" },
	{ if = "sock", text = "", fg = "$gnohj_color05" },
	{ if = "sticky", text = "", fg = "$gnohj_color05" },
	{ if = "dummy", text = "", fg = "$gnohj_color11" },
	
	# Fallback
	{ if = "dir & hovered", text = "", fg = "$gnohj_color03" },
	{ if = "dir", text = "", fg = "$gnohj_color03" },
	{ if = "exec", text = "", fg = "$gnohj_color02" },
	{ if = "!dir", text = "", fg = "$gnohj_color14" },
]
EOF

  echo "Yazi theme updated at '$yazi_theme_file'."
}

generate_eza_theme() {
  eza_conf_dir="$HOME/.config/eza"
  eza_theme_file="$eza_conf_dir/theme.yml"

  # Create directory if it doesn't exist
  mkdir -p "$eza_conf_dir"

  cat >"$eza_theme_file" <<EOF
# Eza theme with gnohj colors
# Auto-generated via colorscheme-set.sh

filekinds:
  directory:
    foreground: "$gnohj_color04"
    is_bold: true
  symlink:
    foreground: "$gnohj_color03"
  executable:
    foreground: "$gnohj_color02"
  regular:
    foreground: "$gnohj_color14"
  pipe:
    foreground: "$gnohj_color05"
  socket:
    foreground: "$gnohj_color05"
  block_device:
    foreground: "$gnohj_color05"
  char_device:
    foreground: "$gnohj_color05"
  special:
    foreground: "$gnohj_color01"

extensions:
  # Config files - yellow
  json:
    filename:
      foreground: "$gnohj_color05"
  json5:
    filename:
      foreground: "$gnohj_color05"
  jsonc:
    filename:
      foreground: "$gnohj_color05"
  yaml:
    filename:
      foreground: "$gnohj_color05"
  yml:
    filename:
      foreground: "$gnohj_color05"
  toml:
    filename:
      foreground: "$gnohj_color05"
  ini:
    filename:
      foreground: "$gnohj_color05"
  conf:
    filename:
      foreground: "$gnohj_color05"
  config:
    filename:
      foreground: "$gnohj_color05"
  env:
    filename:
      foreground: "$gnohj_color05"
  envrc:
    filename:
      foreground: "$gnohj_color05"

  # JavaScript - green
  js:
    filename:
      foreground: "$gnohj_color02"
  cjs:
    filename:
      foreground: "$gnohj_color02"
  mjs:
    filename:
      foreground: "$gnohj_color02"

  # TypeScript - blue
  ts:
    filename:
      foreground: "$gnohj_color04"
  tsx:
    filename:
      foreground: "$gnohj_color04"
  jsx:
    filename:
      foreground: "$gnohj_color04"

  # Shell scripts - green
  sh:
    filename:
      foreground: "$gnohj_color02"
  zsh:
    filename:
      foreground: "$gnohj_color02"
  bash:
    filename:
      foreground: "$gnohj_color02"
  fish:
    filename:
      foreground: "$gnohj_color02"

  # Chezmoi templates - cyan
  tmpl:
    filename:
      foreground: "$gnohj_color03"

  # Documentation - purple
  md:
    filename:
      foreground: "$gnohj_color01"
  mdx:
    filename:
      foreground: "$gnohj_color01"
  txt:
    filename:
      foreground: "$gnohj_color14"
  rst:
    filename:
      foreground: "$gnohj_color01"

  # Markup - salmon
  html:
    filename:
      foreground: "$gnohj_color06"
  htm:
    filename:
      foreground: "$gnohj_color06"
  xml:
    filename:
      foreground: "$gnohj_color06"
  svg:
    filename:
      foreground: "$gnohj_color06"

  # Styles - purple
  css:
    filename:
      foreground: "$gnohj_color01"
  scss:
    filename:
      foreground: "$gnohj_color01"
  sass:
    filename:
      foreground: "$gnohj_color01"
  less:
    filename:
      foreground: "$gnohj_color01"

  # Programming languages
  py:
    filename:
      foreground: "$gnohj_color05"
  rb:
    filename:
      foreground: "$gnohj_color11"
  rs:
    filename:
      foreground: "$gnohj_color06"
  go:
    filename:
      foreground: "$gnohj_color03"
  lua:
    filename:
      foreground: "$gnohj_color04"
  java:
    filename:
      foreground: "$gnohj_color06"
  c:
    filename:
      foreground: "$gnohj_color04"
  cpp:
    filename:
      foreground: "$gnohj_color04"
  h:
    filename:
      foreground: "$gnohj_color04"
  hpp:
    filename:
      foreground: "$gnohj_color04"
  php:
    filename:
      foreground: "$gnohj_color01"
  swift:
    filename:
      foreground: "$gnohj_color06"
  kt:
    filename:
      foreground: "$gnohj_color01"

  # Archives - red
  tar:
    filename:
      foreground: "$gnohj_color11"
  gz:
    filename:
      foreground: "$gnohj_color11"
  tgz:
    filename:
      foreground: "$gnohj_color11"
  zip:
    filename:
      foreground: "$gnohj_color11"
  rar:
    filename:
      foreground: "$gnohj_color11"
  7z:
    filename:
      foreground: "$gnohj_color11"
  bz2:
    filename:
      foreground: "$gnohj_color11"
  xz:
    filename:
      foreground: "$gnohj_color11"

  # Images - purple
  png:
    filename:
      foreground: "$gnohj_color01"
  jpg:
    filename:
      foreground: "$gnohj_color01"
  jpeg:
    filename:
      foreground: "$gnohj_color01"
  gif:
    filename:
      foreground: "$gnohj_color01"
  webp:
    filename:
      foreground: "$gnohj_color01"
  ico:
    filename:
      foreground: "$gnohj_color01"

  # Video - purple
  mp4:
    filename:
      foreground: "$gnohj_color01"
  mkv:
    filename:
      foreground: "$gnohj_color01"
  webm:
    filename:
      foreground: "$gnohj_color01"
  avi:
    filename:
      foreground: "$gnohj_color01"
  mov:
    filename:
      foreground: "$gnohj_color01"

  # Audio - yellow
  mp3:
    filename:
      foreground: "$gnohj_color05"
  flac:
    filename:
      foreground: "$gnohj_color05"
  wav:
    filename:
      foreground: "$gnohj_color05"
  ogg:
    filename:
      foreground: "$gnohj_color05"
  m4a:
    filename:
      foreground: "$gnohj_color05"

  # Git/ignored files - gray
  gitignore:
    filename:
      foreground: "$gnohj_color08"
  gitattributes:
    filename:
      foreground: "$gnohj_color08"
  dockerignore:
    filename:
      foreground: "$gnohj_color08"
  prettierignore:
    filename:
      foreground: "$gnohj_color08"
  eslintignore:
    filename:
      foreground: "$gnohj_color08"

  # Lock files - gray
  lock:
    filename:
      foreground: "$gnohj_color08"
  log:
    filename:
      foreground: "$gnohj_color08"

  # Data
  sql:
    filename:
      foreground: "$gnohj_color05"
  csv:
    filename:
      foreground: "$gnohj_color02"
  graphql:
    filename:
      foreground: "$gnohj_color06"
  prisma:
    filename:
      foreground: "$gnohj_color04"

  # Build/compiled - gray
  o:
    filename:
      foreground: "$gnohj_color08"
  pyc:
    filename:
      foreground: "$gnohj_color08"
  class:
    filename:
      foreground: "$gnohj_color08"
EOF

  echo "Eza theme updated at '$eza_theme_file'."
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
  "match_info_height": true,
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

generate_gh_dash_config() {
  # gh-dash's keybindings, PR/issue queries, repoPaths and layout are hand-
  # maintained in the chezmoi source (dot_config/gh-dash/config.yml) and applied
  # by chezmoi. Only the theme: block is theme-dependent, so - exactly like
  # generate_herdr_config - it is managed here as a marker-delimited block appended
  # at EOF and rewritten from the gnohj_color* palette. Both the live target AND the
  # chezmoi source are patched (no chezmoi-apply drift), so every non-theme section
  # has ONE owner: the chezmoi source. Edit keybindings/queries THERE, colors HERE.
  local gh_dash_target="$HOME/.config/gh-dash/config.yml"
  local gh_dash_source="$HOME/.local/share/chezmoi/dot_config/gh-dash/config.yml"

  local ghd_begin="# >>> colorscheme-set: gh-dash theme - generated, do not edit (see generate_gh_dash_config) >>>"
  local ghd_end="# <<< colorscheme-set: gh-dash theme <<<"
  local ghd_block
  ghd_block="$(
    cat <<EOF
$ghd_begin
theme:
  ui:
    table:
      showSeparator: true
      compact: false
  colors:
    text:
      primary: "$gnohj_color14"
      secondary: "$gnohj_color04"
      inverted: "$gnohj_color10"
      faint: "$gnohj_color09"
      warning: "$gnohj_color05"
      success: "$gnohj_color02"
      error: "$gnohj_color11"
    background:
      selected: "$gnohj_color13"
    border:
      primary: "$gnohj_color04"
      secondary: "$gnohj_color13"
      faint: "$gnohj_color17"
$ghd_end
EOF
  )"

  # Strip any prior managed block (idempotent) then re-append the fresh one at EOF,
  # in both the live target and the chezmoi source. [ -f ] || continue mirrors
  # generate_herdr_config: on a fresh machine (file not applied yet) this is a
  # no-op until chezmoi lays the base file down, then the next run themes it.
  local ghd_file
  for ghd_file in "$gh_dash_target" "$gh_dash_source"; do
    [ -f "$ghd_file" ] || continue
    GHD_BEGIN="$ghd_begin" GHD_END="$ghd_end" perl -0777 -i -pe \
      's/\n*\Q$ENV{GHD_BEGIN}\E.*?\Q$ENV{GHD_END}\E\n?//s' "$ghd_file"
    printf '\n%s\n' "$ghd_block" >>"$ghd_file"
  done
}

generate_gitmux_config() {
  gitmux_conf_file="$HOME/.config/gitmux/gitmux.yml"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$gitmux_conf_file")"

  cat >"$gitmux_conf_file" <<EOF
# Auto-generated by colorscheme-set.sh - do not edit directly
tmux:
  symbols:

    ahead: "👆"
    behind: "👇"
    clean: ""
    branch: ""
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

generate_pi_theme() {
  pi_theme_dir="$HOME/.pi/agent/themes"
  pi_theme_file="$pi_theme_dir/gnohj.json"

  mkdir -p "$pi_theme_dir"

  cat >"$pi_theme_file" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "gnohj",
  "vars": {
    "blue": "${gnohj_color04}",
    "green": "${gnohj_color02}",
    "aqua": "${gnohj_color03}",
    "purple": "${gnohj_color01}",
    "yellow": "${gnohj_color05}",
    "orange": "${gnohj_color06}",
    "red": "${gnohj_color11}",
    "text": "${gnohj_color14}",
    "comment": "${gnohj_color09}",
    "muted": "${gnohj_color08}",
    "dim": "${gnohj_color13}",
    "darkGray": "${gnohj_color17}",
    "selectedBg": "${gnohj_color17}",
    "codeBg": "#1c2632",
    "diffAddedBg": "#2a3a30",
    "diffRemovedBg": "${gnohj_color32}"
  },
  "colors": {
    "accent": "blue",
    "border": "muted",
    "borderAccent": "blue",
    "borderMuted": "darkGray",
    "success": "green",
    "error": "red",
    "warning": "yellow",
    "muted": "muted",
    "dim": "dim",
    "text": "",
    "thinkingText": "comment",

    "selectedBg": "selectedBg",
    "userMessageBg": "codeBg",
    "userMessageText": "",
    "customMessageBg": "diffAddedBg",
    "customMessageText": "",
    "customMessageLabel": "purple",
    "toolPendingBg": "codeBg",
    "toolSuccessBg": "diffAddedBg",
    "toolErrorBg": "diffRemovedBg",
    "toolTitle": "",
    "toolOutput": "comment",

    "mdHeading": "yellow",
    "mdLink": "blue",
    "mdLinkUrl": "dim",
    "mdCode": "aqua",
    "mdCodeBlock": "green",
    "mdCodeBlockBorder": "muted",
    "mdQuote": "comment",
    "mdQuoteBorder": "muted",
    "mdHr": "muted",
    "mdListBullet": "aqua",

    "toolDiffAdded": "green",
    "toolDiffRemoved": "red",
    "toolDiffContext": "comment",

    "syntaxComment": "comment",
    "syntaxKeyword": "purple",
    "syntaxFunction": "yellow",
    "syntaxVariable": "blue",
    "syntaxString": "green",
    "syntaxNumber": "orange",
    "syntaxType": "aqua",
    "syntaxOperator": "text",
    "syntaxPunctuation": "text",

    "thinkingOff": "darkGray",
    "thinkingMinimal": "muted",
    "thinkingLow": "blue",
    "thinkingMedium": "aqua",
    "thinkingHigh": "purple",
    "thinkingXhigh": "orange",

    "bashMode": "green"
  }
}
EOF

  echo "Pi theme updated at '$pi_theme_file'."
}

generate_claude_theme() {
  # Claude Code custom theme - mirrors generate_pi_theme's palette choices so the
  # two AI CLIs read identically. Claude file-watches ~/.claude/themes/, so a write
  # here hot-reloads any running session. base "dark-ansi" keeps CODE syntax on the
  # terminal's (gnohj) ANSI palette; the overrides below theme all the UI chrome in
  # gnohj truecolor. settings.json selects it via "theme": "custom:gnohj-theme".
  # Not chezmoi/monorepo-tracked (generated file) - colorscheme-set is sole owner.
  claude_theme_dir="$HOME/.claude/themes"
  claude_theme_file="$claude_theme_dir/gnohj-theme.json"

  mkdir -p "$claude_theme_dir"

  cat >"$claude_theme_file" <<EOF
{
  "name": "gnohj-theme",
  "base": "dark-ansi",
  "overrides": {
    "claude": "${gnohj_color03}",
    "text": "${gnohj_color14}",
    "inverseText": "${gnohj_color10}",
    "inactive": "${gnohj_color13}",
    "subtle": "${gnohj_color17}",
    "suggestion": "${gnohj_color03}",
    "permission": "${gnohj_color01}",
    "remember": "${gnohj_color01}",

    "success": "${gnohj_color02}",
    "error": "${gnohj_color11}",
    "warning": "${gnohj_color03}",
    "merged": "${gnohj_color01}",

    "promptBorder": "${gnohj_color03}",
    "planMode": "${gnohj_color03}",
    "autoAccept": "${gnohj_color02}",
    "bashBorder": "${gnohj_color02}",
    "ide": "${gnohj_color03}",
    "fastMode": "${gnohj_color21}",

    "diffAdded": "#2a3a30",
    "diffRemoved": "${gnohj_color32}",
    "diffAddedDimmed": "#1e2823",
    "diffRemovedDimmed": "#28201f",
    "diffAddedWord": "${gnohj_color02}",
    "diffRemovedWord": "${gnohj_color11}",

    "userMessageBackground": "#1c2632",
    "userMessageBackgroundHover": "#232f3c",
    "messageActionsBackground": "${gnohj_color17}",
    "bashMessageBackgroundColor": "#1e2a20",
    "memoryBackgroundColor": "#241f2a",
    "selectionBg": "${gnohj_color17}",

    "rate_limit_fill": "${gnohj_color04}",
    "rate_limit_empty": "${gnohj_color17}",
    "briefLabelYou": "${gnohj_color04}",
    "briefLabelClaude": "${gnohj_color02}",

    "claudeShimmer": "${gnohj_color12}",
    "warningShimmer": "${gnohj_color12}",
    "permissionShimmer": "${gnohj_color52}",
    "promptBorderShimmer": "${gnohj_color12}",
    "inactiveShimmer": "${gnohj_color46}",
    "fastModeShimmer": "${gnohj_color52}",

    "red_FOR_SUBAGENTS_ONLY": "${gnohj_color11}",
    "blue_FOR_SUBAGENTS_ONLY": "${gnohj_color04}",
    "green_FOR_SUBAGENTS_ONLY": "${gnohj_color02}",
    "yellow_FOR_SUBAGENTS_ONLY": "${gnohj_color05}",
    "purple_FOR_SUBAGENTS_ONLY": "${gnohj_color01}",
    "orange_FOR_SUBAGENTS_ONLY": "${gnohj_color15}",
    "pink_FOR_SUBAGENTS_ONLY": "${gnohj_color06}",
    "cyan_FOR_SUBAGENTS_ONLY": "${gnohj_color03}"
  }
}
EOF

  echo "Claude Code theme updated at '$claude_theme_file'."
}

generate_herdr_config() {
  # herdr draws its own UI (panels, split-pane borders, sidebar). Two knobs feed
  # its colors, both mapped here from the gnohj_color* palette so herdr tracks
  # the active scheme like every other tool:
  #
  #   * [theme.custom] - the full 15-token palette herdr accepts (Catppuccin role
  #     names: panel_bg, surface0/1, surface_dim, overlay0/1, text, subtext0,
  #     mauve, green, yellow, red, blue, teal, peach). Managed as a marker-
  #     delimited block appended at EOF, so the hand-maintained [keys]/[remote]/
  #     [session] config is never touched. panel_bg stays "reset" to preserve the
  #     terminal background (herdr draws over it - keeps transparency working).
  #   * [ui] accent - the active/focused border + nav highlight. It is NOT a
  #     [theme.custom] token, so it is kept on its own line (retarget existing,
  #     else inject under [ui]). Matched to gnohj_color03, identical to the tmux
  #     active-pane border, so the focus cue is the same in herdr and plain tmux.
  #
  # Both the live target AND the chezmoi source are patched (no `chezmoi apply`
  # drift; same spirit as tracking active-colorscheme.sh), then a running herdr
  # is hot-reloaded. perl -i keeps the in-place edits portable across macOS/Linux;
  # colors pass via env so the perl expressions need no shell-quote gymnastics.
  local herdr_accent="$gnohj_color03"
  local herdr_target="$HOME/.config/herdr/config.toml"
  local herdr_source="$HOME/.local/share/chezmoi/dot_config/herdr/config.toml"

  local herdr_begin="# >>> colorscheme-set: herdr theme palette - generated, do not edit (see generate_herdr_config) >>>"
  local herdr_end="# <<< colorscheme-set: herdr theme palette <<<"
  local herdr_block
  herdr_block="$(
    cat <<EOF
$herdr_begin
[theme.custom]
panel_bg = "reset"
# surface_dim drives the sidebar active/selected row bg and surface0 the inactive
# tab bg (verified live against herdr 0.7.3). Both set to gnohj_color26 - the same
# dark tint tmux-dash uses for its active-session row (bg_active_session) - so the
# active item reads as that subtle near-bg fill. surface1 tracks them for a flat ramp.
surface_dim = "$gnohj_color26"
surface0 = "$gnohj_color26"
surface1 = "$gnohj_color26"
overlay0 = "$gnohj_color13"
overlay1 = "$gnohj_color46"
# herdr sidebar token map (verified via diagnostic): text = active/focused row's
# whole line (workspace+tab), subtext0 = inactive rows' whole line, mauve = active
# space's branch line. These tokens are SHARED by the spaces AND agents sections,
# so they can't be set per-panel. subtext0 = gnohj blue (agents/inactive rows),
# text = default, mauve = green (only the active space's branch line).
subtext0 = "$gnohj_color04"
text = "$gnohj_color14"
mauve = "#c2f0db"
# herdr colors the agent "idle" state with its green token and the "working" state
# with its yellow token (both verified live). Point green at gnohj_color05 (idle)
# and yellow at gnohj_color04 (working) so the two states read yellow/blue exactly
# like tmux-dash's @chip_idle / @chip_working. NOTE: herdr has no per-state color
# config, so any other element using green/yellow shifts with them.
green = "$gnohj_color05"
yellow = "$gnohj_color04"
red = "$gnohj_color11"
blue = "$gnohj_color04"
teal = "$gnohj_color03"
peach = "$gnohj_color06"
# Copy-mode (visual selection) highlight - herdr's src/selection.rs reads these
# two CustomThemeColors fields. Point them at the exact pair tmux's mode-style
# uses (generate-tmux-colors.sh: "bg=\$gnohj_color13,fg=\$gnohj_color02") so a
# selection in a herdr pane reads identically to one in tmux copy-mode: slate
# bg (color13) under green text (color02).
selection_background = "$gnohj_color13"
selection_foreground = "$gnohj_color02"
$herdr_end
EOF
  )"

  local herdr_file
  for herdr_file in "$herdr_target" "$herdr_source"; do
    [ -f "$herdr_file" ] || continue

    # 1) [ui] accent: retarget an existing line, else inject under [ui]. The
    #    inject branch is what makes this work on a target that predates the
    #    accent line (fresh machine, or before the first `chezmoi apply`) -
    #    without it the generator would be a silent no-op there.
    if grep -qE '^[[:space:]]*accent[[:space:]]*=' "$herdr_file"; then
      HERDR_ACCENT="$herdr_accent" perl -i -pe \
        's/^(\s*accent\s*=).*/$1 "$ENV{HERDR_ACCENT}"/' "$herdr_file"
    elif grep -qE '^\[ui\][[:space:]]*$' "$herdr_file"; then
      HERDR_ACCENT="$herdr_accent" perl -i -pe \
        'if (/^\[ui\]\s*$/) { $_ .= "accent = \"$ENV{HERDR_ACCENT}\"\n" }' "$herdr_file"
    fi

    # 2) [theme.custom] palette: strip any prior managed block (idempotent), then
    #    re-append the freshly-interpolated one at EOF.
    HERDR_BEGIN="$herdr_begin" HERDR_END="$herdr_end" perl -0777 -i -pe \
      's/\n*\Q$ENV{HERDR_BEGIN}\E.*?\Q$ENV{HERDR_END}\E\n?//s' "$herdr_file"
    printf '\n%s\n' "$herdr_block" >>"$herdr_file"
  done

  # Hot-reload a running herdr server so colors update without a restart.
  if command -v herdr >/dev/null 2>&1; then
    herdr server reload-config >/dev/null 2>&1 || true
  fi
  echo "herdr configuration updated (full palette + accent=$herdr_accent)."
}

# Always source the active colorscheme + regenerate the small config
# files whose generation logic may have changed independently of the
# theme (e.g. lazygit customCommands, lazydocker keymaps). Cheap — just
# rewrites a few KB of YAML. The heavier theme-switch actions (sketchybar
# reload, ghostty/kitty/btop reload, wallpaper, etc.) stay gated behind
# UPDATED below so unchanged-theme calls don't churn UI.
if [ -f "$active_file" ]; then
  source "$active_file"
  generate_lazygit_config 2>/dev/null || true
  generate_lazydocker_config 2>/dev/null || true
fi

# If there's an update, replace the active colorscheme and perform necessary actions
if [ "$UPDATED" = true ]; then
  echo "Updating active colorscheme to '$colorscheme_profile'."

  # Replace the contents of active-colorscheme.sh
  cp "$colorscheme_file" "$active_file"

  cp "$colorscheme_file" "$HOME/.config/nvim/lua/config/active-colorscheme.sh"

  # Source the active colorscheme to load variables
  source "$active_file"

  # Reload sketchybar to pick up new colors (macOS menu bar — skip on Linux/VPS)
  [[ "$OSTYPE" == darwin* ]] && sketchybar --reload

  # Generate Starship config files (kept for easy switching)
  generate_starship_config

  # Generate lazygit config
  generate_lazygit_config

  # Generate lazydocker config
  generate_lazydocker_config

  # Generate the ghostty theme file, then reload config. SIGUSR2 is ghostty's
  # documented reload signal (systemd ExecReload sends it on Linux; the macOS
  # build honors it too - verified live). Signal-based reload is focus-INDEPENDENT,
  # exactly like kitty's `pkill -USR1 -x kitty` above. The prior osascript sent
  # cmd+shift+, via System Events, which lands on the FRONTMOST app - so running
  # the theme picker from the kitty quick-access terminal reloaded kitty (signal)
  # but never reached ghostty (keystroke went to kitty), leaving ghostty's bg stale.
  # Terminal themes (ghostty/kitty) are for the LOCAL terminal app. On a headless VPS
  # there's no terminal to theme — your colors come from your Mac's ghostty either way,
  # and tmux/nvim/tool colors below still regenerate on Linux. So skip these on Linux.
  if [[ "$OSTYPE" == darwin* ]]; then
    generate_ghostty_theme
    pkill -USR2 -x ghostty 2>/dev/null || true
    generate_kitty_theme
  fi

  # Generate the btop theme
  generate_btop_theme

  # Generate bat config
  generate_bat_config

  # Generate delta config
  generate_delta_config

  # Generate hunk config
  generate_hunk_config

  # Generate borders config (macOS window borders + aerospace — skip on Linux/VPS)
  [[ "$OSTYPE" == darwin* ]] && generate_borders_config

  # Generate gitmux config
  generate_gitmux_config

  # Generate gh-dash config
  generate_gh_dash_config

  # Generate pi theme
  generate_pi_theme

  # Generate Claude Code theme (custom theme, hot-reloaded via ~/.claude/themes watch)
  generate_claude_theme

  # Regenerate herdr's theme palette ([theme.custom] + [ui] accent) + hot-reload
  generate_herdr_config

  # Generate yazi theme
  generate_yazi_theme

  # Generate ghosttyfetch config (macOS terminal-fetch cosmetic — skip on Linux/VPS)
  [[ "$OSTYPE" == darwin* ]] && generate_ghosttyfetch_config

  # Generate eza theme
  generate_eza_theme

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
