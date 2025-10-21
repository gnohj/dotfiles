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

      # Migrated from: run_onchange_before_mac_system.sh.tmpl
      _HIHideMenuBar = true;                         # Auto-hide menu bar
      NSAutomaticWindowAnimationsEnabled = false;    # Disable window animations
      NSWindowShouldDragOnGesture = true;           # Move windows by dragging anywhere (Ctrl+Cmd)

      # Keyboard settings
      # Migrated from: run_onchange_before_mac_system.sh.tmpl
      InitialKeyRepeat = 15;                        # Faster initial key repeat
      KeyRepeat = 1;                                # Faster key repeat
      # ApplePressAndHoldEnabled = false;

      # Expand save and print panels by default
      # NSNavPanelExpandedStateForSaveMode = true;
      # NSNavPanelExpandedStateForSaveMode2 = true;
      # PMPrintingExpandedStateForPrint = true;
      # PMPrintingExpandedStateForPrint2 = true;
    };

    # Trackpad settings
    trackpad = {
      # Clicking = true; # Tap to click
      # TrackpadRightClick = true;
    };

    # Screenshot settings
    screencapture = {
      # location = "~/Desktop";
      # type = "png";
    };
  };

  # Keyboard settings (separate from defaults)
  # system.keyboard = {
  #   enableKeyMapping = true;
  #   remapCapsLockToControl = true;
  # };
}
