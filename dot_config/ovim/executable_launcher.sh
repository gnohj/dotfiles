#!/bin/bash
# Custom ovim launcher script for Alacritty without decorations

alacritty \
  --option window.decorations=None \
  --option window.opacity=0.95 \
  --title "$OVIM_TITLE" \
  -e nvim "$OVIM_FILE" --cmd "let g:ovim_socket='$OVIM_SOCKET'"
