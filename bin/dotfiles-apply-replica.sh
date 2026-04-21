#!/usr/bin/env bash
set -Eeuo pipefail

# Applies omarchy-tweaks configs for university servers:
# - Creates symlinks for: julia config, starship.toml
# - Uses stow for ~/.config (nvim, starship, tmux at ~/.config/tmux/tmux.conf, etc.)
# - Adds source line to server's ~/.bashrc for our dot-bashrc (idempotent)
# - Ensures omarchy repo is cloned/updated first
#
# Config via env vars:
#   OMARCHY_DIR       - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL  - git URL for omarchy (default: https://github.com/basecamp/omarchy)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"

# Ensure local bin is in PATH for tools like stow (idempotent)
case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) export PATH="$HOME/.local/bin${PATH:+:${PATH}}" ;;
esac

setup_julia_config() {
    local dotfiles_dir="$HOME/dotfiles/"
    local julia_config_source="$dotfiles_dir/default/dot-julia/config"
    local julia_config_target="$HOME/.julia/config"

    create_symlink_with_backup "$julia_config_source" "$julia_config_target" "Julia config"
}

setup_nvim_config() {
    local dotfiles_dir="$HOME/dotfiles"

    # Check if already stowed properly
    local test_file="$HOME/.config/nvim/lua/config/options.lua"
    if [[ -L "$test_file" ]]; then
        local link_target="$(readlink "$test_file")"
        if [[ "$link_target" == *"default/dot-config/nvim"* ]]; then
            log_info "Neovim config already stowed correctly; skipping"
            return 0
        fi
    fi

    log_info "Setting up Neovim config with stow..."

    # Change to dotfiles directory for stow
    local original_pwd="$PWD"
    cd "$dotfiles_dir" || {
        log_error "Failed to cd to dotfiles directory"
        return 1
    }

    # Stow dot-config into ~/.config (nvim + tmux + starship; coexists with LazyVim)
    if stow -d default -t "$HOME/.config" --dotfiles -S dot-config --adopt -v 2>/dev/null; then
        log_info "Successfully stowed nvim config"
    else
        log_warning "Stow failed, trying without --adopt"
        if stow -d default -t "$HOME/.config" --dotfiles -S dot-config 2>/dev/null; then
            log_info "Successfully stowed nvim config"
        else
            log_error "Failed to stow nvim config"
            cd "$original_pwd" || true
            return 1
        fi
    fi

    # Return to original directory
    cd "$original_pwd" || true
}

# tmux reads ~/.tmux.conf before XDG; remove only our old symlink so ~/.config/tmux/tmux.conf wins.
remove_legacy_home_tmux_conf_symlink() {
    local legacy="$HOME/.tmux.conf"
    local xdg_conf="$HOME/.config/tmux/tmux.conf"
    local repo_conf="$HOME/dotfiles/default/dot-config/tmux/tmux.conf"
    [[ -e "$xdg_conf" ]] || return 0
    [[ -L "$legacy" ]] || return 0
    if [[ "$(realpath "$legacy" 2>/dev/null)" == "$(realpath "$repo_conf" 2>/dev/null)" ]]; then
        log_info "Removing legacy ~/.tmux.conf (tmux uses ~/.config/tmux/tmux.conf via stow)"
        rm "$legacy"
    fi
}

ensure_bashrc_source() {
    local bashrc_path="$HOME/.bashrc"
    local source_line="source '$HOME/dotfiles/default/dot-bashrc'"

    # Check if already sourced
    if grep -qF "$source_line" "$bashrc_path" 2>/dev/null; then
        log_info "dot-bashrc already sourced in $bashrc_path; skipping"
        return 0
    fi

    log_info "Adding source line for dot-bashrc to $bashrc_path"
    printf '\n# Omarchy tweaks (added by dotfiles-apply-replica)\n%s\n' "$source_line" >>"$bashrc_path"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0

Apply dotfiles on a restricted server: stow nvim/tmux/starship, Julia config,
bashrc hook, omarchy clone. Uses env OMARCHY_DIR, OMARCHY_REPO_URL.
EOF
        exit 0
    fi

    ensure_cmd git stow curl

    # Ensure omarchy repo is available
    clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"

    # Run Julia setup only if Julia is already installed (installation happens in setup script)
    if command -v julia >/dev/null 2>&1; then
        log_info "Running Julia setup script"
        "$SCRIPT_DIR/julia-setup.jl" || log_warning "julia-setup.jl failed"
    else
        log_warning "Julia not found; install it via dotfiles-setup-replica.sh first"
    fi

    # Create symlinks for specific configs
    setup_julia_config
    setup_nvim_config

    remove_legacy_home_tmux_conf_symlink

    # Ensure our bashrc is sourced from server's ~/.bashrc
    ensure_bashrc_source

    log_info "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
