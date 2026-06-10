#!/usr/bin/env bash
# Fast worktree + branch deletion across all repos defined in treekanga.yml.
#
# Why this exists: `git worktree remove` (and `treekanga delete`) blocks on
# rm -rf of node_modules, which is hundreds of thousands of inodes under pnpm.
# This script trashes the dir first, prunes/branches synchronously (instant),
# and runs the actual rm -rf in the background.
#
# Usage:
#   tkrm              fzf picker (multi-select with Tab)
#   tkrm <branch>...  delete given branches across all configured repos

set -uo pipefail

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

CONFIG_FILE="$HOME/.config/treekanga/treekanga.yml"
# Use a temp dir on the same filesystem as $HOME so `mv` is an inode rename
# (instant). Avoids polluting ~/.Trash, which is user-visible in Finder.
TRASH_BASE="${TMPDIR:-/tmp}"

if [ -f "$HOME/.config/colorscheme/active/active-colorscheme.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/colorscheme/active/active-colorscheme.sh"
fi
FZF_COLORS="--color=bg+:${gnohj_color13:-},border:${gnohj_color03:-},fg:${gnohj_color02:-},fg+:${gnohj_color02:-},hl+:${gnohj_color04:-},info:${gnohj_color09:-},prompt:${gnohj_color04:-},pointer:${gnohj_color04:-},marker:${gnohj_color04:-},header:${gnohj_color09:-}"

# Emit "repo|worktreeTargetDir|defaultBranch" for each repo block in treekanga.yml.
parse_repos() {
  awk '
    /^  [a-zA-Z0-9_-]+:$/ {
      if (repo != "" && target != "" && branch != "") print repo "|" target "|" branch
      repo = $1; sub(":", "", repo); target = ""; branch = ""; next
    }
    repo != "" && /^[[:space:]]+worktreeTargetDir:/ { target = $2 }
    repo != "" && /^[[:space:]]+defaultBranch:/    { branch = $2 }
    END {
      if (repo != "" && target != "" && branch != "") print repo "|" target "|" branch
    }
  ' "$CONFIG_FILE"
}

# Emit "repo|branch|fullPath|bareDir" for each non-main, non-bare worktree.
list_worktrees() {
  while IFS='|' read -r repo target main_branch; do
    [ -z "$repo" ] && continue
    local bare="$HOME/$target/.bare"
    [ -d "$bare" ] || continue
    git -C "$bare" worktree list --porcelain 2>/dev/null | awk \
      -v repo="$repo" -v main="$main_branch" -v bare="$bare" '
        /^worktree / { path = substr($0, 10); next }
        /^branch refs\/heads\// {
          br = substr($0, 19)
          if (path != "" && br != main) print repo "|" br "|" path "|" bare
          path = ""
        }
        /^bare/ { path = "" }
        /^detached/ { path = "" }
      '
  done < <(parse_repos)
}

# Kill any tmux sessions whose path lives inside the worktree being removed.
kill_tmux_sessions_for() {
  local wt="$1"
  command -v tmux &>/dev/null || return 0
  tmux list-sessions -F '#{session_name}	#{session_path}' 2>/dev/null \
    | awk -F'\t' -v p="$wt" 'index($2, p) == 1 { print $1 }' \
    | while read -r sess; do
        [ -n "$sess" ] && tmux kill-session -t "$sess" 2>/dev/null || true
      done
}

