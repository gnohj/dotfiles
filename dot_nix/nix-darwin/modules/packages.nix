{ config, pkgs, lib, ... }:

let
  # Create Lua 5.3 environment with all required packages for sketchybar AeroSpaceLua
  # Note: Using Lua 5.3 because luaposix requires lua >= 5.1, < 5.4
  sketchybarLua = pkgs.lua5_3.withPackages (ps: [
    ps.cjson          # JSON encoding/decoding
    ps.luaposix       # POSIX bindings for Unix socket communication
  ]);
in
{
  # macOS-specific Nix packages
  # Note: Cross-platform CLI tools are in ../../common/packages.nix

  environment.systemPackages = with pkgs; [
    # macOS-specific packages only
    # Most packages are in common/packages.nix for cross-platform use

    # Security tools (macOS-specific)
    pinentry_mac  # Password entry dialog for rbw/GPG on macOS

    # Lua environment for sketchybar AeroSpaceLua integration
    # Includes lua-cjson and luaposix (with broken flag overridden)
    # This enables direct socket communication with AeroSpace to prevent freezing
    sketchybarLua

    # Add other macOS-only tools here if needed:
    # - darwin-specific utilities
    # - macOS-only development tools
  ];

  # Migration Note:
  # - ALL CLI tools moved to common/packages.nix (shared with future Linux)
  # - Homebrew formulae/casks in homebrew.nix
  # - Language runtimes stay in mise (~/.config/mise/config.toml)
}
