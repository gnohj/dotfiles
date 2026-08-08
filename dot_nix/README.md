# Nix Configuration

Cross-platform Nix setup that pulls one shared CLI toolchain (`common/package-list.nix`) through a single `flake.lock`, so macOS and the Linux VPS resolve identical binaries.

Nix owns the flake-pinned CLI core, chezmoi owns the dotfiles, and mise owns the language runtimes plus the fast-moving tools that need same-day upstream releases (the AI agents, `herdr`, `rtk`, the AXI CLIs, `no-mistakes`, `treehouse`, and the handful of binaries nixpkgs doesn't carry).
On macOS, Homebrew (via nix-darwin) owns the GUI apps and services.

One deliberate exception: `firstmate` is in neither.
It is an "agent distro" from the same author as `treehouse` and `no-mistakes`, but it ships no binary and cuts no releases - the cloned repo itself is the tool, and the agent writes its own runtime state into that checkout.
A read-only nix store path or a mise release pin cannot host it, so it is cloned to `~/Developer/firstmate` via `dot_config/repos-clone.txt` and kept current by the `update` shell function.
Launch it with `fm`.

## Supports

- macOS via **nix-darwin** (`macbook_silicon`): system packages, Homebrew casks/packages, macOS settings, and launchd services.
- Linux via **home-manager** (`gnohj-linux-x86_64`): the shared CLI toolchain into the user profile.

## Apply

```
darwin-rebuild switch --flake ~/.nix#macbook_silicon                                   # macOS
home-manager switch --flake ~/.local/share/chezmoi/dot_nix#gnohj-linux-x86_64          # Linux
```

The two flake paths differ on purpose: `.chezmoiignore` skips `.nix/` on non-darwin, so `~/.nix` exists only on the Mac and the Linux box builds straight from the chezmoi source tree (same resolution as `dot_config/zshrc/dot_zshrc`).

The `up` shell command wraps this per-OS (flake update, rebuild, chezmoi apply, and more).
