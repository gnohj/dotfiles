#!/usr/bin/env bash
# moshi-desktop version: 1   (bump to force a re-run on `chezmoi apply`)
# Installs Moshi Desktop from the CDN dmg (no cask upstream); install-if-absent, since it self-updates.
set -uo pipefail
[[ "$OSTYPE" == darwin* ]] || exit 0

APP="/Applications/Moshi.app"
MANIFEST="https://cdn.getmoshi.app/desktop/latest.json"

if [ -d "$APP" ]; then
  echo "==> Moshi Desktop already installed (self-updates in-app)"
  exit 0
fi

case "$(uname -m)" in
  arm64) ARCH="aarch64" ;;
  x86_64) ARCH="x86_64" ;;
  *) echo "!! moshi-desktop: unsupported arch $(uname -m)"; exit 0 ;;
esac

VERSION=$(curl -fsSL --max-time 30 "$MANIFEST" 2>/dev/null |
  grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$VERSION" ]; then
  echo "!! moshi-desktop: could not read $MANIFEST — install manually from https://getmoshi.app/desktop"
  exit 0
fi

DMG_URL="https://cdn.getmoshi.app/desktop/v${VERSION}/Moshi_${VERSION}_${ARCH}.dmg"
echo "==> installing Moshi Desktop $VERSION ($ARCH)"

tmp=$(mktemp -d)
trap 'hdiutil detach "$tmp/mnt" -quiet 2>/dev/null; rm -rf "$tmp"' EXIT

if ! curl -fsSL --max-time 300 -o "$tmp/moshi.dmg" "$DMG_URL"; then
  echo "!! moshi-desktop: download failed — install manually from $DMG_URL"
  exit 0
fi

if ! hdiutil attach "$tmp/moshi.dmg" -mountpoint "$tmp/mnt" -nobrowse -quiet; then
  echo "!! moshi-desktop: could not mount $tmp/moshi.dmg — install manually from https://getmoshi.app/desktop"
  exit 0
fi

if ditto "$tmp/mnt/Moshi.app" "$APP"; then
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  echo "==> Moshi Desktop $VERSION installed to $APP"
  echo "    Pair it with the machine on first launch; it self-updates from then on."
else
  echo "!! moshi-desktop: copy to /Applications failed — drag Moshi.app across by hand from $DMG_URL"
fi
