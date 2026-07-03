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
├── bin/                # Utility scripts (on PATH via dot-bashrc)
│   ├── lib-dotfiles.sh # Shared lib: logging, ensure_cmd, symlink helper
│   ├── lib-install.sh  # Shared lib: GitHub releases, marcosnils/bin, juliaup, tpm
│   ├── lib-hosts.sh    # Shared lib: hosts.toml accessors (tomlq)
│   └── package-lists/  # Package/webapp lists for dotfiles-setup-packages.sh
├── default/            # Base stow package (dot-config, dot-bashrc, dot-agents, ...)
├── bengal/ kaspi/ sibir/ sibir2/   # Host profile overlays (stowed on top of default)
└── templates/latex/    # Templates for dotfiles-latex-init.sh
```

Stow layout: `dot-` prefixed entries map to dotfiles in `$HOME`
(`default/dot-config/...` → `~/.config/...`).

## Applying configuration

### Local machines

```bash
dotfiles-apply-config.sh [PROFILE]    # alias: dac
```

Stows `default/` into `~`, then the optional profile overlay (`bengal`,
`kaspi`, ...). Conflicts are resolved interactively with `gum` (adopt into the
repo, or abort). Also links agent skills/commands into `~/.cursor` and
`~/.config/opencode`, and reloads Hyprland.

### University servers (no sudo)

```bash
# 1. Install user-local CLI tools (bootstraps marcosnils/bin, then bin install;
#    neovim AppImage is glibc-aware, stow built from source, juliaup, omarchy clone)
dotfiles-setup-replica.sh             # alias: dsr

# 2. Apply configs (gum menu: omarchy clone, julia config symlink,
#    stow dot-config/dot-agents, bashrc sourcing). --all skips the menu.
dotfiles-apply-replica.sh             # alias: dar
```

GitHub API access: set `GITHUB_AUTH_TOKEN` (PAT, no scopes) or `gh auth login`.

### Local package management (Arch/Omarchy)

```bash
dotfiles-setup-packages.sh [--all]    # alias: dsp
```

Gum menu of steps: remove default Omarchy webapps/packages, install packages
from `bin/package-lists/`, gh extensions, marcosnils/bin, Television channels,
Zotero plugins, LaTeX templates, tpm, Tailscale, Syncthing, tree-sitter,
juliaup.

## Host inventory and remote access

Machines, groups, mountable filesystems, and the rsync sync root are declared once in
[`hosts.toml`](hosts.toml) and consumed via `bin/lib-hosts.sh` (requires
`tomlq`). Jump hosts and ControlMaster settings live in `~/.ssh/config`.

**Sync root** (`defaults.sync_root` plus optional per-machine/group override) maps
each host's remote `Code` tree to local `~/Code`. The remote spec is relative to
each entry's `remote_path`, or absolute when it starts with `/`. Local landing
defaults to `~/Code` when not overridden. Example: fox overrides with a
project-area path on the server.

| Script | Purpose |
| --- | --- |
| `dotfiles-ssh-tmux.sh` (`dst`) | Pick a host with gum, SSH in, attach/create tmux session. Starts a background ControlMaster first for hosts configured with one (2FA hosts). |
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
| `dotfiles-setup-zotero.sh` | Download Zotero plugins from GitHub releases. |
| `dotfiles-firefly-backup.sh` / `dotfiles-firefly-restore.sh` | Firefly III files + MariaDB dump backup/restore (docker). |
| `julia-setup.jl` | Install the global Julia dev packages. |
| `jlreg` | Register Julia package in LocalRegistry, tag, GitHub release. |

## Requirements

- Local: GNU Stow, `gum`, `yay` (Arch), Hyprland/Omarchy for the desktop bits,
  `tomlq` (yq) for host-inventory scripts, `sshfs` for mounts, `rsync`.
- University servers: `curl`, `tar`, `git`, `jq`, `python3`; no sudo needed.
  `dotfiles-setup-replica.sh` installs `tomlq` via `pip install --user yq`.
  Optional `GITHUB_AUTH_TOKEN` for API rate limits.

## Notes

- Hyprland `envs.conf` changes need a full Hyprland restart, not just reload.
- Restore an Omarchy default config:
  `~/.local/share/omarchy/bin/omarchy-refresh-config hypr/bindings.conf`
- Tree-sitter on old-glibc servers may need a source build:
  `cargo install tree-sitter-cli --no-default-features`
