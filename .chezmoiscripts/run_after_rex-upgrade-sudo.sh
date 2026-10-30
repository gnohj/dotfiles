#!/usr/bin/env bash
# Installs the root-owned rex-upgrade and its passwordless sudoers rule; run_after so a box that gains Rex later still gets them.
set -eu

[ "$(uname)" = "Linux" ] || exit 0
[ -f /etc/pacman.d/rex.conf ] || exit 0

target=/usr/local/sbin/rex-upgrade
rule="$(id -un) ALL=(root) NOPASSWD: $target"

dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT

# Passwordless root: accepts only one version-shaped argument and trusts nothing from the caller's environment.
cat >"$dir/rex-upgrade" <<'EOF'
#!/bin/bash
set -euo pipefail
export PATH=/usr/bin
if [ "$#" != 1 ] || ! [[ "$1" =~ ^[0-9]+(\.[0-9]+)*(_g[0-9a-f]+)?-[0-9]+$ ]]; then
  echo "usage: rex-upgrade PKGVER-PKGREL" >&2
  exit 2
fi
arch="$(uname -m)"
server="$(sed -n 's/^Server *= *//p' /etc/pacman.d/rex.conf | head -n 1)"
conf="$(mktemp)"
trap 'rm -f "$conf"' EXIT
printf '[options]\nArchitecture = auto\nRemoteFileSigLevel = Required\n' >"$conf"
# The repo db lists only the newest build; -U by URL still reaches older ones.
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman --config "$conf" -U --needed --noconfirm "${server//\$arch/$arch}/rex-$1-$arch.pkg.tar.zst"
EOF
printf '%s\n' "$rule" >"$dir/sudoers"

if cmp -s "$dir/rex-upgrade" "$target" && sudo -n -l 2>/dev/null | sed 's/^[[:space:]]*//' | grep -qxF "(root) NOPASSWD: $target"; then
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
