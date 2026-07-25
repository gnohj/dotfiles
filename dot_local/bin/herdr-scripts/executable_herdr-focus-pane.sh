#!/usr/bin/env bash
# Focus a herdr pane by id via the socket's pane.focus — no CLI can (`pane focus` is direction-only; `agent focus` takes only panes hosting a live agent).
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/share/mise/shims:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
herdr="${HERDR_BIN_PATH:-herdr}"
sock="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
py="$(command -v python3 2>/dev/null || echo /usr/bin/python3)"

pane="${1:?herdr-focus-pane: missing <pane_id>}"

focus_via_socket() {
  [ -S "$sock" ] || return 1
  "$py" - "$sock" "$pane" <<'PY'
import json, socket, sys

sock_path, pane_id = sys.argv[1], sys.argv[2]
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect(sock_path)
    req = {"id": "focus-pane", "method": "pane.focus", "params": {"pane_id": pane_id}}
    s.sendall((json.dumps(req) + "\n").encode())
    buf = b""
    while b"\n" not in buf:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    sys.exit(0 if "result" in json.loads(buf.split(b"\n")[0]) else 1)
except Exception:
    sys.exit(1)
PY
}

focus_via_socket && exit 0

# Fallback: at least land on the right workspace/tab.
command -v jq >/dev/null 2>&1 || exit 1
info="$("$herdr" pane get "$pane" 2>/dev/null)" || exit 1
ws="$(printf '%s' "$info" | jq -r '.result.pane.workspace_id // empty' 2>/dev/null)"
tab="$(printf '%s' "$info" | jq -r '.result.pane.tab_id // empty' 2>/dev/null)"
[ -n "$ws" ] || exit 1

"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
[ -n "$tab" ] && "$herdr" tab focus "$tab" >/dev/null 2>&1 || true
exit 0
