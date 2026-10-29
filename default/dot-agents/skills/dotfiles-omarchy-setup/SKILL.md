---
name: dotfiles-omarchy-setup
description: Instructions for updating system configuration. Use when modifying dotfiles, Hyprland/Wayland configs, system configs, or other configurations that typically live in ~/.config inside ~/dotfiles. This system uses omarchy at /usr/share/omarchy (and ~/.local/share/omarchy); read-only access there is allowed for understanding commands and idiomatic usage, but never edit files there.
---

# Dotfiles Setup

- Edit only inside `~/dotfiles/default/`, the single stow package. Never edit `/usr/share/omarchy/` or `~/.local/share/omarchy`; read them to learn commands and idioms.
- For omarchy tasks, invoke the `omarchy` skill.
- Do not commit or amend unless asked. Do not add tests or example files unless asked.
- Make minimal, targeted edits.

## Layout

`dot-X` files map to `~/.X`; `dot-config/` maps to `~/.config`. Stow runs with `--no-folding`, so everything is symlinked file by file: each file under `default/` and its home path are the same file. Edit one path only.

| Area | Path under `default/` |
| --- | --- |
| Hyprland | `dot-config/hypr/*.lua`, `hyprsunset.conf` |
| Omarchy shell / idle | `dot-config/omarchy/shell.json` |
| Cursor | `dot-config/Cursor/User/` |
| Agent skills | `dot-agents/skills/` → `~/.agents/skills/` |
| Other apps | `dot-config/`, `dot-local/`, `dot-ssh/`, … |
| Shell utilities | `bin/` (repo root) |

Host-specific settings:

- Hyprland: `dot-config/hypr/monitors.lua` branches on `/etc/hostname` and connected monitor descriptions.
- Neovim: `dot-config/nvim/lua/plugins/jetls.lua` disables JETLS on hostname `kaspi`.

Generated, local-only files (app lockfiles, package-manager plugins) must not live in dotfiles.

## Apply

Run `dac`. To reset links: `dac -- -D`, then `dac`.

After changing Hyprland configs, always run `hyprctl reload` and `hyprctl configerrors`.

## Theme sync to replicas

Replicas do not clone Omarchy. `dotfiles-theme-sync-remote.sh` rsyncs the locally staged theme (`~/.local/state/omarchy/current/theme`) and applies terminal/tmux/neovim hooks.

- Neovim needs `~/.config/nvim/lua/plugins/theme.lua` → staged `neovim.lua`, or LazyVim stays on tokyonight. `autocmds.lua` finishes the apply (`highlight clear` + `background` + `colorscheme`) so groups like CursorLine do not survive a light→dark switch.
- UiO Herdr targets use the `uio` jump ControlMaster; theme sync needs no per-target master.
