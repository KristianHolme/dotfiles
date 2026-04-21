#!/usr/bin/env bash
set -Eeuo pipefail

# Applies omarchy-tweaks configs for university servers:
# - Stows default/dot-config into ~/.config (nvim, tmux, starship, hypr, etc.)
# - Creates symlink for Julia config (~/.julia/config)
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

# Stow the whole default/dot-config tree into ~/.config (--adopt helps merge existing plain files).
stow_dot_config_into_xdg() {
    local dotfiles_dir="$HOME/dotfiles"
    local original_pwd="$PWD"

    cd "$dotfiles_dir" || {
        log_error "Failed to cd to $dotfiles_dir"
        return 1
    }

    log_info "Stowing default/dot-config into \$HOME/.config (first with --adopt if existing files conflict)..."
    if stow -d default -t "$HOME/.config" --dotfiles -S dot-config --adopt -v; then
        log_success "Stowed dot-config into ~/.config"
    else
        log_warning "Stow with --adopt failed; retrying without --adopt"
        if stow -d default -t "$HOME/.config" --dotfiles -S dot-config -v; then
            log_success "Stowed dot-config into ~/.config"
        else
            log_error "Failed to stow dot-config"
            cd "$original_pwd" || true
            return 1
        fi
    fi

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

Apply dotfiles on a restricted server: stow default/dot-config into ~/.config,
Julia config symlink, bashrc hook, omarchy clone. Uses env OMARCHY_DIR,
OMARCHY_REPO_URL.
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

    setup_julia_config
    stow_dot_config_into_xdg || {
        log_error "dot-config stow failed; aborting"
        exit 1
    }

    remove_legacy_home_tmux_conf_symlink

    # Ensure our bashrc is sourced from server's ~/.bashrc
    ensure_bashrc_source

    log_info "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
