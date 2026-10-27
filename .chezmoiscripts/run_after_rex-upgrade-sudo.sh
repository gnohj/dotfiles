#!/usr/bin/env bash
# Installs the root-owned rex-upgrade and its passwordless sudoers rule; run_after so a box that gains Rex later still gets them.
set -eu

[ "$(uname)" = "Linux" ] || exit 0
[ -f /etc/pacman.d/rex.conf ] || exit 0

target=/usr/local/sbin/rex-upgrade
rule="$(id -un) ALL=(root) NOPASSWD: $target \"\""

dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT

# Runs as root with no password, so it takes no arguments and trusts nothing from the caller's environment.
cat >"$dir/rex-upgrade" <<'EOF'
#!/bin/bash
set -euo pipefail
export PATH=/usr/bin
conf="$(mktemp)"
trap 'rm -f "$conf"' EXIT
# Syncs only the rex repo, so core/extra stay as `up` left them and this never sets up an Arch partial upgrade.
printf '[options]\nArchitecture = auto\nInclude = /etc/pacman.d/rex.conf\n' >"$conf"
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman --config "$conf" -Sy --needed --noconfirm rex
EOF
printf '%s\n' "$rule" >"$dir/sudoers"

if cmp -s "$dir/rex-upgrade" "$target" && sudo -n -l 2>/dev/null | grep -qF "NOPASSWD: $target \"\""; then
  exit 0
fi
if [ ! -t 0 ] && ! sudo -n true 2>/dev/null; then
  echo "!! rex-upgrade not installed - run chezmoi apply in a terminal on this box"
  exit 0
fi

echo "==> installing $target and its sudoers rule"
sudo install -o root -g root -m 0755 "$dir/rex-upgrade" "$target"
sudo visudo -cqf "$dir/sudoers"
sudo install -o root -g root -m 0440 "$dir/sudoers" /etc/sudoers.d/rex-upgrade
