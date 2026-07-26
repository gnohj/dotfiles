#!/bin/bash
# remote quake (skhd cmd+rctrl+t): the launcher on the dev-context target. Local counterpart: kitty-ql-quake.sh.
export PATH="$HOME/.local/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

kind=$(dev-context kind 2>/dev/null || echo local)
target=$(dev-context target 2>/dev/null || true)

if [ "$kind" = local ] || [ -z "$target" ]; then
  mac-notify -t "remote quake" -m "dev-context is local — nothing to attach to" -T 5 2>/dev/null
  exit 0
fi

# Resolve the FQDN at runtime: a MagicDNS short name has no known_hosts entry, and the address must stay out of the tracked ssh config.
if [ "$kind" = tailscale ]; then
  fqdn=$(tailscale status --json 2>/dev/null |
    jq -r --arg h "$target" '.Peer[] | select(.HostName==$h) | .DNSName' | sed 's/\.$//')
  [ -n "$fqdn" ] && target="$fqdn"
fi

# -tt forces a pty (`tailscale ssh` cannot take -t) or remote fzf dies on /dev/tty; -l without -i skips .zshrc's fastfetch banner.
exec /Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal \
  --instance-group remote \
  --config "$HOME/.config/kitty/quick-access-terminal-remote.conf" \
  ssh -tt "$target" zsh -l -c '~/.config/launcher/launcher-quake.sh'
