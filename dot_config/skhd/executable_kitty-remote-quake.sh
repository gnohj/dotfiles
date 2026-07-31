#!/bin/bash
# remote quake (skhd cmd+rctrl+t): the launcher on the dev box. Local counterpart: kitty-ql-quake.sh.
export PATH="$HOME/.local/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# The CLI shim is not always on PATH at login, and a missing binary would otherwise read as an offline box.
TS="$(command -v tailscale || echo '/Applications/Tailscale.app/Contents/MacOS/Tailscale')"

notify() { mac-notify -t "remote quake" -m "$1" -T 5 2>/dev/null; }

# dev-context is only an override now, for aiming this key somewhere other than the dev box (`vps <host>`).
target="$(dev-context target 2>/dev/null)"

# Resolved live, never stored: a stored target is the one thing that can drift (same stance as machine-identity).
if [ -z "$target" ]; then
  target="$(cat "$HOME/.config/devbox-host" 2>/dev/null)"
  if [ -z "$target" ]; then
    notify "no dev box configured (~/.config/devbox-host is missing)"
    exit 0
  fi
fi

# Resolve the FQDN at runtime: a MagicDNS short name has no known_hosts entry, and the address must stay out of the tracked ssh config.
peer="$("$TS" status --json 2>/dev/null |
  jq -r --arg h "$target" \
    'first(.Peer[]? | select(.HostName == $h)) | if .Online then (.DNSName | rtrimstr(".")) else "!offline" end' 2>/dev/null)"

if [ "$peer" = '!offline' ]; then
  notify "$target is offline"
  exit 0
fi
# Empty means the tailnet does not know this name, so hand the bare target to ssh, whose config does.
[ -n "$peer" ] && target="$peer"

# This is the only process with both machines in scope, so it stamps the far side's view of THIS one —
# nothing on the box could otherwise learn the workstation's OS. `env` as a remote command needs no AcceptEnv.
# stty -echo leads, as in kitty-ql-quake.sh: the remote pty echoes until fzf takes over, and here that covers the ssh round-trip too.
remote_cmd="stty -echo 2>/dev/null; env DESKTOP_OS='$(uname -s)' DESKTOP_HOST='$(hostname -s)' zsh -l -c '~/.config/launcher/launcher-quake.sh'; stty echo 2>/dev/null"

# -tt forces a pty (`tailscale ssh` cannot take -t) or remote fzf dies on /dev/tty; -l without -i skips .zshrc's fastfetch banner.
exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal \
  --instance-group remote \
  --config "$HOME/.config/kitty/quick-access-terminal-remote.conf" \
  ssh -tt "$target" "$remote_cmd"
