{ pkgs, lib }:

# Single source of truth for the Nix-managed CLI toolchain, consumed by BOTH
# consumers so the Mac and the Linux VPS pull identical binaries from one
# flake.lock:
#   - nix-darwin  → common/packages.nix    (environment.systemPackages)
#   - home-manager → home-manager/home.nix (home.packages)
# Language runtimes stay in mise (~/.config/mise/config.toml); fast-moving AI
# agents stay in mise/npm for freshness. See dot_nix/README.md.

let
  no-mistakes = pkgs.callPackage ./no-mistakes.nix { inherit pkgs lib; };
  treehouse = pkgs.callPackage ./treehouse.nix { inherit pkgs lib; };
in
with pkgs;

# Cross-platform core — built on macOS and the Linux VPS alike.
[
  # Core development tools
  neovim
  chezmoi

  # CLI utilities
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
  # yazi plugins go through `ya pkg` (package.toml), NOT nix: 2+ plugins collide in buildEnv on their shared top-level main.lua.
  trash-cli  # Required by the restore plugin (recovers trashed files)
  p7zip      # 7zip for archive preview in yazi
  clipboard-jh  # ClipBoard project for yazi system-clipboard plugin

  # Data tools
  jq         # JSON processor
  yq         # Yaml processor

  # Terminal & Shell
  tmux       # Terminal multiplexer
  gitmux     # tmux git status (was Homebrew on macOS)
  sesh       # tmux session manager (was Homebrew on macOS)
  television # fuzzy finder TUI (was Homebrew on macOS)
  # starship managed by zinit (see zshrc). atuin: Homebrew on macOS (aarch64 rustc
  # lag), Nix on Linux — see the isLinux bucket below.

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

  # Image/video processing for terminal (yazi previews)
  imagemagick
  ffmpeg

  # Security & Development
  mkcert     # Local certificate tool

  # Networking & Web
  caddy      # Web server
  w3m        # Text web browser
  speedtest-cli # Speed test

  # CLI enhancements
  tlrc       # tldr client
  tree-sitter # Tree-sitter CLI
  figlet     # ASCII art text banners
  d2         # Diagram-as-code (sb-workflow / skills-workflow renders)

  # Built from source (not in nixpkgs)
  no-mistakes # Dev workflow guard
  treehouse   # Pooled detached git worktrees for PR review
]

# macOS-only — GUI/hardware-bound or sourced elsewhere on Linux.
++ lib.optionals pkgs.stdenv.isDarwin [
  herdr      # AI-agent multiplexer — trialing locally on the Mac
  rbw        # Bitwarden CLI — Linux VPS uses scoped tokens (option B), not rbw
  android-tools  # adb/fastboot for a USB Android phone — pointless headless
  scrcpy         # Mirror a USB Android phone — pointless headless

  # Fonts render on the SSH client (the Mac), never on a headless server.
  nerd-fonts.hasklug       # Ghostty primary (Hasklig Nerd Font)
  nerd-fonts.roboto-mono   # Ghostty alternate
  nerd-fonts.space-mono    # Sketchybar
  nerd-fonts.meslo-lg      # Sketchybar mic widget (MesloLGM)
  nerd-fonts.jetbrains-mono # Ghostty alternate option
]

# Linux-only — on macOS atuin comes from Homebrew because aarch64-darwin needs a
# newer rustc than nixpkgs ships (nix can only build 18.16.1 there); x86_64-linux
# builds current atuin straight from the binary cache. The rest of the old Homebrew
# CLIs (gitmux/sesh/television) are shared-core above now — one source, both OSes.
++ lib.optionals pkgs.stdenv.isLinux [
  atuin       # shell history
]
