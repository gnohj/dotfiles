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
- Install all packages from `~/.nix/` - the shared flake (`common/package-list.nix`, same set the Linux box builds) plus the Homebrew apps/casks

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

Once set up, keep the machine current with **`up`** (see [Update Existing Mac](#update-existing-mac-apple-silicon)).

</details>

## Bootstrap New Linux VPS (Ubuntu, amd64)

<details>
<summary>Click to expand bootstrap instructions</summary>

The Linux counterpart to the macOS flow, and now **nix-first like the Mac**: a single script does the system prep, installs Nix + the home-manager toolchain (the same shared flake the Mac uses), then applies dotfiles.

### One command (run as root on a fresh box)

```bash
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
```

Optionally set `TS_AUTHKEY` (brings Tailscale up unattended) and/or `GITHUB_TOKEN` (raises the GitHub rate limit for the toolchain install). **Export them first** - `VAR=… curl … | bash` scopes the vars to `curl`, not the piped `bash`, so the script would see them unset:

```bash
export TS_AUTHKEY=tskey-… GITHUB_TOKEN=ghp_…
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
```

Run it inside `tmux`/`mosh` so a dropped link doesn't kill the long build. It hands off to the target user; the post-provision steps (secrets, OAuth, Tailscale, agents, repos) are driven separately, outside this public repo.

</details>

## Update Existing Mac (Apple Silicon)

<details>
<summary>Click to expand update instructions</summary>

### The commands you'll actually use

- **`up`** - the whole machine current in one shot (each step banner'd, failure-tolerant): `nix flake update` + `darwin-rebuild switch` → `chezmoi apply` → `brew upgrade` → `mise` → `tpm`.
- **`update`** - pull the latest config repos (chezmoi dotfiles + `agents` + `tmux-dash`); no package upgrades.
- **`outdated`** - what's pending across nix (flake staleness), brew, mise, mas.
- **`nix-preview`** - exactly which nix packages would change on the next `up` (diff-closures; live `flake.lock` untouched).
- **`cza`** - re-add your local dotfile edits back into the chezmoi source after editing a target.

`up` covers everything below - the per-surface commands are just for targeted updates.

### Nix (CLI toolchain)

Pinned via `flake.lock` (reproducible until you bump it - shared with the Linux box). Rebuild on the current pin, or bump nixpkgs:

```bash
darwin-rebuild switch --flake ~/.nix#macbook_silicon                                     # rebuild on the current pin
nix flake update --flake ~/.nix && darwin-rebuild switch --flake ~/.nix#macbook_silicon  # bump to newest nixpkgs
```

The switch also drives Homebrew declaratively (`brew bundle` installs/removes casks) but leaves versions alone (`onActivation.upgrade = false`); `brew upgrade` bumps them. GC old generations: `nix-collect-garbage -d`.

### Homebrew (version bumps)

```bash
brew upgrade          # all formulae
brew upgrade --cask   # all casks
```

### Mise (runtimes + AI agents)

```bash
mise outdated         # list          mise install        # install missing from config
mise upgrade          # bump all      mise upgrade node   # one runtime
```

### Chezmoi (dotfiles)

`cz apply` (apply local source) · `cz update` (pull remote + apply) · `cza` (re-add target edits back into source). Secrets refresh from Bitwarden automatically when the list changes; force after a value change: `rbw sync && cz apply --force`.

### Mac App Store (mas)

`up` doesn't touch mas - update via the App Store, or `mas outdated` / `mas upgrade`.

</details>

## Update Existing Linux VPS (Ubuntu, amd64)

<details>
<summary>Click to expand update instructions</summary>

Mirrors the Mac's model - same aliases, minus the Homebrew/App-Store layer.

- **`up`** - one shot: `apt full-upgrade` → `nix flake update` + `home-manager switch` → `mise` → `chezmoi` → `tpm`.
- **`update`** - pull config repos (chezmoi + `agents` + `tmux-dash`).
- **`outdated`** - what's pending across nix (flake staleness) + mise.
- **`nix-preview`** - which nix packages would change on the next `up`.

`up` covers everything below.

### apt (system base)

```bash
sudo apt-get update && sudo apt-get full-upgrade -y && sudo apt-get autoremove -y
```

### Nix (CLI toolchain, via home-manager)

Same shared flake as the Mac. On Linux the flake lives in the chezmoi source (`~/.nix` is gitignored there); `up` also runs `nix upgrade-nix`, since home-manager doesn't manage the nix daemon:

```bash
nix flake update --flake ~/.local/share/chezmoi/dot_nix
home-manager switch --flake ~/.local/share/chezmoi/dot_nix#gnohj-linux-x86_64
```

### Mise (runtimes + AI agents)

```bash
mise outdated    # list      mise install   # install missing      mise upgrade   # bump all      mise upgrade node   # one runtime
```

### Chezmoi (dotfiles)

`cz apply` · `cz update` (pull + apply; re-runs the toolchain bootstrap when it changes). Secrets live in `~/.zsh_gnohj_env.local` (no rbw/Bitwarden on the box) - edit directly to rotate a token.

### Tailscale + from-source tools

Tailscale rides along with apt (`sudo tailscale update` to force). **herdr:** `curl -fsSL https://herdr.dev/install.sh | sh`. **tmux-dash** (private, cargo): `cd ~/Developer/tmux-dash && git pull && cargo install --path .`.

</details>
