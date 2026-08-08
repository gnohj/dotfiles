#!/usr/bin/env bash
# Builds ~/Applications/vlc-multi.app so Finder opens each video in its own VLC process, not the running instance's playlist.
set -euo pipefail

echo "
🔧 Run OnChange [After] VLC multi-instance handler........"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "🚧 Skipping vlc-multi (not macOS)"
  exit 0
fi

VLC_APP="/Applications/VLC.app"
APPS_DIR="$HOME/Applications"
APP="$APPS_DIR/vlc-multi.app"
PLIST="$APP/Contents/Info.plist"
PB="/usr/libexec/PlistBuddy"

if [ ! -d "$VLC_APP" ]; then
  echo "❌  $VLC_APP not found — skipping vlc-multi build"
  exit 0
fi

mkdir -p "$APPS_DIR"
rm -rf "$APP"

# `open -n` is what forces a new process; quoted form survives spaces in paths.
tmp_scpt="$(mktemp -t vlc-multi).applescript"
cat >"$tmp_scpt" <<'SCPT'
on launchNew(posixPath)
	do shell script "/usr/bin/open -n -a /Applications/VLC.app " & quoted form of posixPath
end launchNew

on open theFiles
	repeat with f in theFiles
		launchNew(POSIX path of f)
	end repeat
	tell me to quit
end open

on run
	do shell script "/usr/bin/open -n -a /Applications/VLC.app"
	tell me to quit
end run
SCPT

# Must be an AppleScript bundle: a shell stub gets empty argv on document-open, paths arrive only as an Apple Event.
osacompile -o "$APP" "$tmp_scpt"
rm -f "$tmp_scpt"

plist_set() {
  "$PB" -c "Set :$1 $2" "$PLIST" 2>/dev/null || "$PB" -c "Add :$1 $3 $2" "$PLIST"
}

plist_set CFBundleIdentifier com.gnohj.vlc-multi string
plist_set CFBundleName vlc-multi string
plist_set CFBundleDisplayName vlc-multi string
# No dock icon or menu bar: this applet exists only to relay the open event.
plist_set LSUIElement true bool

# Declaring the UTIs is what lists vlc-multi under Finder's "Open with"; osacompile's own empty CFBundleDocumentTypes is dropped first.
"$PB" -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :CFBundleDocumentTypes array" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Video" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"

i=0
for uti in public.mpeg-4 com.apple.m4v-video com.apple.quicktime-movie org.matroska.mkv public.avi public.movie; do
  "$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:$i string $uti" "$PLIST"
  i=$((i + 1))
done

icon_src="$VLC_APP/Contents/Resources/VLC.icns"
[ -f "$icon_src" ] || icon_src="$VLC_APP/Contents/Resources/movie.icns"
if [ -f "$icon_src" ]; then
  cp "$icon_src" "$APP/Contents/Resources/applet.icns"
fi

touch "$APP"

# Nudge LaunchServices so the bundle shows up in Finder's "Open with" list.
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$lsregister" ] && "$lsregister" -f "$APP" 2>/dev/null || true

echo "✅  built $APP"
echo "🎉 vlc-multi ready — set it via Finder → Cmd+I on an .mp4 → Open with → vlc-multi → Change All"
