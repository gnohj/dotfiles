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
    lazygit    # Git TUI
    lazydocker # Docker TUI

    # Data tools
    jq         # JSON processor

    # AI Tools
    opencode

    # Terminal & Shell
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
    nerd-fonts.roboto-mono   # WezTerm, Ghostty alternate
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
