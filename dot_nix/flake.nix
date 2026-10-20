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

    # Pinned nixpkgs whose sesh still builds; go-mockery 3.8.0 can't read go 1.27 export data, drop once nixpkgs bumps it.
    nixpkgs-sesh.url = "github:NixOS/nixpkgs/8edc0c72e3a38faf5434e40d1f19431125fe4b30";

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
    # Usage: home-manager switch --flake ~/.local/share/chezmoi/dot_nix#gnohj-linux-x86_64
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
              # Pin sesh until go-mockery builds under go 1.27; see flake.nix nixpkgs-sesh.
              sesh = inputs.nixpkgs-sesh.legacyPackages."x86_64-linux".sesh;
              # viceroy denies warnings and rustc 1.99 deprecated std::u32::MAX; drop once upstream builds.
              viceroy = prev.viceroy.overrideAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                  substituteInPlace src/lib.rs --replace-fail "deny(warnings)" "warn(warnings)"
                '';
              });
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
