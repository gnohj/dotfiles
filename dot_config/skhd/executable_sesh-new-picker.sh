#!/usr/bin/env bash
# Thin adapter for tmux-dash's "new session → sesh" option — tmux-dash's binary
# invokes THIS path, so keep it stable to avoid a rebuild. Picker lives in
# sesh-popup.sh; --new-only shows entries without an active tmux session.
exec "$HOME/.config/tmux/sesh-popup.sh" --new-only
