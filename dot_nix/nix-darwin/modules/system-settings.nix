{ config, pkgs, lib, ... }:

{
  # macOS System Settings
  # All settings are documented at:
  # https://daiderd.com/nix-darwin/manual/index.html

  # Security settings
  security.pam.services.sudo_local.touchIdAuth = true;  # Enable Touch ID for sudo

  system.defaults = {
    # Dock settings
    dock = {
      autohide = true;                    # Auto-hide the dock
      autohide-delay = 10.0;             # Dock appears only after 10-second hover
      autohide-time-modifier = 0.0;      # Remove animation delay
      show-recents = false;              # Don't show recent apps
      # orientation = "bottom";
      # tilesize = 48;

      # Persistent apps in Dock
      persistent-apps = [
        "/System/Applications/Mail.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Reminders.app"
        "/Applications/Google Chrome.app"
        "/Applications/Helium.app"
        "/Applications/Ghostty.app"
      ];
    };

    # Finder settings
    finder = {
      AppleShowAllFiles = true;          # Show hidden files
      AppleShowAllExtensions = true;     # Show all file extensions
      CreateDesktop = false;             # Hide Desktop items on desktop
      ShowPathbar = true;                # Show path breadcrumb at bottom
      ShowStatusBar = true;              # Show status bar at bottom (file count, disk space)
      _FXShowPosixPathInTitle = true;    # Show full POSIX path in Finder title
      FXEnableExtensionChangeWarning = false;  # Disable warning when changing file extensions
      # FXPreferredViewStyle = "Nlsv";   # List view
    };

    # Global macOS settings
    NSGlobalDomain = {
      # Set appearance to dark mode (null = light, "Dark" = dark)
      # NOTE: This setting may not apply reliably due to nix-darwin bug
      # See: https://github.com/nix-darwin/nix-darwin/issues/1207
      # Workaround: Manually toggle in System Settings or use AppleScript:
      #   osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
      AppleInterfaceStyle = "Dark";

      # Appearance settings
      AppleShowScrollBars = "Always";               # Always show scroll bars
      NSTableViewDefaultSizeMode = 1;               # Sidebar icon size: 1 (small), 2 (medium), 3 (large)

      # NOTE: Recent Items (NSRecentDocumentsLimit) is not supported by nix-darwin
      # To set to "None", manually run: defaults write NSGlobalDomain NSRecentDocumentsLimit 0

      _HIHideMenuBar = true;                         # Auto-hide menu bar
      NSAutomaticWindowAnimationsEnabled = false;    # Disable window animations
      NSWindowShouldDragOnGesture = true;           # Move windows by dragging anywhere (Ctrl+Cmd)

      # Disable annoying auto-correct features
      NSAutomaticCapitalizationEnabled = false;     # Disable automatic capitalization
      NSAutomaticSpellingCorrectionEnabled = false; # Disable automatic spelling correction
      NSAutomaticPeriodSubstitutionEnabled = false; # Disable automatic period substitution (double-space)

      # Keyboard settings
      InitialKeyRepeat = 15;                        # Faster initial key repeat (delay before repeat)
      KeyRepeat = 1;                                # Faster key repeat (speed once repeating)
      # ApplePressAndHoldEnabled = false;           # Enable press-and-hold for accented characters
      # "com.apple.keyboard.fnState" = false;       # Use F1-F12 as standard function keys

      # Trackpad & Mouse settings
      # Based on System Settings → Trackpad and Mouse screenshots
      "com.apple.swipescrolldirection" = true;      # Natural scrolling (enabled)
      "com.apple.trackpad.scaling" = 10.0;          # Trackpad tracking speed: 0.0-3.0 (UI max), but higher values work
      "com.apple.trackpad.enableSecondaryClick" = true;  # Enable right-click
      "com.apple.trackpad.forceClick" = true;       # Enable Force Click and haptic feedback
      "com.apple.mouse.tapBehavior" = 1;            # Enable tap to click

      # Expand save and print panels by default
      # NSNavPanelExpandedStateForSaveMode = true;
      # NSNavPanelExpandedStateForSaveMode2 = true;
      # PMPrintingExpandedStateForPrint = true;
      # PMPrintingExpandedStateForPrint2 = true;

      # Time format - force 24-hour time
      AppleICUForce24HourTime = true;
    };

    # Trackpad settings
    # Based on System Settings → Trackpad screenshots
    trackpad = {
      # Point & Click tab
      Clicking = true;                    # Enable tap to click
      TrackpadRightClick = true;          # Enable secondary click (right-click)
      TrackpadThreeFingerDrag = false;    # Disable three-finger drag

      # Force Click and haptic feedback
      FirstClickThreshold = 1;            # Click pressure: 0 (light), 1 (medium), 2 (firm)
      SecondClickThreshold = 1;           # Force touch pressure: 0 (light), 1 (medium), 2 (firm)
      ActuationStrength = 1;              # Silent clicking: 0 (enable), 1 (disable)

      # NOTE: The following gesture settings from "More Gestures" tab CANNOT be automated:
      # - Swipe between pages (Off in your config)
      # - Swipe between full-screen apps (Three Fingers Left/Right in your config)
      # - Notification Center (swipe left from right edge with two fingers - Enabled)
      # - Mission Control (swipe up with three fingers - Enabled)
      # - App Exposé (Off in your config)
      # - Launchpad (pinch with thumb and three fingers - Enabled)
      # - Show Desktop (spread with thumb and three fingers - Enabled)
      # These must be configured manually in System Settings → Trackpad → More Gestures
    };

    # Screenshot settings
    screencapture = {
      location = "~/Library/Mobile Documents/com~apple~CloudDocs/Downloads"; # Save screenshots to iCloud Downloads
      type = "png";                       # Save as PNG format
      disable-shadow = false;             # Keep window shadows in screenshots
      show-thumbnail = false;             # Disable thumbnail preview (no focus stealing)
    };

    # Lock Screen settings
    screensaver = {
      askForPassword = true;              # Require password after screensaver/display off
      askForPasswordDelay = 3600;         # Password delay: 3600 seconds = 1 hour
    };

    # Login Window settings
    loginwindow = {
      GuestEnabled = false;               # Disable guest user
    };

  };

  # Keyboard settings
  # Ensure Caps Lock is NOT remapped (stays as Caps Lock)
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = false;
    remapCapsLockToEscape = false;
  };

  # Disable Mission Control "Switch to Desktop N" (symbolic hotkeys 118-127), which grab control+<digit> above the terminal and broke tmux window nav (the "control+3 wall").
  # Uses `defaults -dict-add` (MERGE) NOT system.defaults.CustomUserPreferences, which would rewrite the whole AppleSymbolicHotKeys dict and WIPE the ~65 other hotkeys.
  # keycodes: 1=18 2=19 3=20 4=21 5=23 6=22 7=26 8=28 9=25 0=29 ; control mod = 262144
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "⌨️  Freeing control+1..0 from Mission Control (Switch to Desktop)..." >&2
    disable_desktop_hotkey() {
      sudo -u ${config.system.primaryUser} defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
        -dict-add "$1" "<dict><key>enabled</key><integer>0</integer><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>$2</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>" || true
    }
    disable_desktop_hotkey 118 18   # control+1
    disable_desktop_hotkey 119 19   # control+2
    disable_desktop_hotkey 120 20   # control+3
    disable_desktop_hotkey 121 21   # control+4
    disable_desktop_hotkey 122 23   # control+5
    disable_desktop_hotkey 123 22   # control+6
    disable_desktop_hotkey 124 26   # control+7
    disable_desktop_hotkey 125 28   # control+8
    disable_desktop_hotkey 126 25   # control+9
    disable_desktop_hotkey 127 29   # control+0
    sudo -u ${config.system.primaryUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
  '';

}
