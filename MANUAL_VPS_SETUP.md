# Manual VPS Setup — Remote Dev Box (Model A)

The **interactive / secret-touching** steps that `chezmoi` + `run_onchange_after_linux-bootstrap.sh` can't script. Distinct from `MANUAL_SETUP.md` (which is the macOS/nix path).

What's automated (don't do by hand): the bootstrap installs the toolchain, agent CLIs (claude/codex/gemini), custom tools (treehouse/no-mistakes/treekanga/atuin, tmux-dash from source), tailscale binary, and `enable-linger`. Everything below is the manual remainder.

---

## 🔒 Security rules — READ FIRST

These are non-negotiable; the rest of the doc assumes them.

1. **Reach the box ONLY over Tailscale.** Never bind a service to `0.0.0.0`, never port-forward to the public internet, never use `tailscale funnel` for these services.
2. **Close public SSH.** Either use Tailscale SSH, or firewall port 22 to the tailnet range (`100.64.0.0/10`). Set `PasswordAuthentication no` and `PermitRootLogin no` in `sshd_config`.
3. **Secrets live only in `chmod 600` files, generated ON the box** (`openssl rand -hex 32`). Never commit them, never paste them into shared logs / chat / screenshots, never echo them to a world-readable location.
4. **Do NOT put your Bitwarden master key or unlock your full vault on the VPS.** Use `gh auth login` + per-machine agent OAuth + per-service generated tokens instead. Don't copy your primary `~/.ssh/id_ed25519` here — generate a dedicated per-host key or use Tailscale SSH.
5. **The `agent-tmux-web` token = full code execution on the box.** Treat the tokenized URL like a password: don't screen-share it, don't sync it into browser history you back up, rotate it if exposed.
6. **Rotate tokens** by regenerating the `.env` value and restarting the service — not by editing `tailscale serve`.

---

## 1. Provision (Vultr, Ubuntu 24.04, Dallas)

Trial: Vultr `/promo/try300/` ($300 credit / 30 days). Deploy → **Dallas** → Ubuntu 24.04 → **VX1 GP** (4 vCPU / 16 GB) + **8 GB swap** → attach your SSH **public** key → Hostname `dev-box`, Label `dev-box-dallas-trial` → Deploy Now. Note the public IP. **Delete before day ~28** (power-off still bills). Sizing rationale: 16 GB comfortably runs the full agent stack in the trial; bump to 32 GB only if monitoring (§8b) shows an OOM kill or sustained swap/pressure.

## Fast path — one command does §2–§4

`linux-setup.sh` scripts the whole root-prep + bootstrap: it creates the user, copies the SSH key, sets passwordless sudo, hardens sshd, installs Tailscale, waits out cloud-init, then runs the chezmoi bootstrap. Run it as **root** on the fresh box:

```
curl -fsSL https://raw.githubusercontent.com/gnohj/dotfiles/main/linux-setup.sh | bash
```

(`... | bash -s -- myuser` for a different username; `TS_AUTHKEY=tskey-... ... | bash` to bring Tailscale up unattended.) It's idempotent, and it prints the interactive remainder (§5–§7) at the end. Run it inside tmux/mosh so a dropped link doesn't kill the long cargo builds. The sections below are the same steps by hand, for when you want to understand or diverge from what the script does.

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

## 6. tmux-dash — **private repo, manual build** (usually needed by hand)

tmux-dash is a **personal PRIVATE repo** with no release binaries, built from source (Rust). The bootstrap attempts it over SSH but on a fresh box that repo auth isn't set up yet, so **expect to do this by hand** after auth. First give the box GitHub access — a **dedicated per-host SSH key** added to your GitHub account (preferred; don't copy your primary key — §Security 4), or `gh auth login` + `gh auth setup-git`. Then:

```
git clone git@github.com:gnohj/tmux-dash && cd tmux-dash && cargo install --path .
```

Treat this like the other **private repos** you clone by hand (see `MANUAL_SETUP.md`'s clone section) — chezmoi can't fetch private repos for you.

## 7. agent-tmux-web (security-sensitive — go slow)

**One command** (chezmoi drops the installer on the box): `install-agent-tmux-web.sh <PINNED-AUDITED-SHA>` — it clones+pins+builds, writes the `chmod 600` token `.env` (HOST=127.0.0.1), installs the user systemd unit + linger, and runs `tailscale serve` — and it never prints the token to logs. **Read the server source first** (`src/server/index.ts` + `tmux.ts`) before trusting a SHA.

The manual equivalent, if you'd rather do it by hand:

```
git clone https://github.com/antonlobanovskiy/agent-tmux-web.git ~/.local/share/agent-tmux-web
cd ~/.local/share/agent-tmux-web && git checkout <PINNED-AUDITED-SHA>
```

**Read `src/server/index.ts` + `tmux.ts` before building** (audited clean: constant-time auth, arg-array exec, no shell injection). Then build + configure:

```
pnpm install --frozen-lockfile && pnpm build
printf 'HOST=127.0.0.1\nPORT=6174\nCLI_WEB_DEFAULT_CWD=%s\nAGENT_TMUX_WEB_AUTH_TOKEN=%s\n' "$HOME" "$(openssl rand -hex 32)" > .env
chmod 600 .env
```

- **Bind stays `127.0.0.1`** — Tailscale exposes it, privately. A token MUST be set (empty token disables auth entirely).
- Install the user systemd unit (put `%h/.local/share/mise/shims` on its `PATH`), then:

```
loginctl enable-linger "$(id -un)"
systemctl --user daemon-reload && systemctl --user enable --now agent-tmux-web.service
tailscale serve --bg http://127.0.0.1:6174
```

- Phone URL = `https://<box>.ts.net/?token=<value from .env>` — a password (§Security 5). `grep AGENT_TMUX_WEB_AUTH_TOKEN .env` to read it; never paste it anywhere shared.

## 8. Run agents + connect

```
tmux new -s claude -c ~/work    # then run: claude   (Ctrl-b d to detach)
```

Laptop: `ssh gnohj@<box>.ts.net` (or `mosh`) → `tmux attach`. Phone: open the tokenized URL, Add to Home Screen.

## 8b. Monitoring — trial data for the 16-vs-32 GB verdict

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

## 9. (Optional, later) VPS → Mac dispatcher

Tailnet-bound + token-gated + **named-actions-only** + argv-exec + optional Tailscale ACL limiting the VPS to just the dispatcher port. Build it deliberately - it points a cloud box at an executor on your personal Mac.

---

## ✅ Verify

- [ ] Tailscale up on box + laptop + phone (same tailnet)
- [ ] `chezmoi apply` clean; shell / nvim / tmux feel like the Mac
- [ ] on PATH: `treehouse treekanga no-mistakes tmux-dash atuin claude codex gemini`
- [ ] `gh auth status` OK; `claude` / `codex` authed
- [ ] `systemctl --user status agent-tmux-web` active; phone loads the PWA
- [ ] `loginctl show-user "$(id -un)" | grep Linger=yes` — close laptop, session survives
- [ ] **No service bound to `0.0.0.0`**; public port 22 closed; `.env` is `chmod 600`
- [ ] OSC52 clipboard works over SSH (yank in nvim → paste on the Mac)
- [ ] Monitoring live: `systemctl status sysstat atop` active; `vps-usage-export.sh` writes CSVs to `~/vps-usage/`
