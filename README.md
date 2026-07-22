# Dotfiles

My personal dotfiles for macOS and Linux.

<img width="2557" height="1440" alt="ghostty-current" src="https://github.com/user-attachments/assets/dbe927ed-fda1-4d92-958a-d92d1220b9ee" />

## Key Tools & Configurations

macOS is the daily driver; a headless Linux VPS (Ubuntu) runs the same shell/editor/CLI core as a remote dev box over Tailscale.

### Shared core (macOS + Linux)

- **Dotfiles Management**: [Chezmoi](https://www.chezmoi.io/)
- **Language/Environment Management**: [Mise](https://mise.jdx.dev/)
- **Shell**: Zsh with [Starship](https://starship.rs/) prompt (transient), [Atuin](https://github.com/atuinsh/atuin) (shell history)
- **Editor**: [Neovim](https://neovim.io/) (LazyVim)
- **Multiplexer**: [Tmux](https://github.com/tmux/tmux) with [Sesh](https://github.com/joshmedeski/sesh) session management
- **File Manager**: [Yazi](https://yazi-rs.github.io/)
- **Version Control**: Git worktrees with [Treekanga](https://github.com/garrettkrohn/treekanga) CLI, [Delta](https://github.com/dandavison/delta) pager, [Lazygit](https://github.com/jesseduffield/lazygit) TUI
- **System Monitor**: [btop](https://github.com/aristocratos/btop) (interactive; each platform also runs a lightweight background recorder - see below)

### macOS desktop

- **System Management**: [Nix-Darwin](https://github.com/LnL7/nix-darwin) (declarative macOS settings + packages)
- **Package Management**: [Homebrew](https://brew.sh/) (managed via Nix-Darwin)
- **Secrets Management**: [Bitwarden](https://bitwarden.com/) via [rbw](https://github.com/doy/rbw) (hash-based caching)
- **Window Management**: [Aerospace](https://github.com/nikitabobko/AeroSpace) (tiling WM), [JankyBorders](https://github.com/FelixKratz/JankyBorders) (window borders), [Sketchybar](https://github.com/FelixKratz/SketchyBar) (status bar)
- **Launcher**: [Raycast](https://www.raycast.com/)
- **Terminal**: [Ghostty](https://github.com/ghostty-org/ghostty) (primary), [Kitty](https://github.com/kovidgoyal/kitty) (kept at config parity)
- **Keyboard**: [Kanata](https://github.com/jtroo/kanata) (laptop remapping), custom zmk layouts for [Glove80](https://github.com/gnohj/glove80) & [Corne](https://github.com/gnohj/hypersonic-corne) (external keyboards)
- **Monitoring**: `usage-sampler` LaunchAgent records CPU/mem/swap/pressure every 5 min to `~/.local/state/usage/*.csv` (trend via `usage-report.sh`) - the macOS analog to the VPS's sysstat/atop

### Linux VPS (remote dev box)

Headless, so the desktop categories above collapse into CLI equivalents: the terminal and keyboard remapping stay on the Mac client, tmux + Sesh do the windowing/launching, and the CLI core is the **same Nix toolchain as the Mac**.

- **System & Packages**: [Nix](https://nixos.org/) via [home-manager](https://github.com/nix-community/home-manager) provides the CLI toolchain from the same `flake.lock` as the Mac (home-manager is the Linux analog to nix-darwin); [apt](https://wiki.debian.org/apt) supplies the thin base (build tools, monitoring, source-built tmux); [Mise](https://mise.jdx.dev/) handles language runtimes + agent CLIs
- **Networking**: [Tailscale](https://tailscale.com/) mesh (the only way in - no public SSH), [Mosh](https://mosh.org/) for roaming attach
- **Secrets Management**: scoped tokens in `~/.zsh_gnohj_env.local` (no full Bitwarden unlock on the box)
- **Monitoring**: [sysstat](https://github.com/sysstat/sysstat) + [atop](https://www.atoptool.nl/) (file-based, near-zero RAM)

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

The Linux counterpart to the macOS flow, and now **nix-first like the Mac**: a single script does the system prep, installs Nix + the home-manager toolchain (the same shared flake the Mac uses), then applies dotfiles.

### One command (run as root on a fresh box)

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
```

Run it inside `tmux`/`mosh` so a dropped SSH link doesn't kill the long Nix build. To bring Tailscale up unattended, pass an auth key:

```bash
TS_AUTHKEY=tskey-... curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
```

This will:

- **Root phase:** create the `gnohj` user, copy your SSH key, set passwordless sudo, harden sshd (key-only, no root login, validated with `sshd -t`), install Tailscale, wait out cloud-init, then hand off to the user.
- **User phase:** clone the dotfiles source → install Nix + first `home-manager switch` (the bulk CLI toolchain, from the shared flake) → `chezmoi apply` → the Linux bootstrap (apt base, sysstat/atop monitoring, mise runtimes + agent CLIs, herdr, a seeded default theme).

Idempotent - safe to re-run (a re-run also fast-forwards the source to `origin/main` first, so it always builds the latest). It ends at the root prompt (a piped bootstrap can't switch your shell); continue as the target user with the **dash**: `su - gnohj` (plain `su gnohj` strands you in `/root` with a broken env).

### Remaining manual steps (interactive / secret-touching - can't be piped)

Run these as the target user (`su - gnohj`):

1. **`gh auth login`** - the one thing that can't be automated. It unlocks the private provisioning repo and registers the SSH key its private clones need.
2. **Clone + run the private `post-provision.sh`** - it scripts the rest (AI OAuth, scoped secrets, atuin, Tailscale, repos, tmux-dash, agents, tpm), idempotent, pausing only where a human is genuinely needed:

   ```bash
   git clone git@github.com:gnohj/vps-linux-provision.git ~/Developer/vps-linux-provision
   ~/Developer/vps-linux-provision/post-provision.sh
   ```

3. **agent-tmux-web** - deliberately NOT in the script (phone-PWA code-exec surface). Needs Tailscale up; audit `src/server/{index,tmux}.ts` before trusting a SHA, then `install-agent-tmux-web.sh`.

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

The box mirrors the Mac's update model. The one-shot is **`up`** - it runs apt full-upgrade → `nix flake update` + `home-manager switch` → mise → chezmoi → tpm, each step banner'd and failure-tolerant. There's no Homebrew or App Store layer; the surfaces below are for targeted updates.

### 1. System packages (apt)

The base packages (tmux, mosh, python3, monitoring, etc.) come from apt:

```bash
sudo apt-get update && sudo apt-get upgrade -y

# clean up
sudo apt-get autoremove -y && sudo apt-get clean
```

### 2. Nix (CLI toolchain, via home-manager)

The bulk CLI toolchain (nvim, ripgrep, fd, lazygit, bat, delta, yazi, …) comes from the same shared flake as the Mac. `up` handles it; manually (on Linux the flake lives in the chezmoi source, since `~/.nix` is gitignored):

```bash
nix flake update --flake ~/.local/share/chezmoi/dot_nix
home-manager switch --flake ~/.local/share/chezmoi/dot_nix#gnohj-linux-x86_64
```

### 3. Chezmoi (Dotfiles Management)

**Apply latest dotfiles:**

```bash
chezmoi apply
```

**Update from remote and apply** (re-runs the toolchain bootstrap when it changes):

```bash
chezmoi update
```

Secrets on the VPS are NOT managed by `rbw`/Bitwarden - they live in `~/.zsh_gnohj_env.local` (see `MANUAL_VPS_SETUP.md`). Edit that file directly to rotate a token.

### 4. Mise (Language/Environment Management)

Same as the Mac:

```bash
mise outdated        # list outdated runtimes/CLIs
mise install         # install/update everything from config
mise upgrade         # upgrade all to latest
mise upgrade node    # upgrade a specific runtime
```

### 5. Tailscale + from-source tools

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
cd ~/Developer/tmux-dash && git pull && cargo install --path .
```

</details>
