#!/usr/bin/env bash
# Seed a default colorscheme on a fresh machine; the active link is the guard, so a theme picked later is never clobbered.
set -uo pipefail

ACTIVE="$HOME/.config/colorscheme/active/active-colorscheme.sh"
[ -e "$ACTIVE" ] && exit 0

SET="$HOME/.config/zshrc/colorscheme-set.sh"
SCHEME="evergarden-winter-mute-colors.sh"
[ -x "$SET" ] && [ -f "$HOME/.config/colorscheme/list/$SCHEME" ] || exit 0

echo "==> seeding default colorscheme ($SCHEME)"
# Linked here, not by the setter: on Omarchy the setter never repoints the active theme.
mkdir -p "$(dirname "$ACTIVE")"
ln -s "../list/$SCHEME" "$ACTIVE"
"$SET" || echo "   (colorscheme-set failed; run \`theme\` by hand)"
