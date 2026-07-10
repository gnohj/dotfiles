#!/usr/bin/env bash
# Thin adapter for tmux-dash's "new session → sesh" option, whose compiled
# binary invokes THIS path (view.rs) inside a 45%x65% display-popup — keep the
# path stable so tmux-dash never needs a rebuild. The actual picker lives in
# sesh-popup.sh; --new-only shows config+zoxide entries that don't already have
# an active tmux session.
exec "$HOME/.config/tmux/sesh-popup.sh" --new-only
