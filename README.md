# Dotfiles

My personal dotfiles for macOS and Linux.

<img width="2557" height="1440" alt="ghostty-current" src="https://github.com/user-attachments/assets/dbe927ed-fda1-4d92-958a-d92d1220b9ee" />

## Key Tools & Configurations

### Shared core (macOS + Linux)

- **Dotfiles Management**: [Chezmoi](https://www.chezmoi.io/)
- **Language/Environment Management**: [Mise](https://mise.jdx.dev/)
- **Shell**: Zsh with [Starship](https://starship.rs/) prompt, [Atuin](https://github.com/atuinsh/atuin)
- **Editor**: [Neovim](https://neovim.io/)
- **Multiplexer**: [Rex](https://www.superlogical.com)
- **Networking**: [Tailscale](https://tailscale.com/) mesh
- **File Manager**: [Yazi](https://yazi-rs.github.io/)
- **Version Control**: Git worktrees, [Delta](https://github.com/dandavison/delta) pager, [Lazygit](https://github.com/jesseduffield/lazygit) TUI
- **System Monitor**: [btop](https://github.com/aristocratos/btop)

### macOS

- **System Management**: [Nix-Darwin](https://github.com/LnL7/nix-darwin)
- **Package Management**: [Homebrew](https://brew.sh/)
- **Secrets Management**: [Bitwarden](https://bitwarden.com/) via [rbw](https://github.com/doy/rbw)
- **Window Management**: [Rift](https://github.com/acsandmann/rift), [JankyBorders](https://github.com/FelixKratz/JankyBorders), [Sketchybar](https://github.com/FelixKratz/SketchyBar)
- **Launcher**: [Tinycast](https://github.com/abue-ammar/tinycast)
- **Terminal**: [Ghostty](https://github.com/ghostty-org/ghostty), [Kitty](https://github.com/kovidgoyal/kitty)
- **Keyboard**: [Kanata](https://github.com/jtroo/kanata), custom zmk layouts for [Glove80](https://github.com/gnohj/glove80) & [Corne](https://github.com/gnohj/hypersonic-corne)

### Linux

- **OS**: [Omarchy](https://omarchy.org/) on [Arch](https://archlinux.org/) with [Hyprland](https://hypr.land/)
- **Package Management**: pacman + [yay](https://github.com/Jguer/yay); [Mise](https://mise.jdx.dev/) handles language runtimes + agent CLIs
