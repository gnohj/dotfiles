{ config, pkgs, lib, ... }:

{
  # Homebrew configuration - Declarative package management
  # Run: darwin-rebuild switch --flake ~/.nix

  homebrew = {
    enable = true;

    # Auto-update Homebrew and packages
    onActivation = {
      autoUpdate = false;  # Disabled for testing
      upgrade = false;     # Disabled for testing
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
      "pngpaste"
      "rbw"
      "speedtest-cli"
      "spicetify-cli"
      "switchaudio-osx"
      "thefuck"
      "usage"

      # Development tools
      "mkcert"
      "pulumi/tap/pulumi"
      "tree-sitter-cli"
      "xcodegen"

      # Additional tools
      "btop"
      "caddy"
      "tlrc"
      "w3m"
      "wordnet"
      "zx"
    ];

    # GUI applications (casks)
    casks = [
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
      "appcleaner"
      "betterdisplay"
      "flameshot"
      "istat-menus"
      "latest"
      "localsend"

      # Input Devices
      "logi-options+"

      # Media
      "spotify"
      "vlc"

      # Fonts
      "font-sf-pro"
      "font-space-mono-nerd-font"
      "sf-symbols"
    ];

    # Mac App Store apps (requires mas-cli)
    # masApps = {
    #   "Xcode" = 497799835;
    # };
  };
}
