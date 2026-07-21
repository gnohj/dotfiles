{
  description = "gnohj darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Pinned nixpkgs that still packages gh-dash 4.23.2. 4.24.x regressed with a
    # nil-pointer panic on terminals (e.g. tmux) that don't promptly answer the
    # OSC 11 background-color query — see dlvhdr/gh-dash#876. The fix is on the
    # gh-dash main branch but unreleased; drop this pin once a tagged release
    # past 4.24.1 lands in nixpkgs-unstable.
    nixpkgs-ghdash.url = "github:NixOS/nixpkgs/c92a446a730c";

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ... }: {
    # Linux VPS user env (packages only) — Determinate nix + home-manager on
    # Ubuntu, layered on the OS you install yourself. Mirror of nix-darwin.
    # Usage: home-manager switch --flake ~/.nix#gnohj-linux-x86_64
    homeConfigurations = {
      gnohj-linux-x86_64 = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          # Pin gh-dash to 4.23.2 — 4.24.x panics under tmux (dlvhdr/gh-dash#876).
          # Mirrors the overlay in nix-darwin/default-silicon.nix (x86_64-linux here).
          overlays = [
            (final: prev: {
              gh-dash = inputs.nixpkgs-ghdash.legacyPackages."x86_64-linux".gh-dash;
            })
          ];
        };
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./home-manager/home.nix ];
      };
    };

    darwinConfigurations = {
      # INFO: Main macOS machine (Apple Silicon)
      # Usage: darwin-rebuild switch --flake ~/.nix#macbook_silicon
      macbook_silicon = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          ./nix-darwin/default-silicon.nix
        ];
      };

      # TODO: Intel macOS machine
      # Usage: darwin-rebuild switch --flake ~/.nix#macbook_intel
      # macbook_intel = darwin.lib.darwinSystem {
      #   system = "x86_64-darwin";
      #   modules = [
      #     ./nix-darwin/default-intel.nix
      #   ];
      # };
    };

  };
}
