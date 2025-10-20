{
  description = "gnohj darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darwin, ... }: {
    darwinConfigurations = {
      # INFO: Main macOS machine (Apple Silicon)
      # Usage: darwin-rebuild switch --flake ~/.nix#macbook_silicon
      macbook_silicon = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
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
