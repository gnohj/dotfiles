{ config, pkgs, lib, ... }:

{
  # Cross-platform CLI utilities and tools
  # Per migration plan: ALL CLI tools from mise → Nix
  # mise will ONLY contain language runtimes (node, lua, python, etc.)

  environment.systemPackages = with pkgs; [
    # Core development tools
    neovim
    chezmoi
    mise

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

    # AI Tools
    opencode

    # Terminal & Shell
    alacritty  # GPU-accelerated terminal
    kitty      # GPU-accelerated terminal
    tmux       # Terminal multiplexer
    starship   # Shell prompt
    atuin      # Shell history

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

    # Fonts (new nerd-fonts namespace)
    nerd-fonts.hasklug       # Ghostty primary (Hasklig Nerd Font)
    nerd-fonts.roboto-mono   # Ghostty alternate
    nerd-fonts.space-mono    # Sketchybar
    nerd-fonts.meslo-lg      # Sketchybar mic widget (MesloLGM)
    nerd-fonts.jetbrains-mono # Ghostty alternate option

    # Security & Development
    rbw        # Bitwarden CLI
    mkcert     # Local certificate tool

    # Networking & Web
    caddy      # Web server
    w3m        # Text web browser
    speedtest-cli # Speed test

    # CLI enhancements
    tlrc       # tldr client
    tree-sitter # Tree-sitter CLI
  ];

}
