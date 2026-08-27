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
    # Security tools (macOS-specific)
    pinentry_mac  # Password entry dialog for rbw/GPG on macOS

    # Sketchybar bluetooth widget: system_profiler covers reads, blueutil is the only write path
    blueutil

    # Lua environment for sketchybar AeroSpaceLua integration
    # Includes lua-cjson and luaposix (with broken flag overridden)
    # This enables direct socket communication with AeroSpace to prevent freezing
    sketchybarLua
  ];

  # systemPackages fonts are invisible to GUI apps; fonts.packages installs into /Library/Fonts.
  fonts.packages = with pkgs; [
    nerd-fonts.hasklug        # Ghostty/Kitty primary (Hasklig Nerd Font)
    nerd-fonts.roboto-mono    # Ghostty alternate
    nerd-fonts.space-mono     # Sketchybar
    nerd-fonts.meslo-lg       # Sketchybar errors popup header (MesloLGM)
    nerd-fonts.jetbrains-mono # Ghostty alternate option
  ];

  # Where everything else lives:
  # - Cross-platform CLI core in common/packages.nix (shared with the Linux VPS)
  # - Homebrew formulae/casks in homebrew.nix
  # - Language runtimes + fast-moving CLIs in mise (~/.config/mise/config.toml)
}
