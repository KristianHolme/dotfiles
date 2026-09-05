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

# Export GUM_* from the staged theme's gum_env.lua. Works on replicas without
# Omarchy; falls back to omarchy-restart-gum on a desktop install.
omarchy_gum_env_load() {
    local gum_env="${HOME}/.local/state/omarchy/current/theme/gum_env.lua"
    local key value
    if [[ -f $gum_env ]]; then
        while IFS=$'\t' read -r key value; do
            [[ -n $key && -n $value ]] && export "${key}=${value}"
        done < <(awk -F'"' '/hl\.env\("[A-Z0-9_]+", "[^"]+"\)/ { print $2 "\t" $4 }' "$gum_env")
        return 0
    fi
    if command -v omarchy-restart-gum >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source omarchy-restart-gum
    fi
}
