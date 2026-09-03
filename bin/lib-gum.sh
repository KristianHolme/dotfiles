#!/usr/bin/env bash
#
# gum CLI theme helpers for Omarchy.
# Sourced from ~/.bashrc and lib-dotfiles.sh:
#   source "$HOME/dotfiles/bin/lib-gum.sh"
#   omarchy_gum_env_load

if [[ -n "${LIB_GUM_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_GUM_SH_SOURCED=1

# Export GUM_* from the active theme. Hyprland injects gum_env.lua at login
# only; omarchy-restart-gum re-reads
# ~/.local/state/omarchy/current/theme/gum_env.lua so a theme switch is
# visible in already-open terminals. No-op when Omarchy is not installed.
omarchy_gum_env_load() {
    if command -v omarchy-restart-gum >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source omarchy-restart-gum
    fi
}
