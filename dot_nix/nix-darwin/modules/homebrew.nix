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
      # AI Tools — claude-code/codex/gemini/pi/rtk moved to mise (shared, both OSes).
      # opencode stays: its own installer (~/.opencode/bin) shadows this, and the
      # anomalyco vs sst forks may differ — left unmerged on purpose.
      "anomalyco/tap/opencode"

      # System services & window management
      "FelixKratz/formulae/borders"
      "FelixKratz/formulae/sketchybar"
      "kanata"
      "koekeishiya/formulae/skhd"

      # Note: Lua packages (cjson, luaposix) now managed by Nix in packages.nix

      # Shell & plugin managers
      "zinit"
      "atuin" # shell history — 18.17+ needs rustc 1.96.1, newer than nixpkgs

      # Terminal & tmux utilities
      # gitmux, sesh, television → moved to Nix (dot_nix/common/package-list.nix,
      # shared cross-platform). atuin stays on brew (aarch64 rustc lag).
      "morantron/tmux-fingers/tmux-fingers"
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
      "hunk" # review-first terminal diff viewer (gh-dash PR review)
    ];

    # GUI applications (casks)
    casks = [
      # AI Tools — claude-code CLI moved to mise (npm:@anthropic-ai/claude-code, both OSes).
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
      # karabiner-elements removed: kanata is the remapper, and KE ships a
      # VirtualHIDDevice driver (16.1.0 → 8.0.0) that's incompatible with kanata
      # (needs v6.2.0), plus its own grabber conflicts with kanata for the keyboard.
      # The standalone Karabiner-DriverKit-VirtualHIDDevice v6.2.0 .pkg is installed
      # manually (not brew-managed) so it stays pinned.
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
      "tailscale-app"

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
