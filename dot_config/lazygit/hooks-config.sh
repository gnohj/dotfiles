#!/bin/bash
# This script is sourced by lazygit to disable husky
# Create a marker file that husky hooks can check for
touch /tmp/lazygit-no-husky-$$
trap "rm -f /tmp/lazygit-no-husky-$$" EXIT

/opt/homebrew/bin/lazygit "$@"