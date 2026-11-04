{ config, pkgs, lib, inputs, ... }:

let
  # macOS-only (kqueue); runtime/ ships its 16-colour colorscheme and lualine theme.
  neorex = pkgs.stdenv.mkDerivation {
    pname = "neorex";
    version = "0-unstable-${inputs.neorex.shortRev}";
    src = inputs.neorex;
    # Split-pane helper leads the tty's foreground group, else Rex sees only the root login.
    patches = [ ./neorex-pane-foreground.patch ];
    nativeBuildInputs = [ pkgs.zig_0_17.hook ];
    postInstall = ''
      mkdir -p $out/share/neorex $out/libexec/neorex
      cp -r runtime $out/share/neorex/
      # Rex picks the nvim icon by binary name; splits re-exec the resolved path
      mv $out/bin/neorex $out/libexec/neorex/nvim
      ln -s ../libexec/neorex/nvim $out/bin/neorex
    '';
  };

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

    # Rex-native Neovim frontend; launched by the `nvim` zsh function in bare Rex panes only
    neorex
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
