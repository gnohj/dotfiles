{ config, pkgs, lib, ... }:

{
  # macOS-specific Nix packages
  # Note: Cross-platform CLI tools are in ../../common/packages.nix

  environment.systemPackages = with pkgs; [
    # macOS-specific packages only
    # Most packages are in common/packages.nix for cross-platform use

    # Add macOS-only tools here if needed:
    # - darwin-specific utilities
    # - macOS-only development tools
  ];

  # Migration Note:
  # - ALL CLI tools moved to common/packages.nix (shared with future Linux)
  # - Homebrew formulae/casks in homebrew.nix
  # - Language runtimes stay in mise (~/.config/mise/config.toml)
}
