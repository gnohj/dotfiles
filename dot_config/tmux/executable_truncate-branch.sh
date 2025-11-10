#!/usr/bin/env bash

LOG_FILE="$HOME/.logs/tmux-truncate-branch.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}

# Source gnohj color variables
# shellcheck disable=SC1090
source "$HOME/.config/colorscheme/active/active-colorscheme.sh" 2>/dev/null

# Read gitmux output from stdin or as argument
input="${1:-$(cat)}"
log "Input received: $input"
log "Current directory: $(pwd)"

if [ -n "$input" ]; then
  # Get PR number for current branch
  log "Calling get-pr-number.sh from $(pwd)"
  PR_NUM=$("$HOME/.config/tmux/get-pr-number.sh" "$(pwd)")
  log "PR_NUM returned: '$PR_NUM'"

  # Step 1: Always truncate branch names (if 3+ hyphens)
  log "Applying truncation logic to branch name"
  output=$(perl -pe '
    # Find branch names after ] and before space or other formatting
    if (/\]([A-Za-z0-9_-]+)(\s)/) {
      my $branch = $1;
      my $space = $2;

      # Count hyphens
      my $hyphen_count = ($branch =~ tr/-//);

      # If 4 or more hyphens, remove last segment
      if ($hyphen_count >= 4) {
        $branch =~ s/-[^-]*$//;
      }

      s/\]([A-Za-z0-9_-]+)(\s)/]${branch}${space}/;
    }
  ' <<<"$input")

  # Step 2: If PR exists, append it to the already-truncated branch
  if [ -n "$PR_NUM" ]; then
    log "PR exists, appending PR number with color: $gnohj_color03"
    output=$(PR_NUM="$PR_NUM" PR_COLOR="$gnohj_color03" perl -pe '
      # Find the truncated branch name and append PR number
      if (/\]([A-Za-z0-9_-]+)(\s)/) {
        my $branch = $1;
        my $space = $2;
        my $pr_num = $ENV{PR_NUM};
        my $pr_color = $ENV{PR_COLOR};
        my $pr_suffix = " #[fg=$pr_color]#$pr_num";
        s/\]([A-Za-z0-9_-]+)(\s)/]${branch}${pr_suffix}${space}/;
      }
    ' <<<"$output")
  fi

  log "Output: '$output'"

  # If output is empty, regex didn't match, just return input unchanged
  if [ -z "$output" ]; then
    log "Regex didn't match, returning input unchanged"
    echo "$input"
  else
    echo "$output"
  fi
fi
