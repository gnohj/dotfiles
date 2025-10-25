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
      "FelixKratz/formulae"
      "nikitabobko/tap"
      "oven-sh/bun"
      "pulumi/tap"
      "sst/tap"
      "koekeishiya/formulae"
      "morantron/tmux-fingers"
    ];

    # CLI packages (formulae)
    brews = [
      # System services & window management
      "FelixKratz/formulae/borders"
      "FelixKratz/formulae/sketchybar"
      "kanata"
      "koekeishiya/formulae/skhd"

      # Shell & plugin managers
      "zinit"

      # Terminal & tmux utilities
      "gitmux"
      "morantron/tmux-fingers/tmux-fingers"
      "sesh"

      # macOS utilities
      "mailsy"
      "mas"
      "pngpaste"
      "spicetify-cli"
      "switchaudio-osx"
      "usage"

      # Development tools
      "pulumi/tap/pulumi"
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
      "kitty"
      "wezterm"

      # Productivity
      "bitwarden"
      "obsidian"
      "raycast"
      "whimsical"

      # File Management
      "marta"

      # Window Management & Navigation
      "nikitabobko/tap/aerospace"
      "homerow"
      "karabiner-elements"
      "mouseless"

      # System Utilities
      "aldente"
      "appcleaner"
      "betterdisplay"
      "flameshot"
      "localsend"

      # Input Devices
      "logi-options+"

      # Media
      "spotify"
      "vlc"

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
