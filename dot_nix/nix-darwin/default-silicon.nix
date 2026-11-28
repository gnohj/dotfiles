{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Common cross-platform packages
    ../common/packages.nix

    # macOS-specific modules
    ./modules/system-settings.nix
    ./modules/homebrew.nix
    ./modules/helium-pwas.nix
    ./modules/packages.nix
    ./modules/launchd-services.nix
    ./modules/wifi-ssid-sudoers.nix
    ./modules/afk-sudoers.nix
  ] ++ (if builtins.pathExists ./modules/work then [ ./modules/work ] else [ ]);

  # Determinate Nix runs its own daemon, so nix-darwin must leave the install alone there. chezmoi renders nix-install.json from the machine it applies on.
  nix =
    if (builtins.fromJSON (builtins.readFile ./nix-install.json)).determinate then
      { enable = false; }
    else {
      package = pkgs.nix;

      settings = {
        experimental-features = [ "nix-command" "flakes" ];

        # Unfree GUI apps from Homebrew casks may need nix references
        # Note: This doesn't affect Homebrew packages
      };

      optimise.automatic = true;

      # Garbage collection - keep system clean
      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        };
        options = "--delete-older-than 30d";
      };
    };

  # Allow unfree packages globally
  nixpkgs.config.allowUnfree = true;

  # Overlays
  nixpkgs.overlays = [
    (final: prev: {
      # direnv checkPhase hangs on macOS (zsh test spawns interactive shell)
      direnv = prev.direnv.overrideAttrs (old: { doCheck = false; });

      # Darwin needs Clang's Objective-C ARC support; nixpkgs pins GCC 15.
      clipboard-jh = prev.clipboard-jh.override {
        gcc15Stdenv = final.clangStdenv;
      };

      # Pin gh-dash to 4.23.2 - 4.24.x panics on terminals slow to answer OSC 11 (dlvhdr/gh-dash#876).
      # Sourced from a pinned nixpkgs input; see flake.nix nixpkgs-ghdash.
      gh-dash = inputs.nixpkgs-ghdash.legacyPackages."aarch64-darwin".gh-dash;
    })
  ];

  # Auto upgrade nix package and the daemon service
  # services.nix-daemon.enable = true;

  # Shells
  programs.zsh.enable = true;
  # zshrc owns compinit/bashcompinit/prompt; /etc/zshrc's copies ran first with a shorter fpath and rewrote .zcompdump every shell (60-800ms per pane).
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.enableBashCompletion = false;
  programs.zsh.promptInit = "";
  programs.bash.enable = true;

  # Defaults to "macbook"; another Mac names itself in ~/.config/machine/hostname, which chezmoi renders into hostname.json.
  networking.hostName = (builtins.fromJSON (builtins.readFile ./hostname.json)).name;
  networking.computerName = config.networking.hostName;

  # Platform configuration
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Primary user for user-specific settings (required for homebrew). chezmoi renders primary-user.json with the account that applied ~/.nix.
  system.primaryUser = (builtins.fromJSON (builtins.readFile ./primary-user.json)).name;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
