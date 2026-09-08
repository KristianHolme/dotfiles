---
name: dotfiles-omarchy-setup
description: Instructions for updating system configuration. Use when modifying dotfiles, Hyprland/Wayland configs, system configs, Cursor skills, or other configurations that typically live in ~/.config inside ~/dotfiles. This system uses omarchy at /usr/share/omarchy (and ~/.local/share/omarchy); read-only access there is allowed for understanding commands and idiomatic usage, but never edit files there.
---

# Dotfiles Setup

## Quick Start

1. Identify the target area in `~/dotfiles/`.
2. Edit files in the stow structure under `~/dotfiles/` only.
3. Omarchy package files live in `/usr/share/omarchy/` (scripts/configs); `~/.local/share/omarchy` may still exist. Read-only access is OK for understanding commands and idioms, but do not edit.
4. When working with omarchy-related tasks, invoke the omarchy skill: `@omarchy`
5. Do not commit unless explicitly asked.

## Workflow Checklist

- [ ] Determine scope within `~/dotfiles/` only.
- [ ] Edit `default/` (the only stow package). Host-specific Hyprland goes in Lua:
  - `default/dot-config/hypr/monitors.lua` branches on `/etc/hostname` and connected monitor descriptions
  - `default/dot-config/nvim/lua/plugins/jetls.lua` disables JETLS on hostname `kaspi`
- [ ] Locate the config:
  - Hyprland: `dot-config/hypr/*.lua` (plus `hyprsunset.conf`)
  - Omarchy shell / idle: `dot-config/omarchy/shell.json`
  - Cursor: `dot-config/Cursor/User/`
  - Shell utilities: `bin/`
  - Other app configs: `dot-config/` (e.g. `dot-config/tmux/`), `dot-local/`, `dot-ssh/`, etc.
- [ ] Make minimal, targeted edits with clear intent.
- [ ] When working with omarchy-related tasks, invoke the omarchy skill: `@omarchy`
- [ ] Apply changes via existing dotfiles apply tooling or stow when necessary.
- [ ] Avoid creating tests or example files unless explicitly asked.
- [ ] Do not commit or amend unless explicitly requested.

## Notes on Stow Layout

- Dotfiles are stored in package directories (e.g., `default/`) using `dot-` prefix for home files and `dot-config/` for `~/.config`.
- The Cursor skills path is stowed from `default/dot-cursor/skills/` to `~/.cursor/skills/`.
- Omarchy files and scripts live at `/usr/share/omarchy/`; read-only access is OK for understanding the system.
- **Local-only generated files** (app lockfiles, package-manager plugins, etc.) must not live in dotfiles. Stow uses `--no-folding` so config dirs are symlinked file-by-file. Reset links with `dac -- -D`, then re-apply with `dac`.

## Examples

**Hyprland config change**

- Shared bindings: `~/dotfiles/default/dot-config/hypr/bindings.lua`
- Monitors / host layouts: `~/dotfiles/default/dot-config/hypr/monitors.lua`
- Apply with `dac`, then `hyprctl reload` and `hyprctl configerrors`.

**Cursor settings change**

- Edit `~/dotfiles/default/dot-config/Cursor/User/settings.json`
- Apply changes using the existing dotfiles apply workflow.

ALWAYS run `hyprctl configerrors` after changing hyprland configs, to check if there are any errors.

**Omarchy integration (dotfiles-only)**

- If dotfiles reference omarchy paths or scripts, update those references in `~/dotfiles/` only.
- Replicas do not clone Omarchy. Theme sync rsyncs the locally staged theme (`~/.local/state/omarchy/current/theme`) and applies terminal/tmux/neovim hooks via `dotfiles-theme-sync-remote.sh` (nvim needs `~/.config/nvim/lua/plugins/theme.lua` → staged `neovim.lua`, or LazyVim stays on tokyonight while the terminal is already themed).
