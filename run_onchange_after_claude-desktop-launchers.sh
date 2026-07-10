#!/usr/bin/env bash
# Build native .app launchers for the Claude Desktop app, one per account
# profile (claude-personal, claude-work). Each bundle is a thin stub whose
# executable execs ~/.local/bin/claude-desktop <account>, which opens an
# isolated Claude instance via --user-data-dir. Single source of truth: the
# stub, the fzf launcher, and any hotkey all call that one wrapper. Rebuilt
# whenever this script changes (run_onchange). Mirrors the shape of the
# installer-created "Claude Code URL Handler.app".
set -euo pipefail

echo "
🔧 Run OnChange [After] Claude Desktop launchers........"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "🚧 Skipping Claude Desktop launchers (not macOS)"
  exit 0
fi

CLAUDE_APP="/Applications/Claude.app"
ICON_SRC="$CLAUDE_APP/Contents/Resources/electron.icns"
APPS_DIR="$HOME/Applications"

if [ ! -d "$CLAUDE_APP" ]; then
  echo "❌  $CLAUDE_APP not found — skipping launcher build"
  exit 0
fi

mkdir -p "$APPS_DIR"

build_launcher() {
  account="$1"
  emoji="$2"
  app="$APPS_DIR/claude-$account.app"

  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

  cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.gnohj.claude-$account</string>
  <key>CFBundleName</key>
  <string>claude-$account</string>
  <key>CFBundleDisplayName</key>
  <string>claude-$account</string>
  <key>CFBundleExecutable</key>
  <string>launch</string>
  <key>CFBundleIconFile</key>
  <string>icon</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
</dict>
</plist>
PLIST

  cat >"$app/Contents/MacOS/launch" <<LAUNCH
#!/usr/bin/env bash
exec "\$HOME/.local/bin/claude-desktop" $account
LAUNCH
  chmod +x "$app/Contents/MacOS/launch"

  cp "$ICON_SRC" "$app/Contents/Resources/icon.icns"
  printf 'APPL????' >"$app/Contents/PkgInfo"

  touch "$app"
  echo "✅  built $app ($emoji claude-$account)"
}

build_launcher personal 👤
build_launcher work 💼

# Nudge LaunchServices so Spotlight/Dock pick up the new/changed bundles.
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$lsregister" ] && "$lsregister" -f "$APPS_DIR/claude-personal.app" "$APPS_DIR/claude-work.app" 2>/dev/null || true

echo "🎉 Claude Desktop launchers ready (~/Applications/claude-personal.app, claude-work.app)"
