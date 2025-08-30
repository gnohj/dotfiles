#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
# shellcheck disable=SC1091

# This script generates the automatic-rename-format string from emoji definitions
# It reads emoji mappings and builds the complex conditional format string dynamically

CONFIG_FILE="$HOME/.config/tmux/window-emojis.conf"

# Read all emoji definitions from the config file
declare -A emojis

while IFS= read -r line; do
  if [[ $line =~ ^set\ -g\ @emoji_([a-z]+)\ \"(.+)\"$ ]]; then
    cmd="${BASH_REMATCH[1]}"
    emoji="${BASH_REMATCH[2]}"
    emojis["$cmd"]="$emoji"
  fi
done <"$CONFIG_FILE"

# Build the format string dynamically
format=""

# Special handling for commands that use pattern matching (m:*)
for cmd in vim nvim; do
  if [[ -n "${emojis[$cmd]}" ]]; then
    format="${format}#{?#{m:*${cmd},#{pane_current_command}},${emojis[$cmd]},"
  fi
done

# Add exact matches for other commands
for cmd in zsh bash fish node npm yarn pnpm python docker git lazygit btop htop yazi ssh cargo go ruby java mysql psql redis mongo curl wget; do
  if [[ -n "${emojis[$cmd]}" ]]; then
    format="${format}#{?#{==:#{pane_current_command},${cmd}},${emojis[$cmd]},"
  fi
done

# Add default emoji and close all conditionals
default="${emojis[default]:-💻}"
# Count the number of conditions we opened
num_conditions=$(echo "$format" | grep -o "#{?" | wc -l)
# Add the default and close all braces
format="${format}${default}"
for ((i = 0; i < $num_conditions; i++)); do
  format="${format}}"
done

# Set the tmux option
tmux set-option -g automatic-rename-format "$format"
