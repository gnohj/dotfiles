#!/usr/bin/env bash
# Build the bundle claiming msteams: for the Teams PWA; an AppleScript applet, since macOS delivers URLs by Apple event.
set -euo pipefail

echo "
🔧 Run OnChange [After] msteams URL handler........"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "🚧 Skipping msteams URL handler (not macOS)"
  exit 0
fi

APP="$HOME/Applications/msteams-handler.app"
TMP="$(mktemp -d)"
SRC="$TMP/msteams-handler.applescript"
trap 'rm -rf "$TMP"' EXIT

cat >"$SRC" <<'SCPT'
on open location this_URL
	do shell script "\"$HOME\"/.local/bin/msteams-open " & quoted form of this_URL
end open location
SCPT

mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" "$SRC"

plist="$APP/Contents/Info.plist"
pb=/usr/libexec/PlistBuddy

# osacompile omits most of these keys, so every write is add-or-overwrite.
pbset() {
  "$pb" -c "Add :$1 $2 $3" "$plist" 2>/dev/null || "$pb" -c "Set :$1 $3" "$plist"
}

pbset CFBundleIdentifier string com.gnohj.msteams-handler
pbset CFBundleName string msteams-handler
# Background-only: a handler that bounces in the Dock on every meeting link is noise.
pbset LSUIElement bool true

"$pb" -c "Delete :CFBundleURLTypes" "$plist" 2>/dev/null || true
"$pb" -c "Add :CFBundleURLTypes array" "$plist"
"$pb" -c "Add :CFBundleURLTypes:0 dict" "$plist"
"$pb" -c "Add :CFBundleURLTypes:0:CFBundleURLName string Microsoft Teams Link" "$plist"
"$pb" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$plist"
"$pb" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string msteams" "$plist"
"$pb" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:1 string msteams-enterprise" "$plist"

touch "$APP"

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
# The stale com.microsoft.teams2 handlerpref outlives the uninstalled cask, so re-register to claim it.
[ -x "$lsregister" ] && "$lsregister" -f "$APP" 2>/dev/null || true

echo "🎉 msteams URL handler ready ($APP)"
