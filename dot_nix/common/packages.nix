{ config, pkgs, lib, ... }:

let
  no-mistakes = pkgs.callPackage ./no-mistakes.nix { inherit pkgs lib; };
  treehouse = pkgs.callPackage ./treehouse.nix { inherit pkgs lib; };
in
{
  # Cross-platform CLI utilities and tools
  # Per migration plan: ALL CLI tools from mise → Nix
  # mise itself is installed via its official installer (curl https://mise.run | sh)
  # because nixpkgs binary cache lags behind upstream mise releases on
  # aarch64-darwin and forces source rebuilds during darwin-rebuild.
  # mise still owns language runtimes only (node, lua, python, etc.)

  environment.systemPackages = with pkgs; [
    # Core development tools
    neovim
    chezmoi

    # CLI utilities (from mise migration)
    bat        # Better cat
    eza        # Better ls
    fd         # Better find
    fzf        # Fuzzy finder
    ripgrep    # Better grep
    delta      # Git diff viewer
    zoxide     # Better cd

    # Git tools
    gh         # GitHub CLI
    gh-dash    # GitHub CLI dashboard for PRs and issues
    gh-enhance # PR checks TUI (companion to gh-dash) — runs as `gh enhance`
    lazygit    # Git TUI
    lazydocker # Docker TUI

    # File management
    yazi       # Terminal file manager
    yaziPlugins.restore  # Undo/recover trashed files
    yaziPlugins.git      # Show git status in file list
    trash-cli  # Required for restore plugin
    p7zip      # 7zip for archive preview in yazi
    clipboard-jh  # ClipBoard project for yazi system-clipboard plugin

    # Data tools
    jq         # JSON processor
    yq         # Yaml processor

    # Terminal & Shell
    # kitty moved to Homebrew cask — Nix builds it adhoc-signed, which fails
    # macOS launch constraints (CODESIGNING 4) when launched via `open`.
    tmux       # Terminal multiplexer
    herdr      # AI-agent multiplexer (tmux-for-agents) — trialing locally
    # starship managed by zinit (see zshrc)
    # atuin — moved to Homebrew (nix-darwin/modules/homebrew.nix). 18.17.0+
    # requires rustc 1.96.1, newer than any current nixpkgs (still 1.95.0),
    # so nix can only build 18.16.1. Homebrew ships a prebuilt 18.17 bottle.
    # Move back to Nix once nixpkgs bumps rustc and packages 18.17.

    # AWS & Cloud
    awscli2    # AWS CLI
    saml2aws   # AWS SAML auth

    # System utilities
    duf        # Better df
    fastfetch  # System info
    xh         # Better httpie
    btop       # System monitor

    # Formatters
    stylua     # Lua formatter

    # Image processing for terminal
    imagemagick
    ffmpeg     # yazi video preloader (.mov/.mp4 thumbnails) — without it,
               # video preloader tasks never finish ("unfinished tasks" on quit)

    # Fonts (new nerd-fonts namespace)
    nerd-fonts.hasklug       # Ghostty primary (Hasklig Nerd Font)
    nerd-fonts.roboto-mono   # Ghostty alternate
    nerd-fonts.space-mono    # Sketchybar
    nerd-fonts.meslo-lg      # Sketchybar mic widget (MesloLGM)
    nerd-fonts.jetbrains-mono # Ghostty alternate option

    # Security & Development
    rbw        # Bitwarden CLI
    mkcert     # Local certificate tool
    android-tools  # adb/fastboot for USB-debugging a physical Android phone
    scrcpy         # Mirror a USB-connected Android phone to a Mac window

    # Networking & Web
    caddy      # Web server
    w3m        # Text web browser
    speedtest-cli # Speed test

    # CLI enhancements
    tlrc       # tldr client
    tree-sitter # Tree-sitter CLI
    figlet     # ASCII art text banners
    d2         # Diagram-as-code (sb-workflow / skills-workflow renders)

    # Dev workflow gate (not in nixpkgs — built from source)
    no-mistakes

    # Pooled detached git worktrees for PR review (not in nixpkgs — built from source)
    treehouse
  ];

}
