#!/usr/bin/env bash
# Center a window on the main screen's visible area (excludes menu bar + dock).
# Built for non-resizable windows like macOS System Settings since Ventura.
#
# Usage: center-window.sh "<process name>"
# Example: center-window.sh "System Settings"

set -euo pipefail

PROCESS="${1:?process name required}"

# Wait for the window to materialize after on-window-detected fires.
sleep 0.4

# Query screen dimensions via NSScreen — reliable across multi-monitor
# setups, unlike `bounds of window of desktop` which can fail or return
# the full virtual desktop. Returns four ints separated by spaces:
#   visibleW visibleH topYInAppleScriptCoords leftXInAppleScriptCoords
read SCREEN_W SCREEN_H SCREEN_TOP SCREEN_LEFT < <(osascript -l JavaScript <<'JXA'
ObjC.import("AppKit");
var screen = $.NSScreen.mainScreen;
var f  = screen.frame;
var vf = screen.visibleFrame;
// AppleScript window-position uses top-left origin of the main screen.
// NSScreen uses bottom-left. Convert top-of-visible-area into AppleScript Y.
var topY = f.size.height - (vf.origin.y + vf.size.height);
[vf.size.width, vf.size.height, topY, vf.origin.x].join(" ");
JXA
)

osascript <<APPLESCRIPT
tell application "System Events"
  if exists (process "$PROCESS") then
    tell process "$PROCESS"
      if (count of windows) > 0 then
        set winSize to size of window 1
        set winW to item 1 of winSize
        set winH to item 2 of winSize
        set newX to ($SCREEN_LEFT + ($SCREEN_W - winW) / 2) as integer
        set newY to ($SCREEN_TOP  + ($SCREEN_H - winH) / 2) as integer
        set position of window 1 to {newX, newY}
      end if
    end tell
  end if
end tell
APPLESCRIPT
