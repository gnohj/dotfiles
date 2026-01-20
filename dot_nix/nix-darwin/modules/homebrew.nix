{ config, pkgs, lib, ... }:

{
  # Homebrew configuration
  # Run: darwin-rebuild switch --flake ~/.nix

  homebrew = {
    enable = true; # nix installs Homebrew if not present

    # Auto-update Homebrew and packages
    onActivation = {
      autoUpdate = true;   # Always get latest pkg definitions
      upgrade = false;     # Disabled - don't auto upgrade to latest version
      cleanup = "zap";     # Uninstall packages not declared here
    };

    # Taps (third-party repositories)
    taps = [
      "anomalyco/tap"
      "FelixKratz/formulae"
      "garrettkrohn/treekanga"
      "nikitabobko/tap"
      "oven-sh/bun"
      "fastly/tap"
      "pulumi/tap"
      "sst/tap"
      "koekeishiya/formulae"
      "morantron/tmux-fingers"
      "tonisives/tap"
    ];

    # CLI packages (formulae)
    brews = [
      # AI Tools
      "anomalyco/tap/opencode"

      # System services & window management
      "FelixKratz/formulae/borders"
      "FelixKratz/formulae/sketchybar"
      "kanata"
      "koekeishiya/formulae/skhd"

      # Note: Lua packages (cjson, luaposix) now managed by Nix in packages.nix

      # Shell & plugin managers
      "zinit"

      # Terminal & tmux utilities
      "gitmux"
      "morantron/tmux-fingers/tmux-fingers"
      "sesh"
      "garrettkrohn/treekanga/treekanga"

      # macOS utilities
      "mailsy"
      "mas"
      "pngpaste"
      "spicetify-cli"
      "switchaudio-osx"
      "usage"

      # Development tools
      "pulumi/tap/pulumi"
      "nss"
      "xcodegen"

      # Additional tools
      "wordnet"
      "zx"
    ];

    # GUI applications (casks)
    casks = [
      # AI Tools
      "claude-code"

      # Browsers
      "brave-browser"
      "firefox"
      "google-chrome"
      "microsoft-edge"
      "zen"

      # Communication
      "discord"
      "microsoft-outlook"
      "microsoft-teams"
      "slack"
      "zoom"

      # Development
      "docker-desktop"  # Renamed from "docker"

      # Terminals
      "ghostty"

      # Productivity
      "bitwarden"
      "obsidian"
      "raycast"
      "whimsical"

      # Window Management & Navigation
      "nikitabobko/tap/aerospace"
      "homerow"
      "karabiner-elements"
      "mouseless"

      # System Utilities
      "aldente"
      "appcleaner"
      "betterdisplay"
      "localsend"
      "shottr"

      # Input Devices
      "logi-options+"

      # Media
      "spotify"
      "vlc"

      # System Wide Vim Mode
      "tonisives/tap/ovim"

      # VPN & Security
      "private-internet-access"

      # Fonts
      "font-sf-pro"
      "font-space-mono-nerd-font"
      "sf-symbols"
    ];

    # Mac App Store apps (requires mas-cli)
    masApps = {
      "Xcode" = 497799835;
    };
  };
}
