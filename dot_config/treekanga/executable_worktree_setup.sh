#!/usr/bin/env bash

set -e

CURRENT_WORKTREE="$(pwd)"

# treekanga v2 captures the postScript's stdout/stderr via shell.CmdWithDir
# and discards the result, so anything we `echo` from here is invisible to
# the calling terminal (kitty window, tmux pane, etc.). Mirror every status
# line into a log file so callers (e.g. ~/.local/bin/worktree-runner and
# the worktree-* entry points) can tail it post-hoc and surface what
# actually happened.
#
# Honor TREEKANGA_POSTSCRIPT_LOG when set — the runner uses this to give
# each invocation its own per-run log file, eliminating byte-offset
# accounting and the cross-run race when two runners fire near-simultaneously
# (each would read the other's postScript output via shared log tail).
# When unset (TUI / interactive treekanga add), fall back to the global log.
LOGFILE="${TREEKANGA_POSTSCRIPT_LOG:-$HOME/.logs/treekanga-postscript.log}"
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
#   - TMUX unset → headless wrapper flow (worktree-runner spawned a
#                  fresh Terminal via worktree-jira / worktree-prompt /
#                  worktree-clipboard / worktree-bug). Don't switch
#                  anyone's client;
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

# Thread state file: a JSON doc that links this worktree to its branch +
# tmux session + (later, when discovered) vault note + PR URL. Read by
# recon to surface 📝🎟️🔀 badges in tmux-dash and by the rctrl-i "open
# notes" launcher item. Idempotent — re-runs of treekanga on the same
# worktree don't overwrite; recon bumps `last_seen_at` on each poll.
THREAD_BRANCH=$(git -C "$CURRENT_WORKTREE" branch --show-current 2>/dev/null || true)
if [ -n "$THREAD_BRANCH" ]; then
  THREAD_DIR="$HOME/.local/state/threads"
  mkdir -p "$THREAD_DIR" 2>>"$LOGFILE"
  # ID = first JIRA-style ticket key in the branch (e.g. IHRWEB-1234), else
  # the worktree basename as a slug (kind=untracked).
  if [[ "$THREAD_BRANCH" =~ ([A-Z]+-[0-9]+) ]]; then
    THREAD_ID="${BASH_REMATCH[1]}"
    THREAD_KIND="ticket"
  else
    THREAD_ID="$(basename "$CURRENT_WORKTREE")"
    THREAD_KIND="untracked"
  fi
  THREAD_FILE="$THREAD_DIR/$THREAD_ID.json"
  THREAD_SESSION="${CURRENT_WORKTREE#$HOME/Developer/}"
  if [ ! -f "$THREAD_FILE" ]; then
    NOW="$(date -u +%FT%TZ)"
    cat >"$THREAD_FILE" <<EOF
{
  "id": "$THREAD_ID",
  "kind": "$THREAD_KIND",
  "repo": "$REPO_NAME",
  "branch": "$THREAD_BRANCH",
  "worktree": "$CURRENT_WORKTREE",
  "tmux_session": "$THREAD_SESSION",
  "vault_note": null,
  "pr_url": null,
  "created_at": "$NOW",
  "last_seen_at": "$NOW"
}
EOF
    log "✓ thread state written ($THREAD_FILE)"
  else
    log "· thread state already exists ($THREAD_FILE)"
  fi
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

# Copy .env files from main worktree if they exist. Covers repo-root envs
# (.env, .env.local, …) AND nested per-app envs (apps/<app>/.env*). The account
# app reads APP_TOKEN from apps/account/.env for RadioEdit ObjectDB oAuth; the
# old root-only loop never propagated it, so every new worktree hit the login
# error until copied by hand. Discovery (not a hardcoded app list) means a new
# app's .env is picked up automatically, and apps that need none — e.g. listen,
# which fetches its token at runtime — are simply skipped. .env.example is a
# tracked template, never a secret to copy.
copied_envs=0
env_files=(.env .env.local .env.development .env.development.local)
if [ -d "$MAIN_WORKTREE/apps" ]; then
  while IFS= read -r abs; do
    env_files+=("${abs#"$MAIN_WORKTREE"/}")
  done < <(find "$MAIN_WORKTREE/apps" -maxdepth 2 -type f \
    \( -name '.env' -o -name '.env.*' \) ! -name '.env.example' 2>/dev/null)
fi
for env_file in "${env_files[@]}"; do
  if [ -f "$MAIN_WORKTREE/$env_file" ] && [ ! -f "$env_file" ]; then
    mkdir -p "$(dirname "$env_file")" 2>>"$LOGFILE"
    if cp "$MAIN_WORKTREE/$env_file" "$env_file" 2>>"$LOGFILE"; then
      log "✓ copied $env_file from main"
      copied_envs=$((copied_envs + 1))
    else
      log "✗ failed to copy $env_file"
    fi
  fi
done
[ "$copied_envs" -eq 0 ] && log "· no .env files to copy from main"

