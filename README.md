# Dotfiles Configuration

Comprehensive dotfiles management with support for both local development and university server setups.

## Structure

```
dotfiles/
├── bin/                          # Utility scripts
│   ├── dotfiles-apply-config.sh  # Link configurations via GNU Stow (local)
│   ├── dotfiles-apply-replica.sh # Apply configs for university servers
│   ├── dotfiles-setup-replica.sh # Install tools for university servers
│   ├── dotfiles-setup-packages.sh # Package management (remove defaults, install tools)
│   ├── julia-setup.jl           # Julia package installer
│   ├── dotfiles-ssh-tmux.sh     # Interactive SSH connection with tmux
│   ├── dotfiles-rsync-ssh.sh    # Remote directory sync tool
│   ├── dotfiles-setup-ssh.sh    # SSH key setup and distribution
│   ├── dotfiles-setup-git-signing.sh # Git SSH commit signing + optional GitHub
│   ├── dotfiles-setup-zotero.sh # Zotero Better BibTeX extension installer
│   ├── dotfiles-power-suspend.sh # Configure power button for suspend
│   ├── dotfiles-firefly-backup.sh # Firefly III backup utility
│   └── dotfiles-firefly-restore.sh # Firefly III restore utility
├── default/                      # Default configuration package
├── <profile>/                    # Profile-specific packages (bengal, kaspi, sibir, etc.)
└── README.md
```

## Core Scripts

### Configuration Management

#### Local Development Setup

```bash
~/dotfiles/bin/dotfiles-apply-config.sh
```

Links the Stow packages using GNU Stow with intelligent conflict detection:

- `default/` → `~/` (includes dotfiles for `.config/`, home files, etc.)
- Profile-specific overlays when specified

**With profile support:**

```bash
~/dotfiles/bin/dotfiles-apply-config.sh bengal
```

Or using alias:

```bash
dac bengal
```

Features:

- Interactive conflict resolution using `gum`
- Automatic Hyprland configuration reload
- Profile switching with overlay support

#### University Server Setup

For RHEL systems without sudo access:

**1. Install tools and dependencies:**

```bash
# Optional but recommended: PAT with no scopes (same env var marcosnils/bin uses)
export GITHUB_AUTH_TOKEN="your_token_here"
# Legacy alias still accepted:
# export GITHUB_TOKEN="your_token_here"
~/dotfiles/bin/dotfiles-setup-replica.sh
```

