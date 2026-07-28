# Manual VPS Setup — Remote Dev Box (Model A)

The **interactive / secret-touching** steps that `chezmoi` + `run_onchange_after_linux-bootstrap.sh` can't script. Distinct from `MANUAL_SETUP.md` (which is the macOS/nix path).

What's automated (don't do by hand): the bootstrap installs the toolchain, agent CLIs (claude/codex/gemini), custom tools (treehouse/no-mistakes/treekanga/atuin), tailscale binary, and `enable-linger`. Everything below is the manual remainder.

---

## 🔒 Security rules — READ FIRST

These are non-negotiable; the rest of the doc assumes them.

1. **Reach the box ONLY over Tailscale.** Never bind a service to `0.0.0.0`, never port-forward to the public internet, never use `tailscale funnel` for these services.
2. **Close public SSH.** Either use Tailscale SSH, or firewall port 22 to the tailnet range (`100.64.0.0/10`). Set `PasswordAuthentication no` and `PermitRootLogin no` in `sshd_config`.
3. **Secrets live only in `chmod 600` files, generated ON the box** (`openssl rand -hex 32`). Never commit them, never paste them into shared logs / chat / screenshots, never echo them to a world-readable location.
4. **Do NOT put your Bitwarden master key or unlock your full vault on the VPS.** Use `gh auth login` + per-machine agent OAuth + per-service generated tokens instead. Don't copy your primary `~/.ssh/id_ed25519` here — generate a dedicated per-host key or use Tailscale SSH.
5. **Rotate a leaked token at its source** - regenerate it at the provider, refill `~/.zsh_gnohj_env.local`, `source ~/.zshrc`. Never paper over it downstream.

---

## 1. Provision (Vultr, Ubuntu 24.04, Dallas)

Trial: Vultr `/promo/try300/` ($300 credit / 30 days). Deploy → **Dallas** → Ubuntu 24.04 → **VX1 GP** (4 vCPU / 16 GB) + **8 GB swap** → attach your SSH **public** key → Hostname `dev-box`, Label `dev-box-dallas-trial` → Deploy Now. Note the public IP. **Delete before day ~28** (power-off still bills). Sizing rationale: 16 GB comfortably runs the full agent stack in the trial; bump to 32 GB only if monitoring (§7b) shows an OOM kill or sustained swap/pressure.

## Fast path — one command does §2–§4

`linux-vps-setup.sh` scripts the whole root-prep + bootstrap: it creates the user, copies the SSH key, sets passwordless sudo, hardens sshd, installs Tailscale, waits out cloud-init, then runs the chezmoi bootstrap. Run it as **root** on the fresh box:

```
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
```

(`... | bash -s -- myuser` for a different username.) To bring Tailscale up unattended and raise the GitHub rate limit, **export the vars first** so the piped `bash` inherits them - `VAR=... curl ... | bash` sets them for `curl` only, not `bash`, so the script sees them unset:

```
export TS_AUTHKEY=tskey-... GITHUB_TOKEN=ghp-...
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-vps-setup.sh | bash
```

It's idempotent, and it prints the interactive remainder (§5–§6) at the end. Run it inside tmux/mosh so a dropped link doesn't kill the long cargo builds. The sections below are the same steps by hand, for when you want to understand or diverge from what the script does.

## 2. User + SSH hardening

```
ssh root@<server-ip>
adduser gnohj && usermod -aG sudo gnohj
rsync --archive --chown=gnohj:gnohj ~/.ssh /home/gnohj
```

Harden `sshd` (`/etc/ssh/sshd_config.d/hardening.conf`): `PasswordAuthentication no`, `PermitRootLogin no`, then `systemctl restart ssh`. Firewall public 22 (cloud firewall or `ufw` allowing 22 only from `100.64.0.0/10`), or rely on Tailscale SSH (step 3) and drop public 22 entirely.

Passwordless sudo (lets the bootstrap `apt`-install + set linger cleanly):

```
echo "gnohj ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/gnohj
```

