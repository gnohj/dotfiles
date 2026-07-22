#!/usr/bin/env bash
# Seed a default colorscheme on a fresh Linux box so the shell + TUIs come up themed, not on tool defaults.
# The starship.toml guard makes it a no-op once any theme exists, so a later `theme` pick is never clobbered.
set -uo pipefail

[ "$(uname)" = Linux ] || exit 0
[ -f "$HOME/.config/starship/starship.toml" ] && exit 0

SET="$HOME/.config/zshrc/colorscheme-set.sh"
SCHEME="evergarden-winter-mute-colors.sh"
[ -x "$SET" ] && [ -f "$HOME/.config/colorscheme/list/$SCHEME" ] || exit 0

echo "==> seeding default colorscheme ($SCHEME)"
"$SET" "$SCHEME" || echo "   (colorscheme-set failed; run \`theme\` by hand)"
