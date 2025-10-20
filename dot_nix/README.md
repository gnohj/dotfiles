# Nix Configuration

Cross-platform Nix configuration for macOS (nix-darwin) and future Linux (Arch/Ubuntu with Nix package manager).

## Important: What is nix-darwin?

**nix-darwin is NOT a replacement for macOS.** It's a declarative package and
settings manager that runs ON TOP of macOS.

- **NixOS**: Full Linux OS replacement (like Arch/Ubuntu), controls bootloader to packages
- **nix-darwin**: Package/settings manager on top of macOS (what you're using)
- **Nix on Arch/Ubuntu**: Package manager on top of existing Linux distro (future plan)

### What nix-darwin Controls

✅ System packages (via Nix) ✅ Homebrew packages/casks (declaratively) ✅ macOS
system settings (`defaults write` equivalents) ✅ LaunchDaemons/LaunchAgents

### What nix-darwin Does NOT Control

❌ macOS kernel ❌ macOS bootloader ❌ macOS filesystem ❌ Core macOS components

**You must install macOS first, then install nix-darwin on top.**

## Structure

```bash
~/.nix/
├── flake.nix                    # Main entry point
├── nix-darwin/                  # macOS configuration
│   ├── darwin/
│   │   └── default.nix          # macOS main configuration
│   └── modules/
│       ├── system-settings.nix  # macOS system preferences (Dock, Finder, etc.)
│       ├── homebrew.nix         # Homebrew packages/casks
│       └── packages.nix         # macOS-specific packages (if any)
├── nix-linux/                   # Future: Nix on Arch/Ubuntu (NOT NixOS)
│   └── home.nix                 # Using home-manager for packages
└── common/                      # Shared packages for all platforms
    └── packages.nix             # CLI tools (bat, fzf, ripgrep, etc.)
```

## Usage

### Initial Setup

Run the system-setup.sh script from the root of the dotfiles repo:

```bash
bash ~/.local/share/chezmoi/system-setup.sh
```

### Apply Configuration

```bash
darwin-rebuild switch --flake ~/.nix
```

### Update Packages

```bash
# Update flake inputs (get latest package versions)
nix flake update ~/.nix

# Rebuild with new packages
darwin-rebuild switch --flake ~/.nix
```

### Rollback

```bash
# List previous generations
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild switch --rollback
```

## Configuration Philosophy

### Three-Layer Package Management

1. **Nix** (`common/packages.nix` + nix-darwin modules)
   - ALL CLI utilities (bat, fzf, ripgrep, tmux, etc.)
   - Cross-platform tools shared with future Linux
   - Homebrew packages/casks (managed declaratively)
   - macOS system settings

2. **Chezmoi** (dotfiles)
   - ALL config files (~/.config/\*)
   - Shell configs (.zshrc, etc.)
   - User LaunchAgents
   - Application configs

3. **Mise** (`~/.config/mise/config.toml`)
   - Language runtimes ONLY (node, lua, python, go, rust)
   - Per-project tool versions

### Why This Architecture?

**Benefits:**

- **Declarative** - Entire system defined in code
- **Reproducible** - Same config = same system state
- **Versionable** - Track all changes in git
- **Rollback** - Undo breaking changes with one command
- **Cross-platform** - Share CLI tools between macOS and future Linux

**Clear Separation:**

- nix-darwin = System layer (packages, settings, services)
- chezmoi = Configuration layer (dotfiles only)
- mise = Language layer (runtimes only)

## Tips

### Test Individual Settings

Edit `modules/system-settings.nix` to uncomment one setting at a time:

```nix
system.defaults.dock = {
  autohide = true; # Start with just this
};
```

Then apply:

```bash
darwin-rebuild switch --flake ~/.nix
```

### Check What Changed

```bash
# See what will change (dry run)
darwin-rebuild build --flake ~/.nix

# Check current generation
darwin-rebuild --list-generations
```

### Clean Up

```bash
# Remove old generations
nix-collect-garbage -d

# Optimize nix store
nix-store --optimize
```

## Resources

- [Nix-Darwin Manual](https://daiderd.com/nix-darwin/manual/index.html)
- [Nix Package Search](https://search.nixos.org/packages)
- [macOS Defaults Reference](https://macos-defaults.com/)
