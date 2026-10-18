#!/usr/bin/env bash
# Install missing per-user plugins and move any installed plugin onto its pinned commit, on every apply.
set -uo pipefail

# A failed mise install can leave herdr absent, so skip now and retry on the next apply.
command -v herdr >/dev/null 2>&1 || { echo "herdr not on PATH yet; skipping plugin install"; exit 0; }

# plugin id, install source, pinned commit, and track (release|head) read by herdr-plugins-bump
plugins=(
  "annotate|plannotator/herdr-annotate|e3ca7e88ada0c77baf5714c006a5abe36798349c|head"
  "herdr-file-viewer|smarzban/herdr-file-viewer|4c2add6d952e81abc9ba4bbb9ff90107a626098c|release"
  "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|79679dacc791f70fc34de8b29a3cf9706c0f5b2f|release"
  "rmarganti.herdr-pluck|rmarganti/herdr-pluck|d1eacb80956c3a23ab6f7428a9e83961fb86ba28|release"
)

installed="$(herdr plugin list 2>/dev/null || true)"
for entry in "${plugins[@]}"; do
  IFS='|' read -r id src ref _track <<<"$entry"
  line="$(printf '%s\n' "$installed" | grep -F -- "- $id (" || true)"
  current="$(printf '%s\n' "$line" | sed -n 's/.*@\([0-9a-f]*\)\].*/\1/p')"
  if [ "$current" = "$ref" ]; then
    continue
  fi
  if [ -n "$line" ]; then
    echo "herdr: moving plugin $src ${current:0:7} -> ${ref:0:7}"
  else
    echo "herdr: installing plugin $src"
  fi
  herdr plugin install "$src" --ref "$ref" --yes || echo "herdr: install of $src failed - continuing"
done
