#!/usr/bin/env bash
# herdr-plugins version: 1   (bump to force a re-run on `chezmoi apply`)
#
# Install the herdr plugins this config depends on. herdr keeps plugins in its own store
# (~/.config/herdr/plugins), NOT in chezmoi — so only the config.toml keybindings are tracked,
# and a fresh machine would otherwise have the bindings but no plugins. This closes that gap.
#
# Idempotent: checks the installed list and installs only what is missing, so re-runs are cheap
# (no rebuilds). A released tag downloads a prebuilt GitHub asset; an unreleased commit falls back
# to a local Cargo build if Rust is present.
#
# Bindings that need these (dot_config/herdr/config.toml):
#   prefix+f       → herdr-file-viewer   (git-aware file viewer)
#   prefix+shift+f → herdr-pluck         (tmux-fingers-style token copy)
#   h/j/k/l chords → vim-herdr-navigation
set -uo pipefail

# herdr may not be installed yet on a fresh box (it comes from nix/brew). If so, skip quietly —
# re-run happens on the next `chezmoi apply` once herdr is on PATH (bump the version above, or it
# re-triggers when this file changes). Exit 0 so apply is not marked failed.
command -v herdr >/dev/null 2>&1 || { echo "herdr not on PATH yet; skipping plugin install"; exit 0; }

# plugin id (as shown by `herdr plugin list`)  ->  install source (owner/repo)
plugins=(
  "herdr-file-viewer=smarzban/herdr-file-viewer"
  "vim-herdr-navigation=paulbkim-dev/vim-herdr-navigation"
  "rmarganti.herdr-pluck=rmarganti/herdr-pluck"
)

installed="$(herdr plugin list 2>/dev/null || true)"
for entry in "${plugins[@]}"; do
  id="${entry%%=*}"
  src="${entry#*=}"
  if printf '%s\n' "$installed" | grep -qF "$id"; then
    continue
  fi
  echo "herdr: installing plugin $src"
  herdr plugin install "$src" --yes || echo "herdr: install of $src failed — continuing"
done
