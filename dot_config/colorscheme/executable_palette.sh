#!/usr/bin/env bash
# Load the palette: active scheme, then the Omarchy theme on top. Source this, not those two.
# shellcheck disable=SC1091,SC2034

if [ -r "$HOME/.config/colorscheme/active/active-colorscheme.sh" ]; then
  unset gnohj_text gnohj_selection
  . "$HOME/.config/colorscheme/active/active-colorscheme.sh"
fi
if [ -r "$HOME/.config/colorscheme/omarchy-palette.sh" ]; then
  . "$HOME/.config/colorscheme/omarchy-palette.sh"
fi

# Named roles: a surface asks for the job it needs, so one numbered slot never has to serve two.
gnohj_text="${gnohj_text:-${gnohj_color14:-}}"
gnohj_text_muted="${gnohj_color09:-}"
gnohj_selection="${gnohj_selection:-${gnohj_color17:-}}"
gnohj_accent="${gnohj_color03:-}"
