{ config, pkgs, lib, ... }:

{
  imports = [
    # Common cross-platform packages
    ../common/packages.nix

    # macOS-specific modules
    ./modules/system-settings.nix
    ./modules/homebrew.nix
    ./modules/packages.nix
    ./modules/launchd-services.nix
  ];

  # Nix package manager settings
  nix = {
    package = pkgs.nix;

    settings = {
      # Enable flakes and new nix command
      experimental-features = [ "nix-command" "flakes" ];

      # Allow unfree packages (like Obsidian, Discord, etc.)
      # This is required for many GUI apps from Homebrew casks
      # that Nix might need to reference
      # Note: This doesn't affect Homebrew packages
    };

    # Optimize storage automatically
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

  # Auto upgrade nix package and the daemon service
  # services.nix-daemon.enable = true;

  # Shells
  programs.zsh.enable = true;
  programs.bash.enable = true;

  # Set your hostname
  networking.hostName = "macbook";
  networking.computerName = "macbook";

  # Platform configuration
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Primary user for user-specific settings (required for homebrew)
  system.primaryUser = "gnohj";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
