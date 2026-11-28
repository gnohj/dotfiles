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
      "blacktop/tap"
      "FelixKratz/formulae"
      "oven-sh/bun"
      "fastly/tap"
      "pulumi/tap"
      "rjyo/moshi"
      "sst/tap"
      "koekeishiya/formulae"
      "kunchenguid/tap"
      "tonisives/tap"
      "vjeantet/tap"
      "acsandmann/tap"
      "infinitary-labs/tap"
    ];

    # CLI packages (formulae)
    brews = [
      # AI Tools — claude-code/codex/gemini/pi/rtk moved to mise (shared, both OSes).
      # From the tap, not the curl|sh installer, which drops it in chezmoi-owned ~/.local/bin.
      "rjyo/moshi/moshi-hook"

      # System services & window management
      "FelixKratz/formulae/borders"
      "media-control" # now-playing bridge for the Spotify PWA (no AppleScript dictionary)
      # sketchybar: built from the latest upstream release plus local patches by ~/.local/bin/sketchybar-update
      "blacktop/tap/lporg" # save/restore the Launchpad grid; a cask churn wipes it otherwise
      "kanata"
      "koekeishiya/formulae/skhd"
      "acsandmann/tap/rift" # tiling window manager

      # Note: Lua packages (cjson) now managed by Nix in packages.nix

      # Shell & plugin managers
      "zinit"
      "atuin" # shell history — 18.17+ needs rustc 1.96.1, newer than nixpkgs

      # macOS utilities
      "terminal-notifier"
      "clippy"
      "mailsy"
      "mas"
      "pngpaste"
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
      # Moshi Desktop has no cask; run_onchange_after_install-moshi-desktop.sh pulls the dmg.
      "claude" # Claude Desktop; the Claude Desktop launchers script needs /Applications/Claude.app
      "opensuperwhisper"

      # Browsers
      "finicky"
      "firefox"
      "google-chrome"
      "google-chrome@beta"
      "helium-browser"
      "microsoft-edge"
      "zen"

      # Development
      "android-studio"
      "docker-desktop"  # Renamed from "docker"

      # Terminals
      "ghostty"
      "kitty" # adhoc-signed Nix build fails launch constraints; use cask

      # Productivity
      "infinitary-labs/tap/infinitary"
      "bitwarden"
      "localsend"
      "tinycast@beta"
      "whimsical"

      # Window Management & Navigation
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
      "macshot"

      # Input Devices
      "logi-options+"

      # Media
      "upscayl" # AI image upscaler for sub-4K wallpapers
      "vlc"

      # VPN & Security
      "tailscale-app"

      # Fonts
      "font-sf-pro"
      "font-space-mono-nerd-font"
      "sf-symbols"
    ]
    # Personal Macs always use the gnohj account; a work laptop gets no personal VPN.
    ++ lib.optionals (config.system.primaryUser == "gnohj") [
      "private-internet-access"
    ];

    # No masApps: mas needs an App Store sign-in or darwin-rebuild fails; Xcode 497799835 and Brother 1193539993 stay manual.
  };
}
