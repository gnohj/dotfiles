#!/usr/bin/env bash
# herdr-diff-morning.sh — daily 10am launchd job (see dot_nix/nix-darwin/modules/
# launchd-services.nix :: herdr-diff-morning). Regenerates the herdr <-> tmux-dash
# parity page fresh each morning and opens it in the browser, and fires a notification
# ONLY when herdr has shipped a new upstream release since the last run.
#
# WHY REGENERATE DAILY (not only on release): the page also reflects the INSTALLED
# herdr version, tmux-dash changes, and dirty-repo state, so a fresh scan each morning
# keeps it honest. Headless `claude -p` runs on Claude Max quota ($0, same as
# sb-agent-refresh), so a once-daily run is free. The "new upstream release" signal the
# user cares about is surfaced as a notification + the bumped "latest" version on the page.
#
# WHY A LOCAL HTML FILE (not an Artifact): a headless claude session can't publish a
# claude.ai Artifact, so the skill's `--html-file` mode writes a self-contained page we
# open via file://. Fully offline-capable once written.
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="${HOME:?}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-diff"
HTML="$STATE_DIR/herdr-diff.html"
SEEN="$STATE_DIR/last-release"
LOG_DIR="$HOME/.logs/herdr-diff"
mkdir -p "$STATE_DIR" "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/fires.log"; }

CHANGELOG_URL="https://raw.githubusercontent.com/ogulcancelik/herdr/master/CHANGELOG.md"

# --- detect the latest UPSTREAM release (top `## [x.y.z]` in the changelog) ----------
latest="$(curl -fsSL --max-time 15 "$CHANGELOG_URL" 2>/dev/null \
          | grep -m1 -oE '\[[0-9]+\.[0-9]+\.[0-9]+\]' | tr -d '[]')"
prev="$(cat "$SEEN" 2>/dev/null || true)"
new_release=0
if [ -n "$latest" ] && [ "$latest" != "$prev" ]; then
  new_release=1
fi

log "fire: latest=${latest:-?} prev=${prev:-none} new_release=$new_release"

# --- regenerate the page fresh (headless claude, Max quota) ---------------------------
# Slash-command invocation, same headless pattern as sb-agent-refresh. `--html-file`
# makes the skill Write a local self-contained page instead of publishing an Artifact.
if claude --dangerously-skip-permissions -p "/herdr-diff --html-file $HTML" \
     >> "$LOG_DIR/fires.log" 2>&1 && [ -s "$HTML" ]; then
  log "regenerated $HTML"
else
  log "WARN: regeneration failed or wrote nothing; falling back to existing page"
fi

# --- new-release notification (the signal the user asked to be triggered on) ----------
if [ "$new_release" = 1 ]; then
  mac-notify -t "herdr $latest released" \
             -m "Parity page refreshed — opening /herdr-diff" -T 25 -s Glass \
             2>/dev/null || true
  printf '%s\n' "$latest" > "$SEEN"
fi

# --- open the page every morning (honors "html in my browser at 10am") ---------------
if [ -s "$HTML" ]; then
  open "$HTML" 2>/dev/null || true
  log "opened $HTML"
else
  log "no page to open (first run failed?)"
fi
