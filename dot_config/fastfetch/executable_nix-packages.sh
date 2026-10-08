#!/bin/bash
# Prints the nix-system or nix-default package count; fastfetch's nix scan costs ~160ms, so it reruns only when a profile link changes.
set -u

field="${1:?usage: nix-packages.sh system|default}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch/nix-packages"
key="$(realpath /run/current-system) $(realpath /nix/var/nix/profiles/default)"

if [ "$(head -n 1 "$cache" 2>/dev/null)" != "$key" ]; then
  counts="$(fastfetch -c "$HOME/.config/fastfetch/nix-packages.jsonc" --format json 2>/dev/null |
    /usr/bin/jq -r '.[0].result | "\(.nixSystem // 0) \(.nixDefault // 0)"')"
  mkdir -p "${cache%/*}"
  printf '%s\n%s\n' "$key" "$counts" > "$cache.$$" && mv "$cache.$$" "$cache"
fi

read -r system default < <(sed -n 2p "$cache")
if [ "$field" = system ]; then echo "$system"; else echo "$default"; fi
