# Nix Configuration

Cross-platform Nix setup that pulls one shared CLI toolchain (`common/package-list.nix`) through a single `flake.lock`, so macOS and the Linux VPS resolve identical binaries.

Nix owns the system layer and every CLI tool, chezmoi owns the dotfiles, and mise owns the language runtimes.

## Supports

- macOS via **nix-darwin** (`macbook_silicon`): system packages, Homebrew casks/packages, macOS settings, and launchd services.
- Linux via **home-manager** (`gnohj-linux-x86_64`): the shared CLI toolchain into the user profile.

## Apply

```
darwin-rebuild switch --flake ~/.nix#macbook_silicon        # macOS
home-manager switch --flake ~/.nix#gnohj-linux-x86_64       # Linux
```

The `up` shell command wraps this per-OS (flake update, rebuild, chezmoi apply, and more).
