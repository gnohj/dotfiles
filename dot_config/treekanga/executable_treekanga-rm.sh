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
#
# Env:
#   TKRM_FORCE=1         delete even when the worktree still holds unrecoverable work
#   TKRM_SKIP_FINISH=1   skip the /sb-ticket-finish pre-delete hook

set -uo pipefail

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

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

# Close any session rooted in the worktree; sweep both, a stale one is broken either way.
kill_sessions_for() {
  local wt="$1"
  kill_tmux_sessions_for "$wt"
  kill_herdr_workspaces_for "$wt"
}

kill_tmux_sessions_for() {
  local wt="$1"
  command -v tmux &>/dev/null || return 0
  tmux list-sessions -F '#{session_name}	#{session_path}' 2>/dev/null \
    | awk -F'\t' -v p="$wt" 'index($2, p) == 1 { print $1 }' \
    | while read -r sess; do
        [ -n "$sess" ] && tmux kill-session -t "$sess" 2>/dev/null || true
      done
}

# herdr has no session_path, so read occupancy from panes; "$wt/" keeps it prefix-safe.
kill_herdr_workspaces_for() {
  local wt="$1" herdr_bin="${HERDR_BIN_PATH:-herdr}"
  command -v "$herdr_bin" &>/dev/null || return 0
  command -v jq &>/dev/null || return 0
  "$herdr_bin" pane list 2>/dev/null \
    | jq -r --arg wt "$wt" '
        [ .result.panes[]?
          | select(((.foreground_cwd // .cwd // "") == $wt)
                or (((.foreground_cwd // .cwd // "") | startswith($wt + "/"))))
          | .workspace_id ] | unique | .[]' 2>/dev/null \
    | while read -r ws; do
        [ -n "$ws" ] && "$herdr_bin" workspace close "$ws" >/dev/null 2>&1 || true
      done
}

# Portable command timeout. Prefers GNU coreutils timeout/gtimeout; falls back
# to the perl SIGALRM idiom (perl ships with macOS, coreutils does not). The
# alarm timer survives exec, so claude is killed after $1 seconds if it stalls.
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout &>/dev/null; then
    timeout "$secs" "$@"
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$secs" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
  fi
}

# Report work in $1 that would not survive the delete, as a human-readable
# summary ("2 uncommitted, 1 unpushed"), or nothing when the worktree is safe.
#
# Why this is needed: the delete below is effectively permanent — it trashes the
# dir and detaches an rm -rf, so there is no undo once the background job runs.
# A merged PR does NOT imply an empty worktree: untracked scratch files, a
# branch-local stash, and a follow-up commit you never pushed all outlive the
# merge. The fzf picker deliberately does not annotate these (a status call per
# worktree on a monorepo makes the picker feel broken), so the check happens per
# selection at delete time instead.
worktree_risks() {
  local wt="$1" branch="$2" risks="" n
  [ -d "$wt" ] || return 0
  git -C "$wt" rev-parse --git-dir &>/dev/null || return 0

  n=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "${n:-0}" -gt 0 ] && risks="$n uncommitted"

  # Stashes live in the repo-shared refs/stash and are therefore visible from
  # every worktree, so filter by branch or a stash made elsewhere flags this one.
  # Both message forms name it: "WIP on <branch>:" and "On <branch>:".
  n=$(git -C "$wt" stash list 2>/dev/null | grep -icF " on ${branch}:" || true)
  [ "${n:-0}" -gt 0 ] && risks="${risks}${risks:+, }$n stash"

  # --not --remotes covers both a never-pushed branch and one ahead of its
  # upstream. Skipped without a remote, where it would count every commit.
  if [ -n "$(git -C "$wt" remote 2>/dev/null | head -1)" ]; then
    n=$(git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] && risks="${risks}${risks:+, }$n unpushed"
  fi

  printf '%s' "$risks"
}

delete_one() {
  local repo="$1" branch="$2" wt_path="$3" bare="$4"

  echo "→ $repo:$branch"

  # Guard runs BEFORE the /sb-ticket-finish hook: refusing the delete must not
  # leave a frozen note and a cleaned thread file behind for a worktree that is
  # still here. One refusal does not abort the run — other selections proceed.
  local risks
  risks=$(worktree_risks "$wt_path" "$branch")
  if [ -n "$risks" ]; then
    if [ "${TKRM_FORCE:-0}" != 1 ]; then
      echo "  ✗ refusing: $risks — none of it is recoverable after the rm -rf"
      echo "    inspect:  git -C $wt_path status --short"
      echo "    override: TKRM_FORCE=1 tkrm $branch"
      return 1
    fi
    echo "  ⚠ TKRM_FORCE set — deleting despite $risks"
  fi

  # Pre-delete /sb-ticket-finish hook. Freezes the vault note + cleans up the
  # ~/.local/state/threads/<TICKET>.json orphan BEFORE the worktree is removed.
  # Non-blocking: if the recap fails (claude unavailable, vault unmounted, etc.)
  # we log and continue — the worktree delete is the user's primary intent.
  #
  # TKRM_SKIP_FINISH=1 disables this hook entirely. The tmux-orchestrator
  # teardown sets it: an orch child branch (e.g. IHRWEB-123-foo-ui-settings)
  # embeds its PARENT's ticket id, so running the finish hook would wrongly
  # freeze the parent ticket's note + delete its thread state on child close.
  local thread_id thread_file vault acct note already_frozen=0 finish_ok=0
  thread_id=$(printf '%s' "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  thread_file="$HOME/.local/state/threads/${thread_id}.json"
  # Resolve from the WORKTREE, not $PWD: $wt_path still exists here, $PWD is just where tkrm ran.
  vault="$("$HOME/.local/bin/vault-path" "$wt_path")"
  acct="$("$HOME/.local/bin/claude-account" cwd "$wt_path" 2>/dev/null || true)"

  if [ "${TKRM_SKIP_FINISH:-0}" != 1 ] && [ -n "$thread_id" ] && [ -f "$thread_file" ]; then
    # Cheap shell-level idempotency check: if the vault note already says
    # `state: frozen`, the user (or a previous tkrm) already shipped this
    # ticket. Skip the ~10s claude spawn entirely — just clean the orphan.
    # --ticket so the key never depends on the mid-delete worktree's branch.
    note=$("$HOME/.local/bin/vault-note" --ticket "$thread_id" "$wt_path" 2>/dev/null) || note=""
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
      # Absolute path: PATH hits mise's raw npm binary first, which has no auth and dies.
      if [ -x "$HOME/.local/bin/claude" ]; then
        # --add-dir is required: claude's default sandbox is the cwd ($HOME or
        # wherever tkrm was invoked from), which excludes the vault and the
        # threads state dir. Without these flags the skill halts at pre-check.
        # Headless hook: no TTY to answer permission prompts, and the skill is
        # almost entirely Bash (gh/git/find/jq/ccusage/rm). Without bypass mode
        # every Bash call returns "requires approval" and the session spins for
        # minutes before giving up. bypassPermissions runs it unattended; the
        # timeout is a backstop so a stall can never block the delete for long.
        if run_with_timeout 150 \
            env SB_TICKET_FINISH_FROM_TKRM=1 CLAUDE_ACCOUNT="$acct" \
            "$HOME/.local/bin/claude" -p "/sb-ticket-finish $thread_id" \
              --permission-mode bypassPermissions \
              --add-dir "$vault" \
              --add-dir "$HOME/.local/state" \
            2>&1 | sed 's/^/    /'; then
          finish_ok=1
        else
          echo "    (sb-ticket-finish failed or timed out for $thread_id — keeping thread state for retry)"
        fi
      else
        # Defer: drop a marker the next vault-aware session picks up.
        mkdir -p "$HOME/.local/state/sb-ticket-finish-pending"
        cp "$thread_file" \
           "$HOME/.local/state/sb-ticket-finish-pending/${thread_id}.json" 2>/dev/null \
          && echo "    (~/.local/bin/claude missing — deferred to ~/.local/state/sb-ticket-finish-pending/)"
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

  kill_sessions_for "$wt_path"

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
      # GNU first: on Linux `stat -f %m` reads its arg as a filesystem and poisons the value.
      mtime=$(stat -c %Y "$wt_path" 2>/dev/null || stat -f %m "$wt_path" 2>/dev/null || echo 0)
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

# tkrm deletes your PERSONAL worktrees, but gh-dash `P` reviews lease SEPARATE
# treehouse pool worktrees (under ~/.treehouse/, tracked in gh-review-worktrees/)
# that tkrm never touches — so a review whose windows you've closed keeps holding
# a pool slot silently. Piggyback on the cleanup you already do: after removing
# worktrees, reclaim idle review slots (no open windows) and surface any that are
# still active. Idle-only + grace-guarded, so an in-progress review is safe.
reclaim_review_slots() {
  local rw="$HOME/.config/gh-dash/review-worktree.sh"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/gh-review-worktrees"
  [ -x "$rw" ] || return 0
  local before after freed
  before=$(find "$state_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "${before:-0}" -eq 0 ] && return 0
  "$rw" reclaim >/dev/null 2>&1 || true
  after=$(find "$state_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  freed=$((before - after))
  if [ "$freed" -gt 0 ]; then
    echo "🌲 reclaimed $freed idle review worktree slot(s); ${after} still leased (active)"
  elif [ "${after:-0}" -gt 0 ]; then
    echo "🌲 ${after} review worktree slot(s) still leased & active — close their windows then rerun, or press R in gh-dash"
  fi
}

if [ $# -eq 0 ]; then
  run_picker
else
  run_direct "$(list_worktrees)" "$@"
fi

reclaim_review_slots