(Scope this tighter later if you prefer — it's a convenience for the one-time bootstrap.)

## 3. Tailscale (interactive)

```
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Approve the machine at the printed URL. In the admin console (`login.tailscale.com/admin/dns`): enable **MagicDNS** + **HTTPS Certificates**. Install Tailscale on your **laptop + phone**, same account.

## 4. chezmoi (runs the bootstrap)

`gnohj/dotfiles` is **public**, so no key/token needed to clone:

```
sh -c "$(curl -fsSL https://chezmoi.io/get)" -- init --apply gnohj
```

This applies the Linux subset and runs the bootstrap (toolchain + agent CLIs + custom tools + tailscale + linger). Re-run bootstrap steps later with `chezmoi update`.

## 5. Authenticate the tools (interactive, per-machine)

```
gh auth login                    # HTTPS token → git push + gh + aic
claude   # once, for OAuth   |   codex   # once   |   gemini   # once
```

`gh auth login` uses a scoped token stored by `gh` — do NOT restore your Bitwarden `id_ed25519` here (§Security 4).

## 5b. Scoped secrets → `~/.zsh_gnohj_env.local`

The VPS deliberately skips Bitwarden, so nothing populates secrets automatically here. `run_onchange_after_bitwarden.sh.tmpl` exits early when `rbw` is absent, which means `~/.zsh_gnohj_env.secrets` is never generated on this box (§Security 4). Per-machine secrets go in `~/.zsh_gnohj_env.local` instead - gitignored, and sourced at the end of `~/.zsh_gnohj_env`.

Create it, then add one `export NAME="value"` line per token, reading each value on the **Mac** with `rbw get <NAME>`:

```
touch ~/.zsh_gnohj_env.local && chmod 600 ~/.zsh_gnohj_env.local
```

`dot_config/bitwarden/vars.txt` is the canonical list; copy only the **scoped subset** this box actually needs, never the whole vault. At minimum that has been: `CONTEXT7_API_KEY`, `GEMINI_API_KEY`, `GPR_AUTH_TOKEN`, `JIRA_API_TOKEN`, `OPENAI_API_KEY`, `TURBO_TOKEN`.

**`TURBO_TOKEN` is easy to miss and expensive to omit.** Without it turbo has no remote cache, so every task is a cold miss - the web repo's `pre-push` hook (typecheck + lint + test via turbo) then takes minutes instead of seconds. It is a single unnamespaced secret shared by both repos, unlike `FASTLY_API_TOKEN` / `INFERNO_FASTLY_API_TOKEN`, so one line covers web and inferno. Only the token belongs here: `web/turbo.json` already sets `remoteCache.teamSlug` and `inferno/.envrc` already sets `TURBO_TEAM`.

Reload with `source ~/.zshrc`.

## 6. Run agents + connect

```
tmux new -s claude -c ~/work    # then run: claude   (Ctrl-b d to detach)
```

Laptop: `ssh gnohj@<box>.ts.net` (or `mosh`) → `tmux attach`.

## 6b. Monitoring — trial data for the 16-vs-32 GB verdict

The bootstrap already installs + enables the **lightweight, file-based recorders** (near-zero RAM, so they don't skew the memory measurement you're taking): `sysstat` (sar time-series, sampling every 5 min) and `atop` (per-process log every 60 s). Nothing to install by hand. To use them:

```
vps-usage-export.sh              # today's sar data → ~/vps-usage/*.csv + verdict signals
vps-usage-export.sh --all        # every retained day
atop -r                          # interactive replay — scroll to any spike, see which agent
cat /proc/pressure/memory        # live bottleneck oracle (nonzero 'some' = mem-constrained)
```

The CSVs (semicolon-delimited, `sadf -d` format) import straight into a spreadsheet / chart tool. The **verdict**: any OOM kill or sustained swap/pressure under the full stack → 32 GB; comfortable with no swap and low pressure → 16 GB is enough.

**netdata (optional, add LATER — not during the trial):** once sizing is decided you can add a live web dashboard. It costs ~150-250 MB RAM, which is why it's kept out of the trial measurement. Install and browse it **tailnet-only** (never `funnel`/public):

```
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
# then browse over Tailscale: http://dev-box.<tailnet>.ts.net:19999
```

## 7. VPS → Mac dispatcher (built)

Lets the box reach the workstation for the things a headless machine can't do itself: open a URL, write the clipboard, post a notification, read the frontmost browser tab, and start a debuggable Chrome the box can drive over CDP. That last one is what makes browser E2E possible from an SSH session — `chrome-devtools-mcp` runs on the box and _attaches_ to a browser, it never launches one, and the box has no browser to launch.

`active-tab` is what lets the 🎫 **AI Add Worktree (Chrome tab → worktree)** launcher entry work from the box: it prints one `<browser>\t<url>` line per open browser and `worktree jira` picks the first Jira URL. Note it is a **different browser** from `browser-debug`, which deliberately launches a throwaway profile (`~/.cache/chrome-cdp-profile`). `active-tab` reads your real logged-in windows instead, which is why it goes through Apple Events rather than CDP.

**Trust model.** The box's key is pinned in the Mac's `authorized_keys` to `command="$HOME/.local/bin/to-desktop --forced"` with `no-pty` and no forwarding, so it can never obtain a shell. `to-desktop --forced` re-parses `$SSH_ORIGINAL_COMMAND` against its own verb allowlist, so the box gets exactly `open` / `clip` / `notify` / `browser-debug` / `active-tab` and nothing else. Every one of those takes fixed argv the box cannot steer, so a trailing `; id` or `$(id)` is either refused outright or lands as inert text. Reachability stays tailnet-only; public 22 on the Mac is never opened.

**One-time, on the Mac.** System Settings → General → Sharing → **Remote Login: ON**.

**Per new box, one command — run it ON the Mac:**

```
ssh <box> mac-authorize | bash
```

`mac-authorize` runs on the box, reads that box's own `~/.ssh/id_ed25519.pub` (generated by `post-provision.sh` step_gh), and emits a script that appends a correctly-formed `authorized_keys` entry tagged with the box hostname. It backs up the existing file, strips any prior entry for the same box so re-provisioning is idempotent, and prints the parsed fingerprints so you see immediately whether it took. Piping a generated script beats pasting a line by hand: a wrapped paste silently corrupts the options field, and sshd then reports the whole file as "not a public key file".

No ssh-config edit is needed for a new box — the Mac's `Host dev-box dev-box-* tailscale` block carries `RemoteForward 9222` and omits `HostName`, so each box resolves by its own MagicDNS name.

**Verify from the box:**

```
ssh macbook browser-debug && sleep 3 && curl -s http://127.0.0.1:9222/json/version
```

A Chrome version JSON means the whole chain is live: forced-command SSH to the Mac, Chrome launched there on the debug profile, and CDP reaching back through the `RemoteForward` that herdr carries on every `--remote` attach. A connection reset means Chrome isn't listening; `Permission denied` means the key isn't authorized.

Then check the tab reader, which needs a real browser window open on the Mac:

```
to-desktop active-tab
```

A `<browser>\t<url>` line means the 🎫 worktree capture will work from here. Empty output means no browser window is open on the Mac; `nobody is attached to relay to` means the resolver below found no live session.

**No relay target is ever configured.** `machine-identity mac-host` resolves it from live evidence on every single call, so it cannot drift out of sync with where you are actually sitting:

| Order | Signal | Why it cannot go stale |
| --- | --- | --- |
| 1 | `$NOTIFY_MAC_SSH` | Explicit override, for testing or a workstation off the tailnet |
| 2 | `tailscaled be-child ssh --remote-ip=` | Tailscale SSH spawns one process per login; it exits when you detach |
| 3 | `ss` established socket on `:22` | Classic sshd logins leave no such process, so the open socket is the evidence |

Then `tailscale status` maps that IP to a peer name, skipping any peer whose OS has no browser to open into (a phone). Nothing is read from disk, and `role` reports `devbox` only while somebody is attached, so an idle banner fired at 3am is not reverse-SSHed into an empty room.

What this deliberately does **not** use is `$SSH_CONNECTION`. The herdr server is systemd-spawned and long-lived, so it bakes in whoever attached first and every pane it later spawns inherits that same value forever.

**URL opening is wired through one variable.** `.zshenv` exports `BROWSER=desktop-open` and `GH_BROWSER=desktop-open`, and `desktop-open` is a one-word wrapper around `to-desktop open`. That is the whole integration:

| Tool | Path to the relay |
| --- | --- |
| gh-dash `o` | `cli/go-gh` reads `GH_BROWSER` before falling back to `xdg-open` |
| nvim `<leader>gb` / `<leader>gx` | snacks `gitbrowse` → `vim.ui.open` → `xdg-open` → `open_envvar` honors `BROWSER` |
| `gh pr view --web`, `git web--browse` | Same `BROWSER` contract |

No per-tool config, no nvim override, and anything new that respects either variable works for free. On the Mac the same export is harmless: `to-desktop` sees it is the workstation and opens locally, unsetting `BROWSER` for its own `xdg-open` child so a future Linux desktop cannot ping-pong between the two.

---

## ✅ Verify

- [ ] Tailscale up on box + laptop + phone (same tailnet)
- [ ] `chezmoi apply` clean; shell / nvim / tmux feel like the Mac
- [ ] on PATH: `treehouse treekanga herdr no-mistakes atuin claude codex gemini pi opencode`
- [ ] `gh auth status` OK; `claude` / `codex` authed
- [ ] `~/.zsh_gnohj_env.local` is `chmod 600` and `env | grep -c TURBO_TOKEN` prints `1` (cold turbo = minutes-long `pre-push`)
- [ ] `loginctl show-user "$(id -un)" | grep Linger=yes` — close laptop, session survives
- [ ] **No service bound to `0.0.0.0`**; public port 22 closed; `~/.zsh_gnohj_env.local` is `chmod 600`
- [ ] OSC52 clipboard works over SSH (yank in nvim → paste on the Mac)
- [ ] Dispatcher live (§7): `ssh macbook browser-debug` then `curl -s http://127.0.0.1:9222/json/version` returns Chrome JSON
- [ ] Monitoring live: `systemctl status sysstat atop` active; `vps-usage-export.sh` writes CSVs to `~/vps-usage/`
