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
      # Homebrew 5.1+ requires explicit confirmation for `bundle install --cleanup`.
      # Pass --force-cleanup so the non-interactive nix-darwin activation doesn't abort.
      extraFlags = [ "--force-cleanup" ];
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
      "vjeantet/tap"
    ];

    # CLI packages (formulae)
    brews = [
      # AI Tools
      "anomalyco/tap/opencode"
      "pi-coding-agent"
      "rtk"

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
      "television"
      "garrettkrohn/treekanga/treekanga"

      # macOS utilities
      "terminal-notifier"
      "clippy"
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
      "opensuperwhisper"

      # Browsers
      "firefox"
      "google-chrome"
      "helium-browser"
      "microsoft-edge"
      "zen"

      # Communication
      "discord"
      "microsoft-outlook"
      "microsoft-teams"
      "slack"
      "zoom"

      # Development
      "android-studio"
      "docker-desktop"  # Renamed from "docker"

      # Terminals
      "ghostty"
      "kitty" # adhoc-signed Nix build fails launch constraints; use cask

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
      "macshot"

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

    # Mac App Store apps intentionally omitted.
    # mas install requires App Store sign-in which is not available during
    # darwin-rebuild, causing the entire activation to fail if not authenticated.
    # Install manually after signing in to the App Store:
    #   mas install 497799835   # Xcode
    #   mas install 1193539993  # Brother iPrint&Scan
    #   mas install 310633997   # WhatsApp Messenger
    masApps = {};
  };
}
