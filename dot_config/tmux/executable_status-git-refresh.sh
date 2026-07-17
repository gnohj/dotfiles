#!/usr/bin/env bash
# Stale-while-revalidate WRITER for the gitmux status cache the tmux status bar
# reads (generate-status-line.sh serves $CACHE instantly, then calls this to
# refresh in the background). Extracted so it has TWO callers:
#   1. generate-status-line.sh  - every status tick, keeps the cache fresh.
#   2. sesh-session-created.sh  - once on session creation, to PRE-WARM the cache
#      so the very first status paint of a brand-new session shows the branch /
#      status immediately, instead of blank-until-the-next-tick (the "git lazy
#      loads slow on new sessions" symptom - gitmux itself is fast, the lag was
#      just the cold cache waiting for a tick to kick the refresh).
#
# mkdir-lock coalesces concurrent refreshers per directory (so the tick refresh
# and the pre-warm don't both run gitmux); a >30s stale lock is force-cleared.
# Arg 1: directory. Always exits 0-ish (best-effort; never blocks a caller).

# Hook-context PATH (gitmux/perl); linuxbrew added only on Linux - on macOS /home is autofs, so a /home/linuxbrew PATH entry makes every cut/git lookup a ~10ms autofs stat that pegs opendirectoryd.
export PATH="/opt/homebrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

DIR="${1:-}"
[ -d "$DIR" ] || exit 0
git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-git"
mkdir -p "$CACHE_DIR"
KEY="$(cksum <<<"$DIR" | cut -d' ' -f1)"
CACHE="$CACHE_DIR/$KEY"
LOCK="$CACHE_DIR/$KEY.lock"

# Clear a crashed refresher's lock (>30s old) so the cache can't wedge stale forever.
_age() { local m; m="$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0)"; echo "$(($(date +%s) - m))"; }
[ -d "$LOCK" ] && [ "$(_age "$LOCK")" -ge 30 ] && rmdir "$LOCK" 2>/dev/null

# mkdir lock coalesces refreshers so only one gitmux runs per dir at a time.
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
NEW="$(cd "$DIR" && gitmux -cfg "$HOME/.config/gitmux/gitmux.yml" | sed 's/^ //' | "$HOME/.config/tmux/truncate-branch.sh" | perl -pe 's/(#\[[^\]]*\][\s]*)+$//; s/\s+$//')"
[ -n "$NEW" ] && NEW="$NEW  "
printf '%s' "$NEW" >"$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
