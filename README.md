# Dotfiles

My personal dotfiles for macOS.

<img width="2557" height="1440" alt="ghostty-current" src="https://github.com/user-attachments/assets/dbe927ed-fda1-4d92-958a-d92d1220b9ee" />

## Key Tools & Configurations

- **System Management**: [Nix-Darwin](https://github.com/LnL7/nix-darwin) (declarative macOS settings + packages)
- **Package Management**: [Homebrew](https://brew.sh/) (managed via Nix-Darwin)
- **Dotfiles Management**: [Chezmoi](https://www.chezmoi.io/)
- **Secrets Management**: [Bitwarden](https://bitwarden.com/) via [rbw](https://github.com/doy/rbw) (hash-based caching)
- **Language/Environment Management**: [Mise](https://mise.jdx.dev/)
- **Window Management**: [Aerospace](https://github.com/nikitabobko/AeroSpace) (tiling WM), [JankyBorders](https://github.com/FelixKratz/JankyBorders) (window borders), [Sketchybar](https://github.com/FelixKratz/SketchyBar) (status bar)
- **File Manager**: [Yazi](https://yazi-rs.github.io/)
- **Launcher**: [Raycast](https://www.raycast.com/)
- **Terminal**: [Ghostty](https://github.com/ghostty-org/ghostty) (primary), [Kitty](https://github.com/kovidgoyal/kitty) (kept at config parity)
- **Shell**: Zsh with [Starship](https://starship.rs/) prompt (transient), [Atuin](https://github.com/atuinsh/atuin) (shell history)
- **Editor**: [Neovim](https://neovim.io/) (LazyVim)
- **Multiplexer**: [Tmux](https://github.com/tmux/tmux) with [Sesh](https://github.com/joshmedeski/sesh) session management
- **Version Control**: Git worktrees with [Treekanga](https://github.com/garrettkrohn/treekanga) CLI, [Delta](https://github.com/dandavison/delta) pager, [Lazygit](https://github.com/jesseduffield/lazygit) TUI
- **Keyboard**: [Kanata](https://github.com/jtroo/kanata) (laptop remapping), custom zmk layouts for [Glove80](https://github.com/gnohj/glove80) & [Corne](https://github.com/gnohj/hypersonic-corne) (external keyboards)

## Bootstrap New Mac (Apple Silicon)

<details>
<summary>Click to expand bootstrap instructions</summary>

### Step 1: System setup (Nix + nix-darwin)

Installs Nix package manager, nix-darwin system configuration, and Homebrew packages:

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/mac-setup.sh | bash
```

This will:

- Install Nix package manager (Determinate Systems installer)
- Clone dotfiles repository via Chezmoi
- Install nix-darwin for declarative macOS configuration
- Install all packages defined in `~/.nix/` (Nix packages + Homebrew apps)

**Note:** You'll be prompted for your password once at the start for sudo access.

### Step 2: User setup (dotfiles + development tools)

Applies dotfiles and installs language runtimes via mise:

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/user-setup.sh | bash -s -- your_bitwarden_email@example.com
```

This will:

- Fetch GH SSH key from Bitwarden (requires master password)
- Apply all dotfiles via Chezmoi (`~/.config/`, `~/.zshrc`, etc.)
- Install language runtimes via mise (Node, Python, Go, Rust, etc.)
- Set up environment secrets from Bitwarden (API keys, tokens)
- Set up shell configuration

</details>

## Bootstrap New Linux VPS (Ubuntu, amd64)

<details>
<summary>Click to expand bootstrap instructions</summary>

The Linux counterpart to the macOS flow. There is no Nix layer on Linux, so a single script does both the system prep and the user/toolchain setup.

### One command (run as root on a fresh box)

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-setup.sh | bash
```

Run it inside `tmux`/`mosh` so a dropped SSH link doesn't kill the long cargo builds. Variants:

```bash
# custom username (default: gnohj)
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-setup.sh | bash -s -- myuser

# bring Tailscale up unattended with an auth key
TS_AUTHKEY=tskey-... bash -c "$(curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-setup.sh)"
```

This will:

- **Root phase:** create the user, copy your SSH key, set passwordless sudo, harden sshd (key-only, no root login, validated with `sshd -t`), install Tailscale, wait out cloud-init.
- **User phase:** install chezmoi + `chezmoi init --apply` → run the Linux toolchain bootstrap (mise runtimes, apt packages, sysstat/atop monitoring, agent CLIs, custom tools).

Idempotent - safe to re-run. It prints the interactive remainder at the end.

### Remaining manual steps (interactive - can't be piped)

- **Tailscale onto the tailnet:** `sudo tailscale up --ssh`, then enable MagicDNS + HTTPS in the admin console (skip if you passed `TS_AUTHKEY`).
- **GitHub + agents:** `gh auth login`, then `claude` / `codex` / `gemini` once each for OAuth.
- **Secrets:** put ONLY the tokens this box needs into `~/.zsh_gnohj_env.local` (auto-sourced; var names in `~/.config/bitwarden/vars.txt`). Your Bitwarden master password never touches the VPS.
- **tmux-dash** (private repo, build from source) and **agent-tmux-web** (audit the pinned SHA first).

### Security model (differs from the Mac on purpose)

- **No SSH identity key on the box.** Use agent forwarding (`ForwardAgent yes` in the `dev-box` SSH block) + `gh auth login` - your primary `~/.ssh/id_ed25519` never lands on a cloud machine.
- **No full Bitwarden unlock on the box.** Only the minimum scoped tokens go into `~/.zsh_gnohj_env.local`; a box compromise costs a token rotation, not your whole vault.

Full detail, hardening, and the agent-tmux-web audit steps: **`MANUAL_VPS_SETUP.md`**.

</details>

## Update Existing Mac (Apple Silicon)

<details>
<summary>Click to expand update instructions</summary>

### 1. Nix-Darwin (System Management)

#### Understanding Package Pinning

This setup uses a **hybrid approach** for reproducibility:

- **Nix packages** (CLI dev tools): Pinned via `flake.lock`
  - ✅ Reproducible across machines and time
  - ✅ Same versions until you explicitly update

- **Homebrew packages** (macOS apps + utilities): Floating versions
  - ⚠️ Gets latest from Homebrew on install/update
  - ⚠️ Not reproducible, but always up-to-date

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

**Refresh secrets from Bitwarden:**

Secrets are automatically refreshed when the secret list changes. To force a refresh after changing a password value:

```bash
rbw sync && chezmoi apply --force
```

### 3. Mise (Language/Environment Management)

**List outdated languages:**

```bash
mise outdated
```

**Install/update all languages from config:**

```bash
mise install
```

**Upgrade a specific language runtime:**

```bash
mise upgrade node@20.2.0
mise upgrade python
```

**Upgrade all language runtimes to latest versions:**

```bash
mise upgrade
```

### 4. Mac App Store (mas)

**List outdated apps:**

```bash
mas outdated
```

**Upgrade all App Store apps:**

```bash
mas upgrade
```

**Upgrade a specific app:**

```bash
mas upgrade <app-id>
```

</details>

## Update Existing Linux VPS (Ubuntu, amd64)

<details>
<summary>Click to expand update instructions</summary>

There is no Nix, Homebrew, or App Store layer on the VPS - the update surface is `apt` + `chezmoi` + `mise`, plus the tools built from source.

### 1. System packages (apt)

The base packages (tmux, mosh, python3, monitoring, etc.) come from apt:

```bash
sudo apt-get update && sudo apt-get upgrade -y

# clean up
sudo apt-get autoremove -y && sudo apt-get clean
```

### 2. Chezmoi (Dotfiles Management)

**Apply latest dotfiles:**

```bash
chezmoi apply
```

**Update from remote and apply** (re-runs the toolchain bootstrap when it changes):

```bash
chezmoi update
```

Secrets on the VPS are NOT managed by `rbw`/Bitwarden - they live in `~/.zsh_gnohj_env.local` (see `MANUAL_VPS_SETUP.md`). Edit that file directly to rotate a token.

### 3. Mise (Language/Environment Management)

Same as the Mac:

```bash
mise outdated        # list outdated runtimes/CLIs
mise install         # install/update everything from config
mise upgrade         # upgrade all to latest
mise upgrade node    # upgrade a specific runtime
```

### 4. Tailscale + from-source tools

**Tailscale** self-updates via its apt repo (installed by the bootstrap), so it rides along with `apt-get upgrade` above. To force it:

```bash
sudo tailscale update
```

**herdr:**

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

**tmux-dash** (private repo, built with cargo):

```bash
cd ~/tmux-dash && git pull && cargo install --path .
```

</details>
