# Dotfiles

My personal dotfiles for macOS (Apple Silicon), managed with Chezmoi.

This setup prioritizes:

- **Reproducibility**: Bootstrap a new Mac with two commands
  - Nix for system packages and macOS settings
  - Chezmoi for dotfile management
  - Mise for language runtimes
- **Speed**: Optimized shell and terminal configs
- **Aesthetic**: Unified colorscheme across all tools (dynamic theme switching)
- **Productivity**: Heavily customized Neovim, Tmux, and keyboard-driven
  workflow

## Key Tools & Configurations

- **System Management**: [Nix-Darwin](https://github.com/LnL7/nix-darwin)
- **Dotfiles Management**: [Chezmoi](https://www.chezmoi.io/)
- **Language/Environment Management**: [Mise](https://mise.jdx.dev/)
- **Package Management**: [Homebrew](https://brew.sh/) (managed via Nix-Darwin)
- **Window Management**: [Aerospace](https://github.com/nikitabobko/AeroSpace)
  (tiling WM), [Sketchybar](https://github.com/FelixKratz/SketchyBar) (status
  bar)
- **Terminal**: [Ghostty](https://github.com/ghostty-org/ghostty) (with custom
  shaders)
- **Shell**: Zsh with [Starship](https://starship.rs/) prompt (transient),
  [Atuin](https://github.com/atuinsh/atuin) (shell history)
- **Editor**: [Neovim](https://neovim.io/) (LazyVim-based, heavily customized)
- **Multiplexer**: [Tmux](https://github.com/tmux/tmux) with
  [Sesh](https://github.com/joshmedeski/sesh) session management
- **Version Control**: Git with [Delta](https://github.com/dandavison/delta)
  pager, [Lazygit](https://github.com/jesseduffield/lazygit) TUI
- **Keyboard**: [Kanata](https://github.com/jtroo/kanata) (key remapping on
  laptop), custom zmk layouts for
  [Glove80](https://my.glove80.com/?ref=arslan.io#/layout/user/3fbe1c75-ac0e-4967-88d1-fe626c3ab3ff)
  & [Corne](https://github.com/gnohj/hypersonic-corne) (external keyboards)

## Bootstrap New Mac (Apple Silicon)

### Step 1: System setup (Nix + nix-darwin)

Installs Nix package manager, nix-darwin system configuration, and Homebrew
packages:

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/system-setup.sh | bash
```

This will:

- Install Nix package manager (Determinate Systems installer)
- Clone dotfiles repository via Chezmoi
- Install nix-darwin for declarative macOS configuration
- Install all packages defined in `~/.nix/` (Nix packages + Homebrew apps)

**Note:** You'll be prompted for your password once at the start for sudo
access.

### Step 2: User setup (dotfiles + development tools)

Applies dotfiles and installs language runtimes via mise:

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/user-setup.sh | bash
```

This will:

- Apply all dotfiles via Chezmoi (`~/.config/`, `~/.zshrc`, etc.)
- Install language runtimes via mise (Node, Python, Go, Rust, etc.)
- Set up shell configuration

## Update Existing Mac (Apple Silicon)

### 1. Nix-Darwin (System Management)

#### Understanding Package Pinning

This setup uses a **hybrid approach** for reproducibility:

- **Nix packages** (CLI dev tools): Pinned via `flake.lock`
  - ✅ Reproducible across machines and time
  - ✅ Same versions until you explicitly update
  - Examples: nvim, tmux, fzf, bat, ripgrep

- **Homebrew packages** (macOS apps + utilities): Floating versions
  - ⚠️ Gets latest from Homebrew on install/update
  - ⚠️ Not reproducible, but always up-to-date
  - Examples: ghostty, brave-browser, borders, sketchybar

#### Rebuild without updating packages

Uses existing pinned versions from `flake.lock`:

```bash
darwin-rebuild switch --flake ~/.nix
```

#### Update Nix packages to latest

Updates `flake.lock` to newest nixpkgs snapshot:

```bash
# Update all flake inputs (nixpkgs + nix-darwin)
nix flake update ~/.nix
darwin-rebuild switch --flake ~/.nix

# Or update only nixpkgs
nix flake update ~/.nix nixpkgs
darwin-rebuild switch --flake ~/.nix
```

#### Update Homebrew packages

Currently `onActivation.upgrade = false`, so manual updates:

```bash
# Update specific package
brew upgrade ghostty
brew upgrade --cask brave-browser

# Update all packages
brew upgrade
brew upgrade --cask
```

**Clean up old generations:**

```bash
nix-collect-garbage -d
```

### 2. Chezmoi (Dotfiles Management)

**Apply latest dotfiles:**

```bash
chezmoi apply
```

**Update from remote and apply:**

```bash
chezmoi update
```

### 3. Mise (Language/Environment Management)

**Install/update all tools from config:**

```bash
mise install
```

**Update mise itself:**

```bash
mise self-update
```

**Upgrade all tools to latest versions:**

```bash
mise upgrade
```
