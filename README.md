# Dotfiles

Dotfiles managed with GNU Stow, plus utility scripts for local (Arch/Omarchy)
and university server (RHEL, no sudo) setups.

Every script supports `-h`/`--help`; that is the authoritative documentation.
This file gives the layout and the main workflows. (`dotfiles-help` opens this
file in `bat`.)

## Layout

```
dotfiles/
├── hosts.toml          # Host/group/mount inventory (single source of truth)
├── packages.toml       # Package/webapp/cargo/bin/gh/yazi/omarchy-theme/omarchy-plugin/zotero lists (single source of truth)
├── bin/                # Utility scripts (on PATH via dot-bashrc)
│   ├── lib-dotfiles.sh # Shared lib: logging, ensure_cmd, symlink helper
│   ├── lib-install.sh  # Shared lib: GitHub releases, marcosnils/bin, juliaup, tpm
│   ├── lib-hosts.sh    # Shared lib: hosts.toml accessors (go-yq / jq)
│   └── lib-packages.sh # Shared lib: packages.toml accessors (go-yq / jq)
├── default/            # Stow package (dot-config, dot-bashrc, dot-agents, ...)
└── templates/latex/    # Templates for dotfiles-latex-init.sh
```

Stow layout: `dot-` prefixed entries map to dotfiles in `$HOME`
(`default/dot-config/...` → `~/.config/...`).

`dac` / `dar` pass `--no-folding` to GNU Stow so config dirs are never
tree-folded into a single symlink (which would let app-managed files like Yazi
`ya pkg` plugins land inside the dotfiles repo).

## Applying configuration

### Local machines

```bash
dotfiles-apply-config.sh [PROFILE]    # alias: dac
```

Stows `default/` into `~`. Conflicts are resolved interactively with `gum`
(adopt into the repo, or abort). Also links agent skills/commands into
`~/.cursor` and `~/.config/opencode`, and reloads Hyprland.

Host-specific Hyprland (monitors, scale, workspace pins) is in
`default/dot-config/hypr/monitors.lua`: it reads `/etc/hostname` and the
connected displays. `dac` still accepts an optional profile overlay if you add
a top-level package later.

Pass GNU Stow flags after `--` (e.g. `dac -- -D` to unstow, then `dac` to
re-apply). `dar -- -D` unstows replica `dot-config` / `dot-agents` / `dot-pi`.

### University servers (no sudo)

```bash
# 1. Install user-local CLI tools (bootstraps marcosnils/bin, then bin install from
#    packages.toml [bin.replica]; uv tool install from [uv.replica] (e.g. trash-cli);
#    neovim AppImage is glibc-aware, stow built from source, juliaup)
dotfiles-setup-replica.sh             # alias: dsr

# 2. Apply configs (gum menu: julia config symlink, stow
#    dot-config/dot-agents/dot-pi, bashrc sourcing). --all skips the menu.
dotfiles-apply-replica.sh             # alias: dar
```

GitHub API access: set `GITHUB_AUTH_TOKEN` (PAT, no scopes) or `gh auth login`.

Replica tools include official standalone tmux builds (`tmux/tmux-builds`), avoiding
cluster ncurses/libevent module dependencies. On Saga, after installing standalone
tmux, run `bin/migrations/dotfiles-migrate-saga-shell-tools.sh` once to back up
`~/.bashrc` and remove the legacy Git/tmux module loads and ncurses swap. Use system
Git, and test from a fresh SSH login with `tmux -L clean new-session -s main`;
existing tmux servers retain their old module environment.

### Local package management (Arch/Omarchy)

```bash
dotfiles-setup-packages.sh [--all]    # alias: dsp
```

Gum menu of steps: remove default Omarchy webapps/packages, install from
`packages.toml` (Arch packages, gh extensions, cargo crates, Yazi plugins,
third-party Omarchy themes and shell plugins), marcosnils/bin, Television channels, Zotero plugins,
LaTeX templates, tpm, Tailscale, Syncthing, juliaup. Ensures go-yq is installed
via yay before any step that reads `packages.toml` (safe when migrating from
Python `yq`).

## Host inventory and remote access

Machines, groups, mountable filesystems, and the rsync sync root are declared once in
[`hosts.toml`](hosts.toml) and consumed via `bin/lib-hosts.sh` (requires
go-yq or legacy tomlq, plus `jq`). Jump hosts and ControlMaster settings live in `~/.ssh/config`.

**Sync root** (`defaults.sync_root` plus optional per-machine/group override) maps
each host's remote `Code` tree to local `~/Code`. The remote spec is relative to
each entry's `remote_path`, or absolute when it starts with `/`. Local landing
defaults to `~/Code` when not overridden. Example: fox overrides with a
project-area path on the server.

