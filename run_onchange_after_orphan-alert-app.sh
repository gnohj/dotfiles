#!/usr/bin/env bash
# Dedicated terminal-notifier -sender bundle so orphan alerts get their own Notification-style setting; after first apply set System Settings -> Notifications -> "Orphan Alert" -> Alerts.
set -euo pipefail
[[ "$OSTYPE" == darwin* ]] || exit 0

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Clean up the old pre-rename bundle so it stops lingering in Notification settings.
OLD_APP="$HOME/Applications/RunawayAlert.app"
if [[ -d "$OLD_APP" ]]; then
  [[ -x "$LSREGISTER" ]] && "$LSREGISTER" -u "$OLD_APP" 2>/dev/null || true
  rm -rf "$OLD_APP"
fi

APP="$HOME/Applications/OrphanAlert.app"
BUNDLE_ID="com.gnohj.orphan-alert"
mkdir -p "$APP/Contents/MacOS"

cat >"$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Orphan Alert</string>
  <key>CFBundleDisplayName</key><string>Orphan Alert</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>orphan-alert</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

cat >"$APP/Contents/MacOS/orphan-alert" <<'STUB'
#!/bin/bash
exit 0
STUB
chmod +x "$APP/Contents/MacOS/orphan-alert"

# Register with LaunchServices so -sender resolves + it shows in Notification settings.
[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$APP" 2>/dev/null || true
