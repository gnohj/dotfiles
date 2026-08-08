#!/usr/bin/env bash
# treehouse post_create hook — prep a freshly provisioned/reset pool worktree so
# gh-dash `P` reviews and orchestrator `-e` agents get deps + env ready.
#
# Deliberately LEAN vs treekanga's worktree_setup.sh: this does NOT create a
# thread-state note, wire up sesh/herdr/pbcopy sessions, run codegen, fire
# notifications, or kill windows — treehouse owns the pool-worktree lifecycle,
# so all we want is a usable checkout. Just three things:
#   1. copy .env files from the repo's main worktree (if any are missing here)
#   2. pnpm install via install-deps.sh - backgrounded, and skipped for review-*
#      leases (review-open.sh runs it after the PR checkout instead)
#   3. register the path with zoxide
#
# treehouse runs this via `/bin/sh -c` in the worktree dir, routes our stdout to
# stderr for `--lease` (keeping the leased path clean), and never fails `get` on
# a non-zero hook — but we stay defensive regardless.

set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"
# Align PNPM_HOME (store path) with interactive zsh so the next `pn i` doesn't
# detect a layout mismatch and nuke the node_modules we just installed.
[ -f "$HOME/.zsh_gnohj_env" ] && . "$HOME/.zsh_gnohj_env" 2>/dev/null

WT="$PWD"

# owner/repo from any remote spelling, so ssh and https clones of one repo compare equal.
norm_origin() { printf '%s' "$1" | sed -E 's|\.git$||; s|^[^:]+://[^/]+/||; s|^[^:]+:||'; }

# Matched by origin rather than path, so a clone anywhere resolves to the same env source.
canonical_checkout() { # <origin-url> -> default-branch worktree, or empty
  local want d def_b wt
  want="$(norm_origin "$1")"
  [ -n "$want" ] || return 0
  for d in "$HOME"/Developer/*/; do
    [ "$(norm_origin "$(git -C "$d" remote get-url origin 2>/dev/null || true)")" = "$want" ] || continue
    def_b="$(git -C "$d" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
    wt="$(git -C "$d" worktree list --porcelain 2>/dev/null |
      awk -v b="refs/heads/$def_b" '/^worktree /{p=$2} /^branch /{if($2==b){print p; exit}}')"
    [ -n "$wt" ] && [ -d "$wt" ] && printf '%s' "$wt" && return 0
  done
}

# Repos (folder basename under ~/Developer) to SKIP .env copying for. inferno
# manages its envs per broadcast target (local/premiere/coassociate), so blindly
# copying master's .env into a pool worktree is wrong. pnpm install + zoxide
# still run for these — only the env copy is skipped.
ENV_COPY_SKIP=(inferno)

# User-global hook — fires for EVERY repo's pool. Only act in a pnpm workspace;
# bail cleanly everywhere else so it's a no-op for non-JS repos.
[ -f "$WT/pnpm-lock.yaml" ] || exit 0

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
  # A plain clone is its own main worktree and holds no gitignored envs, so re-resolve against the canonical checkout.
  if [ -z "$main_wt" ] || [ "$main_wt" = "$repo_dir" ]; then
    alt="$(canonical_checkout "$(git -C "$WT" remote get-url origin 2>/dev/null || true)")"
    [ -n "$alt" ] && main_wt="$alt"
  fi
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

# 2 - install-deps.sh (shared with review-open.sh); review leases defer so it sees the PR's manifests.
case "${TREEHOUSE_LEASE_HOLDER:-}" in
  review-*)
    echo "review lease (${TREEHOUSE_LEASE_HOLDER}) — deferring pnpm install to review-open.sh"
    ;;
  *)
    "$HOME/.config/treehouse/install-deps.sh" "$WT" || true
    ;;
esac
exit 0
