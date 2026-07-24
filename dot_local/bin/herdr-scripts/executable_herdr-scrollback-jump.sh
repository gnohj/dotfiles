#!/usr/bin/env bash
# prefix+u entry point (prefix+e is herdr-scrollback.sh). Exists only so the binding is a BARE name: herdr popup commands are not shell-split, so `herdr-scrollback.sh --jump` in config.toml never ran.
exec "$HOME/.local/bin/herdr-scripts/herdr-scrollback.sh" --jump
