---
name: dotfiles-omarchy-setup
description: Instructions for updating system configuration. Use when modifying dotfiles, Hyprland/Wayland configs, system configs, Cursor skills, or other configurations that typically live in ~/.config inside ~/dotfiles. This system uses omarchy at ~/.local/share/omarchy; read-only access there is allowed for understanding commands and idiomatic usage, but never edit files there.
---

# Dotfiles Setup

## Quick Start

1. Identify the target area in `~/dotfiles/`.
2. Edit files in the stow structure under `~/dotfiles/` only.
3. Omarchy lives in `~/.local/share/omarchy/` (scripts/configs); read-only access is OK for understanding commands and idioms, but do not edit.
4. When working with omarchy-related tasks, invoke the omarchy skill: `@omarchy`
5. Do not commit unless explicitly asked.

## Workflow Checklist

- [ ] Determine scope within `~/dotfiles/` only.
- [ ] Select the correct profile in `~/dotfiles/`:
  - `default/` for shared defaults
  - Host-specific: `bengal/`, `kaspi/`, `sibir/`, `sibir2/` as needed
- [ ] Locate the config:
  - Hyprland: `dot-config/hypr/`
  - Cursor: `dot-config/Cursor/User/`
  - Shell utilities: `bin/`
  - Other app configs: `dot-config/` (e.g. `dot-config/tmux/`), `dot-local/`, `dot-ssh/`, etc.
- [ ] Make minimal, targeted edits with clear intent.
- [ ] Omarchy is located at `~/.local/share/omarchy/` (scripts/configs); read-only access is OK, but never edit.
- [ ] When working with omarchy-related tasks, invoke the omarchy skill: `@omarchy`
- [ ] Apply changes via existing dotfiles apply tooling or stow when necessary.
- [ ] Avoid creating tests or example files unless explicitly asked.
- [ ] Do not commit or amend unless explicitly requested.

## Notes on Stow Layout

- Dotfiles are stored in package directories (e.g., `default/`) using `dot-` prefix for home files and `dot-config/` for `~/.config`.
- The Cursor skills path is stowed from `default/dot-cursor/skills/` to `~/.cursor/skills/`.
- Omarchy files and scripts live at `~/.local/share/omarchy/`; read-only access is OK for understanding the system.
- **Local-only generated files** (app lockfiles, package-manager plugins, etc.) must not live in dotfiles. Stow uses `--no-folding` so config dirs are symlinked file-by-file, not as a single tree symlink.

## Examples

**Hyprland config change**

- Edit `~/dotfiles/default/dot-config/hypr/bindings.conf`
- If host-specific, edit the matching host directory instead.
- Apply changes using the existing dotfiles apply workflow.

**Cursor settings change**

- Edit `~/dotfiles/default/dot-config/Cursor/User/settings.json`
- Apply changes using the existing dotfiles apply workflow.

ALWAYS run `hyprctl configerrors` after changing hyprland configs, to check if there are any errors.

**Omarchy integration (dotfiles-only)**

- If dotfiles reference omarchy paths or scripts, update those references in `~/dotfiles/` only.
