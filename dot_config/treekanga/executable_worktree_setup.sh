#!/usr/bin/env bash

set -e

CURRENT_WORKTREE="$(pwd)"

# treekanga v2 captures the postScript's stdout/stderr via shell.CmdWithDir
# and discards the result, so anything we `echo` from here is invisible to
# the calling terminal (kitty window, tmux pane, etc.). Mirror every status
# line into a per-run log file so callers (e.g. ~/.local/bin/jira-worktree)
# can tail it post-hoc and surface what actually happened.
LOGFILE="$HOME/.logs/treekanga-postscript.log"
mkdir -p "$(dirname "$LOGFILE")"
log() {
  local msg="$*"
  echo "$msg" # treekanga discards this
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$msg" >>"$LOGFILE"
}
log "=== START $CURRENT_WORKTREE ==="

# treekanga's postScript runs in whatever shell context spawned `treekanga add`
# (often bash without mise's interactive hooks), so the wrong node ends up
# active and pnpm warns about engine mismatch. Put mise shims first on PATH
# so node/pnpm/npm/yarn resolve to the version specified by .mise.toml /
# .tool-versions in the worktree.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

# ~/.zsh_gnohj_env is the user's full environment file (bash-safe) — it
# exports PNPM_HOME, GIT_AUTHOR_*, XDG paths, and chains into the secrets
# file (GPR_AUTH_TOKEN, NPM_TOKEN, etc.) and any .local overrides. Without
# this, the postScript runs with a different PNPM_HOME than interactive
# zsh, so pnpm uses a different store path. The next interactive `pn i`
# detects the layout mismatch and helpfully nukes node_modules to recreate
# from the user's actual store — wasting the install we just did. Sourcing
# this file aligns the contexts and makes the postScript install reusable.
if [ -f "$HOME/.zsh_gnohj_env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.zsh_gnohj_env"
fi
if command -v mise &>/dev/null; then
  mise install -y 2>/dev/null || true
fi

# Detect repo from path (e.g., ~/Developer/inferno/feature-x → inferno)
REPO_NAME=$(echo "$CURRENT_WORKTREE" | sed -n 's|.*/Developer/\([^/]*\)/.*|\1|p')

# Map repo to main worktree directory name
case "$REPO_NAME" in
inferno) MAIN_DIR="develop" ;;
web) MAIN_DIR="master" ;;
*)
  # Dynamically detect default branch for unknown repos
  REPO_ROOT="$HOME/Developer/$REPO_NAME"
  DEFAULT_BRANCH=$(git -C "$REPO_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [ -z "$DEFAULT_BRANCH" ]; then
    # Fallback: check for common branch names
    for branch in main master develop; do
      if [ -d "$REPO_ROOT/$branch" ]; then
        DEFAULT_BRANCH="$branch"
        break
      fi
    done
  fi
  if [ -z "$DEFAULT_BRANCH" ]; then
    echo "Could not detect default branch for: $REPO_NAME"
    exit 1
  fi
  MAIN_DIR="$DEFAULT_BRANCH"
  ;;
esac

MAIN_WORKTREE="$HOME/Developer/$REPO_NAME/$MAIN_DIR"
IS_MAIN_WORKTREE=false
if [ "$CURRENT_WORKTREE" = "$MAIN_WORKTREE" ]; then
  IS_MAIN_WORKTREE=true
fi

log "Setting up $REPO_NAME worktree..."

# Skip remaining setup for main worktree
if [ "$IS_MAIN_WORKTREE" = true ]; then
  log "$REPO_NAME main worktree setup complete!"
  log "=== END ==="
  exit 0
fi

# treekanga v2 removed auto-zoxide and sesh integration; replicate it here.
# Behavior is split based on `$TMUX`:
#   - TMUX set  →  TUI / manual flow (user already in tmux). Auto-attach
#                  via sesh — matches v1 `add -s` behavior.
#   - TMUX unset → headless wrapper flow (jira-worktree / worktree-prompt
#                  spawned a fresh Terminal). Don't switch anyone's client;
#                  pbcopy the session name so the user can paste it into
#                  their preferred switcher.
if command -v zoxide &>/dev/null; then
  # Match the interactive zshrc's custom DB location ($ZDOTDIR). Without
  # this, non-interactive invocations (treekanga -x, claude -p, etc.) write
  # to zoxide's default DB at ~/.local/share/zoxide/db.zo — which the
  # user's `z` command never reads, so the entry effectively vanishes.
  export _ZO_DATA_DIR="$HOME/.config/zshrc"
  if zoxide add "$CURRENT_WORKTREE" 2>>"$LOGFILE"; then
    log "✓ zoxide registered ($CURRENT_WORKTREE)"
  else
    log "✗ zoxide add failed"
  fi
else
  log "· zoxide not on PATH, skipped"
fi

if [ -n "$TMUX" ] && command -v sesh &>/dev/null; then
  if sesh connect "$CURRENT_WORKTREE" 2>>"$LOGFILE"; then
    log "✓ sesh session connected"
  else
    log "✗ sesh connect failed"
  fi
elif command -v pbcopy &>/dev/null; then
  # Use the path relative to ~/Developer/ so the folder bucket survives.
  # ~/Developer/web/infra/test-test → "web/infra/test-test"
  # basename(...) would give just "test-test"; prepending REPO_NAME loses
  # the bucket. Older worktrees show full bucket paths in tmux/gitmux
  # because sesh auto-derives names from the zoxide cwd (which uses the
  # full relative path); we match that here so new sessions look identical.
  CLIPBOARD_VALUE="${CURRENT_WORKTREE#$HOME/Developer/}"
  printf '%s' "$CLIPBOARD_VALUE" | pbcopy 2>>"$LOGFILE" &&
    log "✓ session name copied to clipboard ($CLIPBOARD_VALUE)" ||
    log "✗ pbcopy failed"
else
  log "· no \$TMUX and no pbcopy; user must navigate manually"
fi

# Copy .env files from main worktree if they exist
copied_envs=0
for env_file in .env .env.local .env.development .env.development.local; do
  if [ -f "$MAIN_WORKTREE/$env_file" ] && [ ! -f "$env_file" ]; then
    if cp "$MAIN_WORKTREE/$env_file" "$env_file" 2>>"$LOGFILE"; then
      log "✓ copied $env_file from main"
      copied_envs=$((copied_envs + 1))
    else
      log "✗ failed to copy $env_file"
    fi
  fi
done
[ "$copied_envs" -eq 0 ] && log "· no .env files to copy from main"

# Install dependencies (timed; capture output to log only — pnpm is noisy)
install_start=$(date +%s)
if [ -f "pnpm-lock.yaml" ]; then
  log "→ pnpm install starting…"
  if pnpm install >>"$LOGFILE" 2>&1; then
    log "✓ pnpm install completed in $(($(date +%s) - install_start))s"
  else
    log "✗ pnpm install failed (see $LOGFILE for details)"
    log "=== END ==="
    exit 1
  fi
elif [ -f "package-lock.json" ]; then
  log "→ npm install starting…"
  if npm install >>"$LOGFILE" 2>&1; then
    log "✓ npm install completed in $(($(date +%s) - install_start))s"
  else
    log "✗ npm install failed"
    log "=== END ==="
    exit 1
  fi
elif [ -f "yarn.lock" ]; then
  log "→ yarn install starting…"
  if yarn install >>"$LOGFILE" 2>&1; then
    log "✓ yarn install completed in $(($(date +%s) - install_start))s"
  else
    log "✗ yarn install failed"
    log "=== END ==="
    exit 1
  fi
else
  log "· no lockfile, skipping install"
fi

if [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
  codegen_start=$(date +%s)
  log "→ pnpm codegen starting…"
  if pnpm -r --if-present run codegen >>"$LOGFILE" 2>&1; then
    log "✓ pnpm codegen completed in $(($(date +%s) - codegen_start))s"
  else
    log "✗ pnpm codegen failed (see $LOGFILE — non-fatal, run manually if needed)"
  fi
fi

log "$REPO_NAME worktree setup complete!"
log "=== END ==="

# Notify tmux session if running with sesh. Session name mirrors sesh's
# zoxide-derived format: path relative to ~/Developer (includes the
# folder bucket if present, e.g. "web/infra/test-test").
WORKTREE_NAME=$(basename "$CURRENT_WORKTREE")
SESSION_NAME="${CURRENT_WORKTREE#$HOME/Developer/}"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux display-message -d 5000 -t "$SESSION_NAME" "✅ $WORKTREE_NAME post script complete!"
fi

# Close the treekanga selector window if this postScript was launched from it
# (rctrl-semi opens a window named '🌳' running `treekanga tui`). Killing it
# here also terminates the parent treekanga process — fine, it has nothing
# left to do.
if command -v tmux &>/dev/null; then
  tmux list-windows -a -F '#{session_name}:#{window_index}|#{window_name}' 2>/dev/null |
    awk -F'|' '$2 == "🌳" { print $1 }' |
    while read -r target; do
      tmux kill-window -t "$target" 2>/dev/null || true
    done
fi
