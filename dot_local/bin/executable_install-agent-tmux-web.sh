#!/usr/bin/env bash
# One-shot installer for agent-tmux-web on THIS box (the remote dev VPS). chezmoi drops
# it on every machine; you run it ONCE on the Linux box. Idempotent — safe to re-run
# (keeps your existing token, just updates the build/unit). Replaces the manual Phase 7
# steps in MANUAL_VPS_SETUP.md.
#
# ⚠️  SECURITY — this service can run arbitrary commands in your tmux via its token
#     (constant-time-checked, but full RCE for whoever holds it). So:
#       - binds 127.0.0.1 ONLY; Tailscale exposes it privately. NEVER 0.0.0.0 / funnel.
#       - the token is generated here, stored chmod 600, and NEVER printed to stdout/logs
#         (this script prints the command to fetch it, not the value).
#       - PIN an audited commit: pass the SHA as $1 (or $AGENT_TMUX_WEB_REF). Read the
#         server source before trusting a new SHA: src/server/index.ts + tmux.ts.
set -euo pipefail

[ "$(uname)" = "Linux" ] || { echo "This installer targets the Linux VPS (systemd + linger). macOS uses launchd — not applicable."; exit 1; }

REPO="https://github.com/antonlobanovskiy/agent-tmux-web.git"
DIR="$HOME/.local/share/agent-tmux-web"
PORT="${AGENT_TMUX_WEB_PORT:-6174}"
REF="${1:-${AGENT_TMUX_WEB_REF:-}}"
ENV_FILE="$DIR/.env"
UNIT_DIR="$HOME/.config/systemd/user"

command -v pnpm >/dev/null 2>&1 || { echo "pnpm not found — run 'chezmoi apply' first (bootstrap installs node@22 + pnpm)."; exit 1; }

# 1. Clone or update, pinned to an audited ref.
if [ -d "$DIR/.git" ]; then
  echo "==> updating $DIR"
  git -C "$DIR" fetch --tags --quiet origin
else
  echo "==> cloning agent-tmux-web"
  git clone --quiet "$REPO" "$DIR"
fi
if [ -n "$REF" ]; then
  git -C "$DIR" checkout --quiet "$REF"
  echo "==> pinned to $REF"
else
  echo "!! No ref pinned — using the current default branch. STRONGLY re-run pinned to an"
  echo "   audited commit:  $0 <SHA>   (current HEAD: $(git -C "$DIR" rev-parse --short HEAD))"
fi

cd "$DIR"

# 2. Build.
echo "==> pnpm install + build"
pnpm install --frozen-lockfile
pnpm build

# 3. .env — generate a token ONCE; keep the existing one on re-run (never silently rotate).
if [ -f "$ENV_FILE" ] && grep -q '^AGENT_TMUX_WEB_AUTH_TOKEN=..' "$ENV_FILE"; then
  echo "==> keeping existing token in $ENV_FILE"
else
  umask 077
  printf 'HOST=127.0.0.1\nPORT=%s\nCLI_WEB_DEFAULT_CWD=%s\nAGENT_TMUX_WEB_AUTH_TOKEN=%s\n' \
    "$PORT" "$HOME" "$(openssl rand -hex 32)" >"$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "==> wrote $ENV_FILE (chmod 600, HOST=127.0.0.1, fresh token)"
fi

# 4. User systemd service — mise shims on PATH so node/tmux resolve; auto-restart.
mkdir -p "$UNIT_DIR"
PNPM_BIN="$(command -v pnpm)"
cat >"$UNIT_DIR/agent-tmux-web.service" <<UNIT
[Unit]
Description=Agent Tmux Web
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=%h/.local/share/agent-tmux-web
EnvironmentFile=%h/.local/share/agent-tmux-web/.env
Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$PNPM_BIN start
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT

# linger — the service (and your tmux) survive logout. Needs sudo; degrade gracefully.
loginctl enable-linger "$(id -un)" 2>/dev/null \
  || sudo -n loginctl enable-linger "$(id -un)" 2>/dev/null \
  || echo "!! could not set linger — run once:  sudo loginctl enable-linger $(id -un)"

systemctl --user daemon-reload
systemctl --user enable --now agent-tmux-web.service
systemctl --user --no-pager status agent-tmux-web.service 2>/dev/null | head -4 || true

# 5. Expose over the tailnet with HTTPS — tailnet-only (never funnel/public).
if command -v tailscale >/dev/null 2>&1; then
  tailscale serve --bg "http://127.0.0.1:$PORT" 2>/dev/null \
    || echo "!! 'tailscale serve' failed — do 'sudo tailscale up --ssh' + enable MagicDNS/HTTPS in the admin console, then: tailscale serve --bg http://127.0.0.1:$PORT"
fi

# 6. Point the user at it WITHOUT leaking the token into scrollback/logs.
echo
echo "==> agent-tmux-web is up. Open the PWA at:"
echo "      https://<your-tailnet-name>/?token=<TOKEN>"
echo "    Exact host:   tailscale serve status"
echo "    Token (keep private — do NOT paste anywhere shared):"
echo "      grep '^AGENT_TMUX_WEB_AUTH_TOKEN=' $ENV_FILE | cut -d= -f2-"
