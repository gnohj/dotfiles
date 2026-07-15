#!/usr/bin/env bash
# treehouse post_create hook — prep a freshly provisioned/reset pool worktree so
# gh-dash `P` reviews and orchestrator `-e` agents get deps + env ready.
#
# Deliberately LEAN vs treekanga's worktree_setup.sh: this does NOT create a
# thread-state note, wire up sesh/herdr/pbcopy sessions, run codegen, fire
# notifications, or kill windows — treehouse owns the pool-worktree lifecycle,
# so all we want is a usable checkout. Just three things:
#   1. copy .env files from the repo's main worktree (if any are missing here)
#   2. pnpm install — BACKGROUNDED, so `get`/`--lease` returns immediately
#      (reviews don't need deps; agents that do can wait for it)
#   3. register the path with zoxide
#
# treehouse runs this via `/bin/sh -c` in the worktree dir, routes our stdout to
# stderr for `--lease` (keeping the leased path clean), and never fails `get` on
# a non-zero hook — but we stay defensive regardless.

set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"
# Align PNPM_HOME (store path) with interactive zsh so the next `pn i` doesn't
# detect a layout mismatch and nuke the node_modules we just installed.
[ -f "$HOME/.zsh_gnohj_env" ] && . "$HOME/.zsh_gnohj_env" 2>/dev/null

WT="$PWD"

# Repos (folder basename under ~/Developer) to SKIP .env copying for. inferno
# manages its envs per broadcast target (local/premiere/coassociate), so blindly
# copying master's .env into a pool worktree is wrong. pnpm install + zoxide
# still run for these — only the env copy is skipped.
ENV_COPY_SKIP=(inferno)

# User-global hook — fires for EVERY repo's pool. Only act in a pnpm workspace;
# bail cleanly everywhere else so it's a no-op for non-JS repos.
[ -f "$WT/pnpm-lock.yaml" ] || exit 0

# Which multiplexer invoked us (matches review-worktree.sh's mux_kind)? treehouse
# is called under tmux OR herdr, so the completion notify must route per-mux —
# tmux commands would silently no-op under herdr. Captured now so the detached
# background subshell keeps it.
if [ -n "${HERDR_SOCKET_PATH:-}" ]; then MUX=herdr
elif [ -n "${TMUX:-}" ]; then MUX=tmux
else MUX=none; fi

# 3 (cheap, do first) — zoxide, matching the interactive custom DB location or
# the `z` command never sees the entry.
if command -v zoxide >/dev/null 2>&1; then
  _ZO_DATA_DIR="$HOME/.config/zshrc" zoxide add "$WT" 2>/dev/null || true
fi

# 1 — copy .env from the repo's MAIN worktree. treehouse paths
# (~/.treehouse/<pool>/N/…) don't encode the repo like ~/Developer/<repo> does,
# so derive the repo + its default-branch worktree from the shared bare repo.
common="$(git -C "$WT" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$common" ]; then
  common="$(cd "$(dirname "$common")" 2>/dev/null && pwd)/$(basename "$common")"
  repo_dir="$(dirname "$common")"
  def="$(git -C "$WT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
  main_wt="$(git -C "$WT" worktree list --porcelain 2>/dev/null \
    | awk -v b="refs/heads/$def" '/^worktree /{p=$2} /^branch /{if($2==b){print p; exit}}')"
  [ -z "$main_wt" ] && main_wt="$repo_dir/$def"
  repo_name="$(basename "$repo_dir")"
  skip_env=0
  for r in "${ENV_COPY_SKIP[@]}"; do [ "$repo_name" = "$r" ] && skip_env=1; done
  if [ "$skip_env" -eq 0 ] && [ -n "$def" ] && [ -d "$main_wt" ] && [ "$main_wt" != "$WT" ]; then
    env_files=(.env .env.local .env.development .env.development.local)
    if [ -d "$main_wt/apps" ]; then
      while IFS= read -r abs; do env_files+=("${abs#"$main_wt"/}"); done \
        < <(find "$main_wt/apps" -maxdepth 2 -type f \( -name '.env' -o -name '.env.*' \) ! -name '.env.example' 2>/dev/null)
    fi
    for e in "${env_files[@]}"; do
      if [ -f "$main_wt/$e" ] && [ ! -f "$WT/$e" ]; then
        mkdir -p "$(dirname "$WT/$e")" 2>/dev/null && cp "$main_wt/$e" "$WT/$e" 2>/dev/null && echo "copied $e from main"
      fi
    done
  fi
fi

# 2 — pnpm install, DETACHED so the lease returns fast. Reuse keeps node_modules
# across leases, so --frozen-lockfile is near-instant when the lockfile is
# unchanged; a fresh/reset slot pays a full install in the background. When it
# finishes, notify like treekanga: a tmux status message on the session that
# holds a pane in this worktree (the review/agent windows P/-e opened) + a macOS
# notification, so you know deps are ready without watching.
if command -v pnpm >/dev/null 2>&1; then
  label="${WT#"$HOME"/.treehouse/}" # e.g. review-130256/2/review
  ( (
    cd "$WT" || exit
    start=$(date +%s)
    if pnpm install --frozen-lockfile >/dev/null 2>&1; then
      msg="✅ treehouse: $label deps ready ($(($(date +%s) - start))s)"
    else
      msg="⚠️ treehouse: $label pnpm install failed"
    fi
    case "$MUX" in
      tmux)
        # status message on the session that has a pane in this worktree (the
        # review/agent windows), plus a desktop notif — mirrors treekanga.
        sess="$(tmux list-panes -a -F '#{pane_current_path}|#{session_name}' 2>/dev/null \
          | awk -F'|' -v w="$WT" '$1==w||index($1,w"/")==1{print $2; exit}')"
        [ -n "$sess" ] && command -v tmux >/dev/null 2>&1 && tmux display-message -d 6000 -t "$sess" "$msg" 2>/dev/null
        command -v mac-notify >/dev/null 2>&1 && mac-notify -t "treehouse deps" -m "$msg" -T 5 2>/dev/null
        ;;
      herdr)
        # herdr's own toast (its desktop-class notify) over the socket API.
        command -v herdr >/dev/null 2>&1 && herdr notification show "treehouse deps" --body "$msg" --sound done 2>/dev/null || true
        ;;
      *)
        # no multiplexer context — desktop notif only.
        command -v mac-notify >/dev/null 2>&1 && mac-notify -t "treehouse deps" -m "$msg" -T 5 2>/dev/null
        ;;
    esac
  ) </dev/null >/dev/null 2>&1 & ) 2>/dev/null
  echo "pnpm install started (background)"
fi
exit 0
