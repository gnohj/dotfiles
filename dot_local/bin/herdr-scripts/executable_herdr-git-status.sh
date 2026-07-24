#!/usr/bin/env bash
# herdr-git-status.sh — feed each open herdr workspace's working-tree status to the
# sidebar `$git` token, using the SAME gitmux.yml as the tmux status line + the
# ctrl+t picker. herdr's own git model is branch-only (no dirty/ahead/behind — see
# `herdr api schema`), so its built-in `git_status` token renders nothing; this
# poller supplies the signs via `herdr workspace report-metadata --token git=…`.
# The `$git` row is wired in dot_config/herdr/config.toml ([ui.sidebar.spaces]).
#
#   herdr-git-status.sh          one refresh pass over every open workspace
#   herdr-git-status.sh --loop   daemon: refresh every $INTERVAL s (flock = one only)
#   herdr-git-status.sh --kick   refresh once now, then ensure the --loop daemon is up
#
# Everything runs through the herdr CLI (socket API), so it works local AND over
# `herdr --remote` — the poller lives on whichever host runs the herdr server, the
# same host the repos live on. gitmux SYMBOLS only (the branch is dropped: herdr
# already shows it on its own sidebar line); tmux "#[…]" color codes are stripped
# since a metadata token renders as plain theme-colored text.
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
export PATH="$HOME/.local/bin:$HOME/.local/bin/herdr-scripts:$HOME/.nix-profile/bin:$HOME/.local/share/mise/shims:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
export HERDR_BIN_PATH="$herdr"

GITMUX_CFG="$HOME/.config/gitmux/gitmux.yml"
INTERVAL="${HERDR_GIT_INTERVAL:-8}"
export TTL_MS=$(( (INTERVAL + 30) * 1000 ))   # outlive a couple of missed passes
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
LOCK="$STATE_DIR/git-status.lock"

refresh_once() {
  command -v jq >/dev/null 2>&1 || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  command -v gitmux >/dev/null 2>&1 || return 0
  GITMUX_CFG="$GITMUX_CFG" python3 - <<'PY'
import os, json, re, subprocess, sys, time

HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
CFG = os.environ.get("GITMUX_CFG", os.path.expanduser("~/.config/gitmux/gitmux.yml"))
TTL = os.environ.get("TTL_MS", "60000")
CODE = re.compile(r"#\[[^]]*\]")          # tmux color codes gitmux emits
seq = str(time.time_ns())                  # ns: monotonic, and above any manual probe seq

def out(args, cwd=None):
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=4).stdout
    except Exception:
        return ""

try:
    panes = json.loads(out([HERDR, "pane", "list"]))
except Exception:
    sys.exit(0)

ws_cwd = {}
for p in panes.get("result", {}).get("panes", []):
    w = p.get("workspace_id")
    c = (p.get("foreground_cwd") or p.get("cwd") or "").rstrip("/")
    if w and c and w not in ws_cwd:
        ws_cwd[w] = c

for w, c in ws_cwd.items():
    if not os.path.isdir(c):
        continue
    plain = CODE.sub("", out(["gitmux", "-cfg", CFG], cwd=c))
    parts = plain.split(None, 1)                        # [branch, symbols…] — drop the branch
    sym = " ".join(parts[1].split()) if len(parts) > 1 else ""
    base = [HERDR, "workspace", "report-metadata", w, "--source", "gitmux", "--seq", seq]
    if sym:
        subprocess.run(base + ["--ttl-ms", TTL, "--token", "git=" + sym], capture_output=True)
    else:
        subprocess.run(base + ["--clear-token", "git"], capture_output=True)
PY
}

ensure_daemon() {
  mkdir -p "$STATE_DIR"
  if command -v flock >/dev/null 2>&1; then
    # If the lock is already held, a daemon is running — nothing to do.
    if ! ( exec 9>"$LOCK"; flock -n 9 ) 2>/dev/null; then
      return 0
    fi
  fi
  if command -v setsid >/dev/null 2>&1; then
    setsid "$0" --loop >/dev/null 2>&1 &
  else
    nohup "$0" --loop >/dev/null 2>&1 &
  fi
}

run_loop() {
  mkdir -p "$STATE_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK"
    # BLOCK until we own the lock (don't exit). Under the systemd service with
    # Restart=always this makes a second instance a hot standby rather than an
    # exit-0/restart spin: if a layout-kick daemon (macOS, or a boot-race) holds
    # the lock, we wait and seamlessly take over the moment it dies.
    flock 9
  fi
  # Exit when the herdr socket is gone (server down): the systemd .path unit
  # (herdr-git-status.path) restarts us when it reappears, so we don't poll a dead
  # socket. A restarted server is otherwise picked up automatically (each pass
  # re-queries via the CLI). Socket path matches the daemon default; HERDR_SOCKET_PATH
  # overrides it when set.
  local sock="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
  while :; do
    [ -S "$sock" ] || exit 0
    refresh_once
    sleep "$INTERVAL"
  done
}

case "${1:-}" in
  --loop) run_loop ;;
  --kick) refresh_once; ensure_daemon ;;
  *)      refresh_once ;;
esac
