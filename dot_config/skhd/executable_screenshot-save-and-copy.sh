#!/bin/bash
# Native macOS screenshot → clipboard, staged at a shared path (/tmp/agent-clip) and mirrored to each VPS in HOSTS so Cmd+V works local or remote.
export PATH="/opt/homebrew/bin:$PATH"

STAGE="/tmp/agent-clip"          # writable on macOS and Linux alike
HOSTS=()                         # add ssh aliases here to enable remote paste (none yet — no VPS)

# Match macshot's "Screenshot-{date} at {time}" so hyper+x and hyper+s produce identical iCloud archive naming.
ARCHIVE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Screenshot-$(date +'%Y-%m-%d at %H-%M-%S').png"

mkdir -p "$STAGE"
find "$STAGE" -type f -mmin +1440 -delete 2>/dev/null   # prune local staged shots >24h
name="clip-$(date +%Y%m%d-%H%M%S)-$RANDOM.png"   # space-free for pasted paths
path="$STAGE/$name"

screencapture -i "$path"
[ -f "$path" ] || exit 0         # Esc = user cancelled

cp "$path" "$ARCHIVE" 2>/dev/null # keep the nicely-named iCloud archive
printf %s "$path" | pbcopy        # the ONE path — valid on Mac and any mirrored VPS

# Mirror to each VPS at the identical path. Backgrounded so the hotkey returns instantly; unreachable hosts fail harmlessly.
for h in "${HOSTS[@]}"; do
  ( ssh -o ConnectTimeout=3 "$h" "mkdir -p $STAGE && find $STAGE -type f -mmin +1440 -delete 2>/dev/null" \
      && scp -q "$path" "$h:$path" ) >/dev/null 2>&1 &
done
