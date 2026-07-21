{ config, pkgs, lib, ... }:

{
  # macOS (nix-darwin) consumer of the shared CLI toolchain. The package list
  # itself lives in ./package-list.nix so the Linux VPS (home-manager) pulls the
  # exact same set from one flake.lock. mise owns language runtimes only; the
  # nix-darwin Homebrew module owns macOS-specific apps & services.
  environment.systemPackages = import ./package-list.nix { inherit pkgs lib; };
}
