#!/bin/bash

# Treekanga repo selector - opens treekanga TUI for selected bare repo
# Reads repos from treekanga.yml config

export PATH="/opt/homebrew/bin:$PATH"
export TERM="xterm-256color"

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

color_string="list-border:6,input-border:${gnohj_color04},preview-border:4,header-bg:-1,header-border:6,bg+:${gnohj_color13},fg+:${gnohj_color02},hl+:${gnohj_color04},fg:${gnohj_color02},info:${gnohj_color09},prompt:${gnohj_color04},pointer:${gnohj_color04},marker:${gnohj_color04},header:${gnohj_color09}"

tmux display-popup -E -w 28% -h 40% -b none "
  export PATH=\"/opt/homebrew/bin:\$PATH\"
  CONFIG_FILE=\"\$HOME/.config/treekanga/treekanga.yml\"

  REPOS=\$(grep -E '^  [a-zA-Z0-9_-]+:\$' \"\$CONFIG_FILE\" | sed 's/^  //' | sed 's/:\$//' | awk '{print \"📂 \" \$0}')

  SELECTED=\$(echo \"\$REPOS\" | fzf --no-border \
    --ansi \
    --list-border \
    --no-sort \
    --prompt '🌳 ' \
    --gutter=' ' \
    --color '${color_string}' \
    --input-border \
    --bind 'tab:down,btab:up')

  if [[ -z \"\$SELECTED\" ]]; then
    exit 0
  fi

  SELECTED=\$(echo \"\$SELECTED\" | awk '{print \$2}')

  # Get worktreeTargetDir for selected repo
  WORKTREE_DIR=\$(awk -v repo=\"\$SELECTED\" '
    \$0 ~ \"^  \" repo \":\$\" { found=1; next }
    found && /^  [a-zA-Z]/ { found=0 }
    found && /worktreeTargetDir:/ { gsub(/.*worktreeTargetDir: */, \"\"); print; exit }
  ' \"\$CONFIG_FILE\")

  # Get bareRepoName (usually .git)
  BARE_NAME=\$(awk -v repo=\"\$SELECTED\" '
    \$0 ~ \"^  \" repo \":\$\" { found=1; next }
    found && /^  [a-zA-Z]/ { found=0 }
    found && /bareRepoName:/ { gsub(/.*bareRepoName: */, \"\"); print; exit }
  ' \"\$CONFIG_FILE\")

  BARE_REPO_PATH=\"\$HOME/\$WORKTREE_DIR/\${BARE_NAME:-.git}\"

  tmux new-window -n '🌳' -c \"\$BARE_REPO_PATH\" 'export PATH=\"/opt/homebrew/bin:\$PATH\"; /opt/homebrew/bin/treekanga tui'
"
