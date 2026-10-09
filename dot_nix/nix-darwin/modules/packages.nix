{ config, pkgs, lib, ... }:

let
  # Lua environment for sketchybar's config (sketchybarrc puts /run/current-system/sw/bin first)
  sketchybarLua = pkgs.lua5_3.withPackages (ps: [
    ps.cjson          # JSON encoding/decoding
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

    # Lua environment for sketchybar (lua-cjson for Rift and Spotify JSON)
    sketchybarLua
  ];

  # systemPackages fonts are invisible to GUI apps; fonts.packages installs into /Library/Fonts.
  fonts.packages = with pkgs; [
    nerd-fonts.hasklug        # Ghostty/Kitty primary (Hasklig Nerd Font)
    nerd-fonts.roboto-mono    # Ghostty alternate
    nerd-fonts.space-mono     # Sketchybar
    nerd-fonts.jetbrains-mono # Ghostty alternate option
  ];

  # A font store-hash change leaves macOS serving the old path, so every glyph boxes until fontd rescans.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    killall fontd 2>/dev/null || true
  '';

  # Where everything else lives:
  # - Cross-platform CLI core in common/packages.nix (shared with the Linux VPS)
  # - Homebrew formulae/casks in homebrew.nix
  # - Language runtimes + fast-moving CLIs in mise (~/.config/mise/config.toml)
}
