#!/usr/bin/env bash
#
# gum CLI theme helpers for Omarchy.
# Sourced from ~/.bashrc and dotfiles scripts:
#   source "$HOME/dotfiles/bin/lib-gum.sh"
#   omarchy_gum_env_load

if [[ -n "${LIB_GUM_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_GUM_SH_SOURCED=1

# Load GUM_* exports from the active Omarchy theme (Hyprland-format gum.env.conf).
# Hyprland injects these for new app spawns; long-lived Ghostty keeps stale env.
# Re-source ~/.bashrc after changing theme.
omarchy_gum_env_load() {
    local conf="${HOME}/.config/omarchy/current/theme/gum.env.conf"
    [[ -f "$conf" ]] || return 0

    while IFS= read -r line; do
        [[ "$line" =~ ^env[[:space:]]*=[[:space:]]*([^,]+),(.+)$ ]] || continue
        export "${BASH_REMATCH[1]// /}=${BASH_REMATCH[2]// /}"
    done <"$conf"
}
