{ config, pkgs, lib, ... }:

{
  # Cross-platform CLI utilities and tools
  # Per migration plan: ALL CLI tools from mise → Nix
  # mise will ONLY contain language runtimes (node, lua, python, etc.)

  environment.systemPackages = with pkgs; [
    # Core development tools
    neovim
    chezmoi
    mise       # Language runtime manager

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

    # Terminal & Shell
    tmux       # Terminal multiplexer
    starship   # Shell prompt
    atuin      # Shell history

    # AWS & Cloud
    awscli2    # AWS CLI
    saml2aws   # AWS SAML auth

    # System utilities
    direnv     # Directory-based env vars
    duf        # Better df
    fastfetch  # System info
    xh         # Better httpie

    # Formatters
    stylua     # Lua formatter

    # Image processing for terminal
    imagemagick
  ];

  # Note: Migration strategy (see ~/.config/nix-darwin-migration-plan.md)
  # 1. Nix → System packages, CLI tools, macOS settings
  # 2. Chezmoi → Dotfiles only (~/.config/*)
  # 3. Mise → Language runtimes ONLY (node, lua, python, go, rust, etc.)
}