| Script | Purpose |
| --- | --- |
| `dotfiles-ssh-tmux.sh` (`dst`) | Pick a host with gum, SSH in, attach/create tmux session. Starts a background ControlMaster first for hosts configured with one (2FA hosts). Machines with `login_node` in `hosts.toml` hop to that node so tmux is not lost on VIP round-robin. Syncs the local Omarchy theme to that host in the background (log: `~/.cache/dotfiles/remote-theme-sync.log`). |
| `dotfiles-theme-sync-remote.sh` | Rsync the locally staged Omarchy theme (`~/.local/state/omarchy/current/theme`) to active SSH hosts (ControlMaster only). Applies replica hooks: btop, tmux (status + pane OSC), terminals, gum env, pi, claude, helix, opencode, neovim (`~/.config/nvim/lua/plugins/theme.lua` → staged `neovim.lua`). Hosts with `login_node` apply on that node (VIP rsync, hop for live tmux). No Omarchy clone on the remote. Also run from the `theme-set.d/remote-theme-sync` hook (background, log: `~/.cache/dotfiles/remote-theme-sync.log`). |
| `dotfiles-rsync-ssh.sh` (`drs`) | Pick host, browse folders, rsync selections. Pull (default): remote → `~/Code`. Push: `drs --push host`. Remote copy: `drs --remote source target path`. Examples: `drs fox DRL_Sphere`, `drs ml3`, `drs --push nam-shub-01`, `drs --remote fox ml3 DRL_Sphere/data`. |
| `dotfiles-mounts.sh` | SSHFS mount manager (TUI and CLI). Plain user `sshfs` mounts of the filesystems in `hosts.toml`; sudo only to prepare `/mnt` mountpoints. `-l` lists status, `-e`/`-d` enable/disable. |
| `dotfiles-server-monitor.sh` | tmux session with one `btop` window per selected host; group members preselected. |
| `dotfiles-setup-ssh.sh` | ssh-copy-id your ed25519 key to one node per mountable filesystem. |
| `dotfiles-setup-git-signing.sh` | Global SSH commit signing + optional GitHub signing key upload. |

## Other utilities

| Script | Purpose |
| --- | --- |
| `dotfiles-latex-init.sh` | New LaTeX project from `templates/latex/`. |
| `dotfiles-compress-video.sh` | ffmpeg compression for web playback. |
| `dotfiles-youtube-audio.sh` | yt-dlp audio download + LocalSend share. |
| `dotfiles-cmd-ocr` | OCR a screen region (grim/slurp/tesseract), copy to clipboard. |
| `dotfiles-scratch-nvim` | Floating terminal with nvim on a timestamped quicknote. |
| `dotfiles-fix-browser-audio.sh` | Unmute/uncork PipeWire browser streams. |
| `dotfiles-power-suspend.sh` | logind drop-in: power button suspends. |
| `dotfiles-setup-zotero.sh` | Download Zotero plugins from GitHub releases (`packages.toml` `[zotero.plugins]`). |
| `dotfiles-firefly-backup.sh` / `dotfiles-firefly-restore.sh` | Firefly III files + MariaDB dump backup/restore (docker). |
| `julia-setup.jl` | Install the global Julia dev packages. |
| `jlreg` | Register Julia package in LocalRegistry, tag, GitHub release. |

## Requirements

- Local: GNU Stow, `gum`, `yay` (Arch), Hyprland/Omarchy for the desktop bits,
  go-yq (mikefarah) for TOML inventory scripts (legacy tomlq fallback), `sshfs` for mounts, `rsync`.
- University servers: `curl`, `tar`, `git`, `jq`; no sudo needed.
  `dotfiles-setup-replica.sh` bootstraps go-yq via marcosnils/bin before reading
  `packages.toml`, then installs from `[bin.replica]` and `[uv.replica]` (e.g. trash-cli via
  `uv tool install`).
  Optional `GITHUB_AUTH_TOKEN` for API rate limits.

## Notes

- Hyprland env changes (`hl.env`) need a full Hyprland restart, not just reload.
- After Hyprland Lua edits: `hyprctl reload` then `hyprctl configerrors`.
- Restore an Omarchy default Lua file: `omarchy refresh config hypr/bindings.lua`
- Tree-sitter CLI is installed via cargo (`tree-sitter-cli` in `packages.toml`).
  On old-glibc servers where that build fails, install manually:
  `cargo install tree-sitter-cli --no-default-features`
- Local tmux status colors still come from `themed/tmux.conf.tpl` + the
  `theme-set.d/tmux` hook. Quattro's `omarchy-theme-set-tmux` paints pane/window
  colors; keep the workaround for the status bar. Remote fan-out rsyncs the
  staged theme and reapplies terminal/tmux hooks via
  `dotfiles-theme-sync-remote.sh` / `hooks/theme-set.d/remote-theme-sync`.
  Replicas do not clone Omarchy.