Bootstraps [marcosnils/bin](https://github.com/marcosnils/bin) into `~/.local/bin`, then uses `bin install` for GitHub release binaries. Installs to `~/.local/bin`:

- CLI tools: `eza`, `zoxide`, `starship`, `fzf`, `ripgrep`, `lazygit`, `fd`, `tree-sitter`, `git-lfs`, `btop`, `dust`, `superfile`, `gum`, `gh`
- Development: `neovim` (AppImage; glibc-aware source repo), GNU `stow` (built from source), LazyVim starter, `juliaup`
- Repositories: clones [Omarchy](https://github.com/basecamp/omarchy) to `~/.local/share/omarchy`

**2. Apply configurations:**

```bash
~/dotfiles/bin/dotfiles-apply-replica.sh
```

Applies configurations using a hybrid approach:

- Manual symlinks: Julia config, tmux config, individual files
- Stow integration: Neovim config (merges with LazyVim using `--adopt`)
- Bashrc sourcing: Ensures custom shell configuration loads

Features:

- Idempotent installations with version checking
- Conditional Neovim installation based on glibc version
- GitHub rate limit handling with helpful error messages
- Safe conflict resolution and backup creation

Tree-sitter may not work correctly due to some glibc stuff. If there are many errors in nvim, we can build from source.

1. install rust 'curl --proto '=https' --tlsv1.2 -sSf <https://sh.rustup.rs> | sh'
2. 'cargo install tree-sitter-cli --no-default-features'

Using `--no-default-features` to avoid errors with quickJS or something(?).

#### Local Package Management

```bash
~/dotfiles/bin/dotfiles-setup-packages.sh
```

Comprehensive package management for Omarchy systems:

- **Removes:** Selected Omarchy webapps (HEY, Basecamp, WhatsApp, etc.)
- **Installs:** Essential tools (zotero-bin, cursor-bin, discord, tmux, etc.)
- **Sets up:** Julia environment, tmux plugin manager, Zotero extensions
- **Configures:** LaTeX distribution (texlive-meta)

#### Edit your configuration

Edit files under profile directories and re-run the apply script. Hyprland changes are reloaded automatically.

#### Restore Omarchy defaults

```bash
~/.local/share/omarchy/bin/omarchy-refresh-config hypr/bindings.conf
```

### Development Environment

#### Julia Environment Setup

```bash
~/dotfiles/bin/julia-setup.jl
```

Installs essential Julia packages to your global environment:

- **Development:** Revise, Debugger, Cthulhu, PkgTemplates
- **Performance:** BenchmarkTools, BasicAutoloads
- **Utilities:** DrWatson, ProgressMeter, OhMyREPL, Reexport

#### Julia Package Manager as App (Experimental)

Install the Julia package manager as a standalone app for faster package operations:

1. Start Julia REPL
2. Enter package mode by pressing `]`
3. Run: `app add https://github.com/JuliaLang/Pkg.jl/tree/pkg-app`

This experimental feature allows Pkg to be used as a standalone application.

## Remote Access & Sync

### SSH Connection with tmux

```bash
~/dotfiles/bin/dotfiles-ssh-tmux.sh
```

Interactive SSH connection manager with automatic tmux session handling:

- **Server selection:** Choose from predefined servers using fuzzy finder
- **Session management:** Automatically attaches to existing tmux sessions or creates new ones
- **Servers supported:** atalanta, abacus-as, abacus-min, nam-shub-01/02, bioint01-04

### Directory Synchronization

```bash
# Basic usage - sync studies from atalanta
~/dotfiles/bin/dotfiles-rsync-ssh.sh

# Sync from different host
~/dotfiles/bin/dotfiles-rsync-ssh.sh --from bioint01

# Custom directories
~/dotfiles/bin/dotfiles-rsync-ssh.sh \
  --source-dir ~/projects \
  --target-dir ~/local-backup

# Full example
~/dotfiles/bin/dotfiles-rsync-ssh.sh \
  --from atalanta \
  --source-dir ~/Code/DRL_RDE/data/studies \
  --target-dir ~/synced-studies
```

Features:

- **Interactive selection:** Choose multiple directories to sync
- **Host inventory:** Machines and groups come from [`hosts.toml`](hosts.toml); jump hosts live in `~/.ssh/config` (`ProxyJump`)
- **Progress tracking:** Real-time sync progress with numbered operations
- **Safe syncing:** Uses `rsync` with delete protection and incremental transfers

### SSHFS Remote Mounts

Interactive TUI for managing SSHFS mounts via **system** systemd units (sudo
required). Filesystem inventory is read from [`hosts.toml`](hosts.toml) at the repo
root; each entry gets a paired `.mount` + `.automount` under
`/etc/systemd/system/`. The automount unit holds an autofs trigger at the mount
point: the real SSHFS `.mount` starts on first access and **idle-unmounts** after 10
minutes by default, so `ls /mnt` without entering subdirectories does not hang on
unreachable remotes.

**Interactive management:**

```bash
~/dotfiles/bin/dotfiles-mounts.sh    # Toggle mounts with gum TUI (sudo)
dotfiles-mounts -l                   # List current status (no sudo)
dotfiles-mounts -e <name>            # Enable mount(s)
dotfiles-mounts -d <name>            # Disable mount(s)
```

**Filesystems** are declared in `hosts.toml` either as `[machines.<alias>]`
with `remote_path` + `local_path`, or as `[groups.<name>]` with `mount_via`,
`remote_path`, and `local_path` (one mount per shared filesystem).

SSH runs as root for the fuse mount, so the script wires the real user’s
`~/.ssh/config`, identity file, and `known_hosts` into the unit (see
`SSHFS_IDENTITY_FILE`). On the host, **`user_allow_other`** must be enabled in
`/etc/fuse.conf` for `allow_other` to work.

**Features:**

- **On-access mounting:** systemd `.automount` + `delay_connect` SSHFS
- **Idle expiry:** `SSHFS_IDLE_SEC` (default 600) frees stuck remotes from global directory listings
- **Auto-reconnect:** `reconnect` after sleep/network drops
- **Bandwidth-efficient:** `compression=yes`
- **Safe listing:** Parent paths like `/mnt` avoid `stat()` on idle child mountpoints

If `cd /mnt/foo` yields **Input/output error** while the directory shows mode
`----------` (`d---------`), fix permissions **while the SSHFS unit is stopped**
then re-enable the automount, e.g. `sudo systemctl stop 'mnt-uio\x2dmath.mount'`,
`sudo chmod 755 /mnt/foo`, `sudo chown "$USER:$USER" /mnt/foo`, then
`sudo systemctl start 'mnt-uio\x2dmath.automount'` (or disable/enable from
`dotfiles-mounts.sh`). New enables set `0755` and your user on the mountpoint.

### SSH Key Management

```bash
~/dotfiles/bin/dotfiles-setup-ssh.sh
```

Automated SSH key distribution:

- **Key validation:** Checks for existing ed25519 key
- **Agent management:** Adds key to ssh-agent if not present
- **Multi-server setup:** Copies public key to all configured servers
- **Servers:** abacus-as/min, nam-shub-01/02, bioint01-04, uio

**SSH Agent Setup:** Enable automatic SSH agent startup with `systemctl --user enable --now ssh-agent.socket` to enable automatic key loading and agent forwarding.

### Git commit signing (SSH)

```bash
~/dotfiles/bin/dotfiles-setup-git-signing.sh
```

Sets up global SSH commit signing (`gpg.format ssh`, signing key path, `allowed_signers`) and can register the public key on GitHub as a signing key via `gh`. Use after your SSH key exists; verify commits with `git log --show-signature`.

## Application Setup

### Zotero Better BibTeX Extension

```bash
~/dotfiles/bin/dotfiles-setup-zotero.sh
```

Automated Zotero extension installer:

- **Latest version:** Downloads current Better BibTeX release from GitHub
- **Safe download:** Validates file integrity before installation
- **User guidance:** Provides step-by-step manual installation instructions

Note: Manual installation through Zotero GUI is required for proper extension registration.

## System Configuration

### Power Management

```bash
# Configure power button for suspend
~/dotfiles/bin/dotfiles-power-suspend.sh

# Power profile menu (now uses omarchy-menu power)
```

**Power button configuration:**

- Creates systemd logind drop-in configuration
- Options: reboot system, restart services, or apply on next reboot

**Power profile menu:**

- Uses `omarchy-menu power` (integrated with omarchy system)
- Interactive selection using `walker` with consistent styling
- Integrates with `powerprofilesctl` for profile switching

## Backup & Restore

### Firefly III Database Management

```bash
# Create backup
~/dotfiles/bin/dotfiles-firefly-backup.sh

# Create backup to specific directory
~/dotfiles/bin/dotfiles-firefly-backup.sh ~/my-backup-location

# Restore from backup
~/dotfiles/bin/dotfiles-firefly-restore.sh ~/Firefly3/backup/20240120-143022
```

**Backup features:**

- **Complete backup:** Files (tarball) + MariaDB database dump
- **Timestamped:** Automatic backup directory naming
- **Configurable:** Custom backup destinations supported

**Restore features:**

- **Full restoration:** Database + configuration files
- **Docker integration:** Automatic container management
- **Validation:** Checks backup integrity before restoration

## Requirements

### Local Development

- GNU Stow (for linking configs)
- `gum` (for interactive conflict resolution - install with `pacman -S gum`)
  - `gum` is installed by default in [Omarchy](https://omarchy.org)
- Arch with `yay` (for the package setup script)
- `curl` (for optional installers)
- Hyprland (only if you want the Hypr configs; the apply script tries to `hyprctl reload` if present)
- `rsync` (for directory synchronization)
- `docker` and `docker-compose` (for Firefly III backup/restore)
- `walker` (for power profile menu)
- `powerprofilesctl` (for power management)

### University Servers

- `curl` (for downloading prebuilt binaries)
- `tar`, `gunzip` (for extracting archives)
- `git` (for cloning repositories)
- RHEL/CentOS compatible system
- No sudo access required
- Optional: GitHub token for API rate limits

## Features

### Custom Hyprland Configuration

- **Window management:** Enhanced resizing with `SUPER + minus/plus` (horizontal) and `SUPER + SHIFT + minus/plus` (vertical)
- **Floating windows:** `SUPER + SHIFT + arrows` for precise positioning
- **Quick launchers:** Fast app access (browser, terminal, Obsidian, Spotify, etc.) via UWSM
- **Workspace rules:** Automatic app placement (e.g., `cursor` → workspace 2, `obsidian` → workspace 9)
- **Environment extension:** Includes Omarchy tools in `PATH` via `envs.conf`

### Profile System

- **Multiple profiles:** Support for different configurations (bengal, kaspi, sibir, etc.)
- **Overlay architecture:** Profile-specific files override defaults while preserving base configuration
- **Easy switching:** Change profiles with a single command argument

### Interactive Tools

- **Conflict resolution:** Smart handling of existing dotfiles with user choice prompts
- **Server selection:** Fuzzy-finding interface for SSH connections
- **Multi-selection:** Choose multiple directories for synchronization
- **Progress tracking:** Real-time feedback for long-running operations

## How It Works

### Local Development

The configuration system uses a layered approach:

1. **Base layer:** `default/` package provides core configurations
2. **Profile layer:** Optional profile packages (e.g., `bengal/`) overlay the base
3. **Conflict detection:** Dry-run analysis before applying changes
4. **Interactive resolution:** User choice for handling conflicts:
   - **Adopt:** Move existing files to dotfiles repo (via `stow --adopt`)
   - **Abort:** Keep existing files, skip linking
5. **Automatic reload:** Hyprland configuration refreshes after changes

### University Server Setup

The replica setup uses a two-stage approach:

1. **Tool Installation (`setup-replica.sh`):**
   - Downloads prebuilt binaries from GitHub releases
   - Installs to `~/.local/bin` (no sudo required)
   - Handles version checking and idempotent updates
   - Sets up development environment (Neovim + LazyVim)

2. **Configuration Application (`apply-replica.sh`):**
   - Manual symlinks for simple configs (Julia, tmux)
   - Stow integration for complex configs (Neovim with LazyVim merge)
   - Bashrc sourcing integration for shell customizations

### Troubleshooting University Servers

**GitHub Rate Limits (403 errors):**

- Set `GITHUB_TOKEN` environment variable
- Get token from <https://github.com/settings/tokens>
- No special permissions needed

**Bash Profile Issues:**

- Add `[[ -f ~/.bashrc ]] && source ~/.bashrc` to `~/.bash_profile`
- Ensures custom configs load in SSH sessions

**Tree-sitter Errors in Neovim:**

- Check `:checkhealth nvim-treesitter` in Neovim
- Verify `tree-sitter` CLI is in PATH: `which tree-sitter`
- Install parsers manually: `:TSInstall latex`

## Notes

- **Environment variables:** Changes to Hyprland's `envs.conf` require a full Hyprland restart to take effect
- **Profile isolation:** Each profile can completely override base configurations using `--override` flag
- **Backup safety:** All backup operations include integrity validation before restoration
- **Jump host routing:** Bioint servers are automatically accessed through atalanta gateway
