#!/usr/bin/env bash
# Install missing per-user plugins on every apply so deferred or failed installs recover automatically.
set -uo pipefail

# A failed mise install can leave herdr absent, so skip now and retry on the next apply.
command -v herdr >/dev/null 2>&1 || { echo "herdr not on PATH yet; skipping plugin install"; exit 0; }

# plugin id, install source, and pinned commit
plugins=(
  "annotate|plannotator/herdr-annotate|dc871270c273bdeb457b8c0f9f72f40d6ca30925"
  "herdr-file-viewer|smarzban/herdr-file-viewer|647f03236d9aa20de0b07c9de0a951e13a1e59bf"
  "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|79679dacc791f70fc34de8b29a3cf9706c0f5b2f"
  "rmarganti.herdr-pluck|rmarganti/herdr-pluck|d1eacb80956c3a23ab6f7428a9e83961fb86ba28"
)

installed="$(herdr plugin list 2>/dev/null || true)"
for entry in "${plugins[@]}"; do
  IFS='|' read -r id src ref <<<"$entry"
  if printf '%s\n' "$installed" | grep -qF -- "- $id ("; then
    continue
  fi
  echo "herdr: installing plugin $src"
  herdr plugin install "$src" --ref "$ref" --yes || echo "herdr: install of $src failed - continuing"
done
