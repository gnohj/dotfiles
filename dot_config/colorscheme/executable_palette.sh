#!/usr/bin/env bash
# Load the palette: active scheme, then the Omarchy theme on top. Source this, not those two.
# shellcheck disable=SC1091

if [ -r "$HOME/.config/colorscheme/active/active-colorscheme.sh" ]; then
  . "$HOME/.config/colorscheme/active/active-colorscheme.sh"
fi
if [ -r "$HOME/.config/colorscheme/omarchy-palette.sh" ]; then
  . "$HOME/.config/colorscheme/omarchy-palette.sh"
fi
