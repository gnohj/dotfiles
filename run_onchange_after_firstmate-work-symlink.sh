#!/usr/bin/env bash
# ~/Developer/firstmate-work -> ~/Developer/firstmate. Firstmate has ONE code root and two homes
# selected by FM_HOME (~/.local/share/firstmate{,-work}); ~/.local/bin/fm cds to the code root and
# sets FM_HOME from its personal/work argument. Both sesh entries therefore belong at the code root
# — the homes are state dirs with no AGENTS.md and no bin/. But herdr-sesh-layout.sh resolves a
# session's startup_command by matching .Path in `sesh list -c -j` and taking `first`, so two
# entries sharing one path are indistinguishable and the second silently inherits the first's
# command — failing in the direction of running the personal account on work. A second path that
# resolves to the same directory keeps them distinct with no change to the identity model.
# Both platforms need it, hence this script rather than the Linux-only bootstrap.
#
# ln -sfn, NOT ln -sf: re-running -sf against an existing symlink-to-directory dereferences it and
# drops the new link INSIDE the target (~/Developer/firstmate/firstmate-work). -n is the idempotency.
set -eu

src="$HOME/Developer/firstmate"
link="$HOME/Developer/firstmate-work"

[ -d "$src" ] || exit 0

# A real directory here is somebody's data, not our link — never clobber it.
if [ -e "$link" ] && [ ! -L "$link" ]; then
  echo "!! $link exists and is not a symlink — leaving it alone" >&2
  exit 0
fi

ln -sfn "$src" "$link"