delete_one() {
  local repo="$1" branch="$2" wt_path="$3" bare="$4"

  echo "→ $repo:$branch"

  # Pre-delete /sb-ticket-finish hook. Freezes the vault note + cleans up the
  # ~/.local/state/threads/<TICKET>.json orphan BEFORE the worktree is removed.
  # Non-blocking: if the recap fails (claude unavailable, vault unmounted, etc.)
  # we log and continue — the worktree delete is the user's primary intent.
  local thread_id thread_file vault note already_frozen=0 finish_ok=0
  thread_id=$(printf '%s' "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  thread_file="$HOME/.local/state/threads/${thread_id}.json"
  vault="$HOME/Obsidian/second-brain"

  if [ -n "$thread_id" ] && [ -f "$thread_file" ]; then
    # Cheap shell-level idempotency check: if the vault note already says
    # `state: frozen`, the user (or a previous tkrm) already shipped this
    # ticket. Skip the ~10s claude spawn entirely — just clean the orphan.
    note=$(ls "$vault/Notes/work/${thread_id}-"*.md 2>/dev/null | head -1)
    if [ -z "$note" ]; then
      note=$(ls "$vault/Notes-Inbox/${thread_id}-"*.md 2>/dev/null | head -1)
    fi
    if [ -n "$note" ] && grep -q '^state: frozen' "$note" 2>/dev/null; then
      already_frozen=1
      echo "  ✓ /sb-ticket-finish $thread_id — note already frozen, skipping claude"
    elif [ ! -d "$vault" ]; then
      # Vault not mounted on this machine — nothing to freeze. Treat as no-op
      # for state cleanup purposes; the thread JSON is just stale local state.
      already_frozen=1
      echo "  ✓ /sb-ticket-finish $thread_id — vault not mounted, cleaning state only"
    else
      echo "  /sb-ticket-finish $thread_id"
      if command -v claude &>/dev/null; then
        # --add-dir is required: claude's default sandbox is the cwd ($HOME or
        # wherever tkrm was invoked from), which excludes the vault and the
        # threads state dir. Without these flags the skill halts at pre-check.
        if SB_TICKET_FINISH_FROM_TKRM=1 claude -p "/sb-ticket-finish $thread_id" \
            --add-dir "$vault" \
            --add-dir "$HOME/.local/state" \
            2>&1 | sed 's/^/    /'; then
          finish_ok=1
        else
          echo "    (sb-ticket-finish failed for $thread_id — keeping thread state for retry)"
        fi
      else
        # Defer: drop a marker the next vault-aware session picks up.
        mkdir -p "$HOME/.local/state/sb-ticket-finish-pending"
        cp "$thread_file" \
           "$HOME/.local/state/sb-ticket-finish-pending/${thread_id}.json" 2>/dev/null \
          && echo "    (claude not on PATH — deferred to ~/.local/state/sb-ticket-finish-pending/)"
      fi
    fi

    # Only clean the thread JSON when the freeze actually succeeded or was a
    # confirmed no-op. On failure we keep it so the user can retry via a
    # manual /sb-ticket-finish — otherwise we'd leave the note `state: living`
    # with no remaining state-side breadcrumb to fix it.
    if [ "$already_frozen" -eq 1 ] || [ "$finish_ok" -eq 1 ]; then
      rm -f "$thread_file"
    fi
  fi

  if [ ! -d "$wt_path" ]; then
    echo "  (path missing, just pruning) $wt_path"
    git -C "$bare" worktree prune 2>/dev/null || true
    git -C "$bare" branch -D "$branch" 2>/dev/null || true
    return 0
  fi

  kill_tmux_sessions_for "$wt_path"

  local trash="$TRASH_BASE/treekanga-$(date +%s)-$$-$(basename "$wt_path")"
  if ! mv "$wt_path" "$trash"; then
    echo "  ✗ failed to trash $wt_path (in use?)"
    return 1
  fi

  git -C "$bare" worktree prune
  git -C "$bare" branch -D "$branch" 2>/dev/null || echo "  (branch $branch not found locally)"
  command -v zoxide &>/dev/null && zoxide remove "$wt_path" 2>/dev/null || true

  # Detach the rm so this script (and the launcher popup) can exit immediately.
  ( setsid rm -rf "$trash" </dev/null >/dev/null 2>&1 & ) 2>/dev/null \
    || ( rm -rf "$trash" </dev/null >/dev/null 2>&1 & disown ) 2>/dev/null \
    || ( rm -rf "$trash" </dev/null >/dev/null 2>&1 & )

  echo "  ✓ trashed (rm -rf running in background)"
}

run_picker() {
  local records selections
  # Sort worktrees by directory mtime descending so the most recently
  # touched ones float to the top (matching how the user thinks: "the
  # one I just made" / "the one I last cd'd into" first). Missing paths
  # get mtime=0 and sink to the bottom — they're prune candidates anyway.
  records=$(list_worktrees | while IFS='|' read -r repo branch wt_path bare; do
    [ -z "$repo" ] && continue
    if [ -d "$wt_path" ]; then
      mtime=$(stat -f %m "$wt_path" 2>/dev/null || echo 0)
    else
      mtime=0
    fi
    printf '%s\t%s|%s|%s|%s\n' "$mtime" "$repo" "$branch" "$wt_path" "$bare"
  done | sort -rn -k1,1 | cut -f2-)
  if [ -z "$records" ]; then
    echo "No deletable worktrees found."
    sleep 1
    return 0
  fi

  # fzf shows "🌳 repo:branch  path" but keeps the raw record in a hidden column.
  selections=$(echo "$records" \
    | awk -F'|' '{ printf "🌳 %s | %s | %s\t%s\n", $1, $2, $3, $0 }' \
    | fzf --multi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --wrap \
        --height=80% --reverse \
        --header="Tab: multi-select. Enter: delete." \
        --prompt="🗑  Delete > " \
        $FZF_COLORS) || return 0

  [ -z "$selections" ] && return 0

  while IFS=$'\t' read -r _display record; do
    IFS='|' read -r repo branch wt_path bare <<<"$record"
    delete_one "$repo" "$branch" "$wt_path" "$bare"
  done <<<"$selections"
}

run_direct() {
  local records="$1"; shift
  for target in "$@"; do
    local match
    match=$(echo "$records" | awk -F'|' -v b="$target" '$2 == b { print; exit }')
    if [ -z "$match" ]; then
      echo "✗ no worktree found for branch: $target"
      continue
    fi
    IFS='|' read -r repo branch wt_path bare <<<"$match"
    delete_one "$repo" "$branch" "$wt_path" "$bare"
  done
}

if [ $# -eq 0 ]; then
  run_picker
else
  run_direct "$(list_worktrees)" "$@"
fi
