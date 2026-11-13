#!/usr/bin/env bash
# Quake entry point (`ql`): launcher.sh with LAUNCHER_MODE=quake, a persistent root-menu loop for the kitty quake or any plain shell.
exec env LAUNCHER_MODE=quake "$HOME/.config/launcher/launcher.sh" "$@"
