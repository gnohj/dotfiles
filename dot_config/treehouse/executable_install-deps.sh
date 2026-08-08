#!/usr/bin/env bash
# install-deps.sh — backgrounded `pnpm install` + completion notify for one pool
# worktree. Extracted from post-create.sh so BOTH callers share one copy:
#
#   post-create.sh   non-review leases (agents), right after the master reset
#   review-open.sh   gh-dash `P` reviews, AFTER `checkout --detach origin/$HEAD`
#
# The split exists because treehouse resets a slot to the default branch and runs
# post_create BEFORE review-open.sh checks out the PR head. Installing at hook
# time would resolve master's manifests and then have package.json/pnpm-lock.yaml
# swapped underneath it — wrong node_modules for the PR, plus a spurious
# --frozen-lockfile mismatch. Review leases therefore defer to this script.
#
#   install-deps.sh <worktree-path>
#
# Always exits 0: dep prep is best-effort and must never fail a lease or review.

set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"
# Align PNPM_HOME (store path) with interactive zsh so the next `pn i` doesn't
# detect a layout mismatch and nuke the node_modules we just installed.
[ -f "$HOME/.zsh_gnohj_env" ] && . "$HOME/.zsh_gnohj_env" 2>/dev/null

WT="${1:-}"
[ -n "$WT" ] && [ -d "$WT" ] || exit 0
[ -f "$WT/pnpm-lock.yaml" ] || exit 0
command -v pnpm >/dev/null 2>&1 || exit 0

# Which multiplexer are we under? The notify must route per-mux — tmux commands
# silently no-op under herdr. Env vars work from the treehouse hook; `mux kind`
# covers review-open.sh, which gh-dash runs nohup-detached with no $TMUX.
if [ -n "${HERDR_SOCKET_PATH:-}" ]; then MUX=herdr
elif [ -n "${TMUX:-}" ]; then MUX=tmux
else MUX="$("$HOME/.local/bin/mux/mux" kind 2>/dev/null || echo none)"; fi

label="${WT#"$HOME"/.treehouse/}" # e.g. review-130256/2/review

# DETACHED so the caller returns immediately. Reuse keeps node_modules across
# leases, so --frozen-lockfile is near-instant when the lockfile is unchanged; a
# fresh/reset slot pays a full install here in the background.
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
echo "pnpm install started (background): $label"
exit 0
