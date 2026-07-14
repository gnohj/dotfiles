#!/usr/bin/env bash
# karabiner-driverkit version: 1   (bump to force a re-run on `chezmoi apply`)
#
# Installs + PINS Karabiner-DriverKit-VirtualHIDDevice v6.2.0 — the only version
# kanata 1.11.x speaks (its bundled karabiner-driverkit crate is built against
# that release's IPC; pqrs changes protocol between minor versions). A newer
# driver makes kanata log `connect_failed asio.system:2` and the keyboard dies.
#
# Karabiner-Elements is deliberately NOT installed (removed from homebrew.nix): it
# ships an incompatible newer driver AND its own grabber fights kanata. We install
# only the standalone pinned driver here; the daemon that runs it is declared in
# nix-darwin (launchd.daemons.karabiner-vhid-daemon).
#
# macOS only. Every step is best-effort so a hiccup never aborts `chezmoi apply`.
set -uo pipefail
[ "$(uname)" = "Darwin" ] || exit 0

VERSION="6.2.0"
PKG_URL="https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v${VERSION}/Karabiner-DriverKit-VirtualHIDDevice-${VERSION}.pkg"
MGR="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"

installed=$(pkgutil --pkg-info org.pqrs.Karabiner-DriverKit-VirtualHIDDevice 2>/dev/null | awk '/version:/{print $2}')

if [ "$installed" = "$VERSION" ]; then
  echo "==> Karabiner-DriverKit-VirtualHIDDevice $VERSION already installed"
else
  echo "==> installing Karabiner-DriverKit-VirtualHIDDevice $VERSION (was: ${installed:-none}) — needs sudo"
  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/vhid.pkg" "$PKG_URL"; then
    sudo installer -pkg "$tmp/vhid.pkg" -target / || echo "!! installer failed — run manually: sudo installer -pkg $tmp/vhid.pkg -target /"
    [ -x "$MGR" ] && sudo "$MGR" forceActivate || true
    echo "==> APPROVE the driver: System Settings > General > Login Items & Extensions > Driver Extensions"
    echo "    (macOS requires a one-time manual approval; it cannot be scripted.)"
  else
    echo "!! download failed — install manually from $PKG_URL"
  fi
  rm -rf "$tmp"
fi

# The daemon that RUNS this driver is declared in nix-darwin
# (launchd.daemons.karabiner-vhid-daemon). On a fresh machine that's the only
# copy. This box also has a hand-made /Library/LaunchDaemons/org.pqrs.* plist from
# the original manual fix — remove it ONCE, by hand, after `darwin-rebuild` brings
# up the nix daemon (so there's never a moment with zero daemons). See MANUAL_SETUP.
