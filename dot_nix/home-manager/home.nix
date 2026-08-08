{ pkgs, lib, ... }:

# Linux VPS user environment. Deliberately PACKAGES-ONLY — dotfiles stay in
# chezmoi, language runtimes and fast-moving CLIs stay in mise. This is the
# Linux counterpart to nix-darwin's environment.systemPackages, sharing
# common/package-list.nix so the box and the Mac resolve identical binaries
# from one flake.lock.
#
# Apply:  home-manager switch --flake ~/.local/share/chezmoi/dot_nix#gnohj-linux-x86_64
{
  home.username = "gnohj";
  home.homeDirectory = "/home/gnohj";
  home.stateVersion = "25.05";

  home.packages = import ../common/package-list.nix { inherit pkgs lib; };

  programs.home-manager.enable = true;

  # HM can't import nixpkgs' now-curried systemd service.nix; drop once HM catches up.
  manual.manpages.enable = false;
}
