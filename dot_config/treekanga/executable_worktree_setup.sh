#!/usr/bin/env bash

set -e

CURRENT_WORKTREE="$(pwd)"

# Detect repo from path (e.g., ~/Developer/inferno/feature-x → inferno)
REPO_NAME=$(echo "$CURRENT_WORKTREE" | sed -n 's|.*/Developer/\([^/]*\)/.*|\1|p')

# Map repo to main worktree directory name
case "$REPO_NAME" in
inferno) MAIN_DIR="_develop" ;;
web) MAIN_DIR="_master" ;;
*)
  # Dynamically detect default branch for unknown repos
  REPO_ROOT="$HOME/Developer/$REPO_NAME"
  DEFAULT_BRANCH=$(git -C "$REPO_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [ -z "$DEFAULT_BRANCH" ]; then
    # Fallback: check for common branch names
    for branch in main master develop; do
      if [ -d "$REPO_ROOT/_$branch" ]; then
        DEFAULT_BRANCH="$branch"
        break
      fi
    done
  fi
  if [ -z "$DEFAULT_BRANCH" ]; then
    echo "Could not detect default branch for: $REPO_NAME"
    exit 1
  fi
  MAIN_DIR="_$DEFAULT_BRANCH"
  ;;
esac

MAIN_WORKTREE="$HOME/Developer/$REPO_NAME/$MAIN_DIR"
IS_MAIN_WORKTREE=false
if [ "$CURRENT_WORKTREE" = "$MAIN_WORKTREE" ]; then
  IS_MAIN_WORKTREE=true
fi

echo "Setting up $REPO_NAME worktree..."

# Create tasks symlink to Obsidian (for <leader>ft in nvim) - applies to ALL worktrees
OBSIDIAN_TASKS="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/second-brain/Tasks/$REPO_NAME"
if [ -d "$OBSIDIAN_TASKS" ] && [ ! -e "tasks" ]; then
  echo "Creating tasks symlink to Obsidian..."
  ln -s "$OBSIDIAN_TASKS" tasks
elif [ -L "tasks" ]; then
  echo "Tasks symlink already exists"
elif [ -d "tasks" ]; then
  echo "Warning: tasks directory exists but is not a symlink"
fi

# Skip remaining setup for main worktree
if [ "$IS_MAIN_WORKTREE" = true ]; then
  echo "$REPO_NAME main worktree setup complete!"
  exit 0
fi

# Copy .env files from main worktree if they exist
for env_file in .env .env.local .env.development .env.development.local; do
  if [ -f "$MAIN_WORKTREE/$env_file" ] && [ ! -f "$env_file" ]; then
    echo "Copying $env_file from main worktree..."
    cp "$MAIN_WORKTREE/$env_file" "$env_file"
  fi
done

# Install dependencies
if [ -f "pnpm-lock.yaml" ]; then
  echo "Installing dependencies with pnpm..."
  pnpm install
elif [ -f "package-lock.json" ]; then
  echo "Installing dependencies with npm..."
  npm install
elif [ -f "yarn.lock" ]; then
  echo "Installing dependencies with yarn..."
  yarn install
fi

echo "$REPO_NAME worktree setup complete!"

# Notify tmux session if running with sesh (session name = repo/worktree)
WORKTREE_NAME=$(basename "$CURRENT_WORKTREE")
SESSION_NAME="$REPO_NAME/$WORKTREE_NAME"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux display-message -d 5000 -t "$SESSION_NAME" "✅ $WORKTREE_NAME post script complete!"
fi
