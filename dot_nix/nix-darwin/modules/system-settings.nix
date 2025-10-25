{ config, pkgs, lib, ... }:

{
  # macOS System Settings
  # All settings are documented at:
  # https://daiderd.com/nix-darwin/manual/index.html

  system.defaults = {
    # Dock settings
    # Migrated from: run_onchange_before_mac_system.sh.tmpl
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
        "/Users/${config.system.primaryUser}/Applications/Chrome Apps.localized/Google Calendar.app"
        "/Applications/Marta.app"
        "/Applications/Google Chrome.app"
        "/Applications/Brave Browser.app"
        "/Applications/Ghostty.app"
      ];
    };

    # Finder settings
    # Migrated from: run_onchange_before_mac_system.sh.tmpl
    finder = {
      AppleShowAllFiles = true;          # Show hidden files
      CreateDesktop = false;             # Hide Desktop items on desktop
      # FXPreferredViewStyle = "Nlsv";   # List view
      # ShowPathbar = true;
      # ShowStatusBar = true;
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

      # Migrated from: run_onchange_before_mac_system.sh.tmpl
      _HIHideMenuBar = true;                         # Auto-hide menu bar
      NSAutomaticWindowAnimationsEnabled = false;    # Disable window animations
      NSWindowShouldDragOnGesture = true;           # Move windows by dragging anywhere (Ctrl+Cmd)

      # Keyboard settings
      # Migrated from: run_onchange_before_mac_system.sh.tmpl
      InitialKeyRepeat = 15;                        # Faster initial key repeat (delay before repeat)
      KeyRepeat = 1;                                # Faster key repeat (speed once repeating)
      # ApplePressAndHoldEnabled = false;           # Enable press-and-hold for accented characters
      # "com.apple.keyboard.fnState" = false;       # Use F1-F12 as standard function keys

      # Trackpad & Mouse settings
      # Based on System Settings → Trackpad and Mouse screenshots
      "com.apple.swipescrolldirection" = true;      # Natural scrolling (enabled)
      "com.apple.trackpad.scaling" = 3.0;           # Trackpad tracking speed: 0.0 (slow) to 3.0 (fast)
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
      # location = "~/Desktop";
      # type = "png";
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

}