# Mark setup complete EARLY — the runner watches for this marker to
# fire its success banner and write the rctrl+' state file. By
# logging "complete!" here (BEFORE the slow pnpm install + codegen +
# per-repo hook), the user gets the success banner in ~10–15s instead
# of 60–90s, and can rctrl+' into the new worktree session immediately.
# The slow steps run in a detached background subshell below; when
# that finishes, it sends a tmux display-message + macOS notification
# so the user knows full setup (deps + codegen + hook) is ready.
log "$REPO_NAME worktree setup complete!"
log "=== END ==="

WORKTREE_NAME=$(basename "$CURRENT_WORKTREE")
SESSION_NAME="${CURRENT_WORKTREE#$HOME/Developer/}"

# Detach via double-fork ( ( cmd & ) ) so the bg subshell reparents
# to init and survives this script's exit, treekanga's exit, claude's
# exit, and the runner's exit. Output continues appending to LOGFILE
# so `tail -f ~/.logs/treekanga-postscript.log` (or the per-run log)
# still works for debugging.
( (
  cd "$CURRENT_WORKTREE" || exit
  set +e

  # Re-source env so PNPM_HOME, GPR_AUTH_TOKEN, etc. are present in
  # the bg subshell. The fg postScript already sourced this; re-sourcing
  # is idempotent and keeps the bg path self-contained.
  if [ -f "$HOME/.zsh_gnohj_env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/.zsh_gnohj_env"
  fi

  bg_log() {
    local msg="$*"
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$msg" >>"$LOGFILE"
  }

  install_ok=1
  install_start=$(date +%s)
  if [ -f "pnpm-lock.yaml" ]; then
    bg_log "→ (bg) pnpm install starting…"
    if pnpm install >>"$LOGFILE" 2>&1; then
      bg_log "✓ (bg) pnpm install completed in $(($(date +%s) - install_start))s"
    else
      bg_log "✗ (bg) pnpm install failed"
      install_ok=0
    fi
  elif [ -f "package-lock.json" ]; then
    bg_log "→ (bg) npm install starting…"
    if npm install >>"$LOGFILE" 2>&1; then
      bg_log "✓ (bg) npm install completed in $(($(date +%s) - install_start))s"
    else
      bg_log "✗ (bg) npm install failed"
      install_ok=0
    fi
  elif [ -f "yarn.lock" ]; then
    bg_log "→ (bg) yarn install starting…"
    if yarn install >>"$LOGFILE" 2>&1; then
      bg_log "✓ (bg) yarn install completed in $(($(date +%s) - install_start))s"
    else
      bg_log "✗ (bg) yarn install failed"
      install_ok=0
    fi
  else
    bg_log "· (bg) no lockfile, skipping install"
  fi

  if [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
    codegen_start=$(date +%s)
    bg_log "→ (bg) pnpm codegen starting…"
    if pnpm -r --if-present run codegen >>"$LOGFILE" 2>&1; then
      bg_log "✓ (bg) pnpm codegen completed in $(($(date +%s) - codegen_start))s"
    else
      bg_log "✗ (bg) pnpm codegen failed (non-fatal)"
    fi
  fi

  # Per-repo post-create hook (looks for ~/.config/treekanga/postcreate/<repo>.sh).
  HOOK="$HOME/.config/treekanga/postcreate/$REPO_NAME.sh"
  if [ -x "$HOOK" ]; then
    hook_start=$(date +%s)
    bg_log "→ (bg) per-repo post-create hook: $HOOK"
    if (
      cd "$CURRENT_WORKTREE" \
        && export WORKTREE_PATH="$CURRENT_WORKTREE" REPO_NAME="$REPO_NAME" \
        && "$HOOK"
    ) >>"$LOGFILE" 2>&1; then
      bg_log "✓ (bg) per-repo hook completed in $(($(date +%s) - hook_start))s"
    else
      bg_log "✗ (bg) per-repo hook failed (non-fatal)"
    fi
  elif [ -f "$HOOK" ]; then
    bg_log "· (bg) $HOOK exists but is not executable — chmod +x to enable"
  fi

  # Notify the user that bg setup is done. tmux display-message lands
  # on the worktree session's status bar (visible if user already
  # rctrl+'d in). mac-notify catches the case where they haven't yet.
  if [ "$install_ok" = "1" ]; then
    final_msg="✅ $WORKTREE_NAME setup complete (deps + codegen done)"
    notify_title="✓ Background setup done"
  else
    final_msg="⚠️ $WORKTREE_NAME setup completed with errors — check ~/.logs/treekanga-postscript.log"
    notify_title="⚠️ Background setup had errors"
  fi
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux display-message -d 8000 -t "$SESSION_NAME" "$final_msg" 2>/dev/null
  fi
  if command -v mac-notify >/dev/null 2>&1; then
    mac-notify -t "$notify_title" -m "$WORKTREE_NAME" -T 6 -g "worktree-bg-$WORKTREE_NAME" 2>/dev/null
  fi
  bg_log "=== END (bg) ==="
) </dev/null >/dev/null 2>&1 & ) 2>/dev/null

# Fast-path final notification: tell the user the worktree dir is
# ready (sync part done). The bg subshell will fire ANOTHER tmux
# message + mac-notify when deps + codegen + hook actually finish.
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux display-message -d 5000 -t "$SESSION_NAME" "🌳 $WORKTREE_NAME ready (deps installing in background)" 2>/dev/null
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
