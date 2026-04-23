#!/bin/bash
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dirty_repos_notification}"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/dirty_repos_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [DIRTY_REPOS] $message" >>"$LOG_FILE"
}

REPOS_FILE="$HOME/.config/repos.txt"
DIRTY_NAMES=()

# Read repos from repos.txt
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  local_path="${line##* }"
  local_path="${local_path/#\~/$HOME}"
  if [ -e "$local_path/.git" ]; then
    status=$(git -C "$local_path" status --porcelain 2>/dev/null)
    unpushed=$(git -C "$local_path" rev-list --count @{u}..HEAD 2>/dev/null)
    if [ -n "$status" ] || [ "${unpushed:-0}" -gt 0 ]; then
      DIRTY_NAMES+=("$(basename "$local_path")")
    fi
  fi
done < "$REPOS_FILE"

# Also check chezmoi
if [ -e "$HOME/.local/share/chezmoi/.git" ]; then
  status=$(git -C "$HOME/.local/share/chezmoi" status --porcelain 2>/dev/null)
  unpushed=$(git -C "$HOME/.local/share/chezmoi" rev-list --count @{u}..HEAD 2>/dev/null)
  if [ -n "$status" ] || [ "${unpushed:-0}" -gt 0 ]; then
    DIRTY_NAMES+=("chezmoi")
  fi
fi

# Also check ~/Developer repos (fd for speed)
if command -v fd &>/dev/null; then
  while IFS= read -r gitdir; do
    gitdir="${gitdir%/}"
    repo_path="${gitdir%/.git}"
    status=$(git -C "$repo_path" status --porcelain 2>/dev/null)
    unpushed=$(git -C "$repo_path" rev-list --count @{u}..HEAD 2>/dev/null)
    if [ -n "$status" ] || [ "${unpushed:-0}" -gt 0 ]; then
      DIRTY_NAMES+=("$(basename "$repo_path")")
    fi
  done < <(fd -H '^\.git$' "$HOME/Developer" --max-depth 4 --exclude node_modules 2>/dev/null)
fi

# Deduplicate
DIRTY_NAMES=($(printf '%s\n' "${DIRTY_NAMES[@]}" | sort -u))
DIRTY_COUNT=${#DIRTY_NAMES[@]}

# Update sketchybar
if [ "$DIRTY_COUNT" -eq 0 ]; then
  COLOR=$GREEN
  LABEL="􀆅"
elif [ "$DIRTY_COUNT" -le 3 ]; then
  COLOR=$ORANGE
  LABEL="$DIRTY_COUNT"
else
  COLOR=$RED
  LABEL="$DIRTY_COUNT"
fi

sketchybar --set "$NAME" \
  label="$LABEL" \
  label.color="$COLOR"

if [ "$DIRTY_COUNT" -gt 0 ]; then
  log_message "INFO" "Dirty repos ($DIRTY_COUNT): ${DIRTY_NAMES[*]}"
else
  log_message "INFO" "All repos clean"
fi
