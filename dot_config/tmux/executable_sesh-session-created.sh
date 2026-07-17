#!/usr/bin/env bash
# tmux `session-created` hook handler (wired in tmux.conf).
#
# Launches nvim FAST for git-repo sesh sessions and builds the two background
# 3-pane shell windows — robot (AI) and hammer (dev).
#
# GATED TO SESH LAUNCHES ONLY: every sesh entry point stamps @sesh_spawn with
# the current epoch immediately before `sesh connect`. We require that stamp to
# be fresh (a few seconds). A manual `tmux new-session` — or a tool like
# worktree-runner that calls `tmux new-session -d` directly — never sets the
# stamp, so it's skipped. That's the leak fix. On top of that: only git
# repos/worktrees that aren't explicit-startup sessions in sesh.toml qualify.
#
# nvim launch survives because it runs inside an INTERACTIVE zsh (-i => job
# control => nvim holds the terminal; a non-interactive `zsh -c nvim` exits).
# -c skips the prompt loop (no turbo plugins), so nvim is up in ~300ms with the
# correct per-project env (zshrc sources mise); quitting nvim drops into a shell.
#
# Arg 1: session name (#{hook_session_name}).

# /opt/homebrew stays first so macOS resolution is unchanged; the Linux dirs
# (linuxbrew / mise shims / ~/.local/bin) are appended for a headless Linux VPS.
export PATH="/opt/homebrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
source "$HOME/.config/tmux/lib/dev-window.sh"

SESSION="$1"
[ -n "$SESSION" ] || exit 0

# --- sesh-only gate: require a fresh @sesh_spawn stamp (protocol: sesh-spawn.sh)
"$HOME/.config/sesh/sesh-spawn.sh" fresh || exit 0

# --- run once per session + claim the session AGAINST startup.sh --------------
# Claim IMMEDIATELY (before the slow git/awk work below), not just before the
# window build. sesh runs the default startup_command (startup.sh -> dev.sh) for
# this same session, and dev.sh ALSO builds the dev windows. Both gate on
# @nvim_fast_done; if we set it late (after the sesh.toml awk) startup.sh can read
# it unset in the gap and build a duplicate set of dev windows. Setting
# it here shrinks the race to the two adjacent tmux calls. Safe to claim before the
# git/explicit-startup checks: a non-git or explicit-startup session needs no
# dev.sh fallback anyway (dev.sh self-skips non-git; explicit sessions run their
# own command), so blocking startup.sh for them costs nothing.
[ "$(tmux show-options -qv -t "$SESSION" @nvim_fast_done)" = "1" ] && exit 0
tmux set-option -t "$SESSION" @nvim_fast_done 1

DIR=$(tmux display-message -p -t "$SESSION" '#{session_path}' 2>/dev/null)
[ -n "$DIR" ] || exit 0

# --- git repo AND not an explicit-startup session in sesh.toml ----------------
git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Pre-warm the gitmux status cache in parallel with the window build below, so the
# status bar shows branch/status the instant this brand-new session first paints
# instead of blank-until-the-next-tick. Same writer the status #() job uses, so
# the mkdir-lock coalesces if a tick fires mid-warm.
"$HOME/.config/tmux/status-git-refresh.sh" "$DIR" >/dev/null 2>&1 &

SESH_TOML="$HOME/.config/sesh/sesh.toml"
if [ -f "$SESH_TOML" ] && awk -v w="$SESSION" '
    /^\[\[session\]\]/ { nm=""; next }
    /^name[ \t]*=/ { l=$0; sub(/^name[ \t]*=[ \t]*"/,"",l); sub(/".*/,"",l); nm=l; next }
    /^startup_command[ \t]*=/ { if (nm==w) found=1 }
    END { exit !found }
  ' "$SESH_TOML"; then
  exit 0
fi

# @nvim_fast_done already claimed at the top (before the git/awk work) so the
# concurrent startup.sh -> dev.sh defers instead of building a duplicate window.

# --- pen window (window 1): fast, surviving nvim ------------------------------
# base-index 1 (base.conf) → the session's first window is :1, not :0.
tmux respawn-window -k -t "${SESSION}:1" "zsh -i -c 'cd \"$DIR\"; nvim; exec zsh'"
mark_window "${SESSION}:1" pen

# --- robot (AI) + hammer (dev) windows: 3 background panes each (-d keeps focus on nvim)
create_dev_windows "$SESSION" "$DIR"
