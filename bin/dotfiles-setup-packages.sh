#!/bin/bash
set -Eeuo pipefail

# Omarchy prune/install script
# - Removes selected default webapps and packages
# - Installs requested packages (lists under bin/package-lists/)
# - Refreshes application launchers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

PACKAGE_LISTS_DIR="$SCRIPT_DIR/package-lists"

OMARCHY_BIN="$HOME/.local/share/omarchy/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

# Read a list file: one entry per line; skip empty lines and lines whose first non-whitespace char is #.
# Second argument is the name of a function invoked once per line: fn "$line"
read_list_file() {
    local file="$1"
    local fn="$2"
    if [[ ! -f "$file" ]]; then
        log_error "Missing package list: $file"
        exit 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        "$fn" "$line"
    done <"$file"
}

# Print one installable package name per line (same skip rules as read_list_file).
list_packages_from_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "Missing package list: $file"
        exit 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        printf '%s\n' "$line"
    done <"$file"
}

# Return 0 if $1 is a line in newline-separated list $2.
line_in_list() {
    local needle="$1"
    local haystack="$2"
    grep -qxF "$needle" <<<"$haystack"
}

remove_webapp() {
    local name="$1"
    if [[ -f "$DESKTOP_DIR/$name.desktop" ]]; then
        log_info "Removing web app: $name"
        "$OMARCHY_BIN/omarchy-webapp-remove" "$name" || true
    else
        log_info "Skip web app (not found): $name"
    fi
}

pkg_installed() { yay -Qi "$1" >/dev/null 2>&1; }

remove_pkg() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        log_info "Removing package: $pkg"
        yay -Rns --noconfirm "$pkg" || true
    else
        log_info "Skip package (not installed): $pkg"
    fi
}

install_pkg() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        log_info "Already installed: $pkg"
    else
        log_info "Installing package: $pkg"
        yay -Sy --noconfirm "$pkg"
    fi
}

install_latex_template() {
    local name="$1"
    local url="$2"
    local target_dir="$3"
    local check_file="$4"

    if [[ -f "$check_file" ]]; then
        log_info "LaTeX template $name already installed; skipping"
        return 0
    fi

    log_info "Installing LaTeX template: $name"

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download and extract
    curl -fsSL -o template.zip "$url"
    unzip -q template.zip

    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"

    # Copy files to target directory
    cp -r * "$target_dir/"

    # Clean up
    cd - >/dev/null
    rm -rf "$temp_dir"

    log_info "LaTeX template $name installed successfully"
}

refresh_latex_database() {
    # Refresh LaTeX file database so it can find newly installed templates
    if command -v mktexlsr >/dev/null 2>&1; then
        log_info "Refreshing LaTeX file database..."
        mktexlsr "$HOME/texmf" || log_warning "Warning: Could not refresh LaTeX file database"
    else
        log_info "mktexlsr not found; skipping LaTeX database refresh"
    fi
}

setup_tmux_tpm() {
    # Setup tmux plugin manager (tpm)
    if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
        log_info "Installing tmux plugin manager..."
        mkdir -p "$HOME/.tmux/plugins"
        git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
    else
        log_info "tpm already installed at $HOME/.config/tmux/plugins/tpm; skipping clone"
    fi
}

setup_tailscale() {
    # Install and configure Tailscale
    log_info "Setting up Tailscale..."

    # Check if Tailscale is already installed
    if command -v tailscale >/dev/null 2>&1; then
        log_info "Tailscale already installed and configured; skipping setup"
    else
        log_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh

        log_info "Starting Tailscale connection..."
        sudo tailscale up

        # Ask if user wants to enable SSH using gum (skipped in unattended --all runs)
        if [[ "${DOTFILES_SETUP_UNATTENDED:-0}" == "1" ]]; then
            log_info "Unattended mode; skipping Tailscale SSH prompt"
            log_info "To enable SSH later, run: tailscale set --ssh"
        elif command -v gum >/dev/null 2>&1; then
            if gum confirm "Enable Tailscale SSH access to this machine?"; then
                log_info "Enabling Tailscale SSH..."
                tailscale set --ssh
                log_success "Tailscale SSH enabled successfully"
            else
                log_info "Skipping Tailscale SSH setup"
            fi
        else
            log_warning "gum not available; skipping SSH setup choice"
            log_info "To enable SSH later, run: tailscale set --ssh"
        fi

        log_success "Tailscale setup completed"
    fi
}

setup_syncthing() {
    # Setup Syncthing service
    log_info "Setting up Syncthing..."

    if ! pkg_installed syncthing; then
        log_warning "Syncthing package not installed; skipping service setup"
        return 0
    fi

    # Enable and start syncthing user service
    log_info "Enabling Syncthing user service..."
    systemctl --user enable syncthing.service
    systemctl --user start syncthing.service

    log_success "Syncthing service enabled and started"
    log_info "Web UI available at: http://localhost:8384"
}

setup_television() {
    local tv_cable_dir="$HOME/.config/television/cable"

    if ! command -v tv >/dev/null 2>&1; then
        log_warning "tv not on PATH; skipping update-channels"
        return 0
    fi
    if ! tv --version >/dev/null 2>&1; then
        log_warning "tv command not working; skipping update-channels"
        return 0
    fi

    if [[ ! -d "$tv_cable_dir" ]]; then
        log_info "Creating Television cable directory..."
        mkdir -p "$tv_cable_dir"
        log_info "Updating Television channels..."
    elif [[ -n "$(find "$tv_cable_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
        log_info "Television cable dir already populated; skipping update-channels"
        return 0
    else
        log_info "Television cable dir is empty; updating channels..."
    fi

    tv update-channels || log_warning "tv update-channels failed (non-critical)"
}

setup_github_cli_extensions() {
    if ! command -v gh >/dev/null 2>&1; then
        log_warning "gh not on PATH; skipping GitHub CLI extensions"
        return 0
    fi

    if ! gh auth status -h github.com >/dev/null 2>&1; then
        log_info "gh not authenticated for github.com; run 'gh auth login' for full API access (extensions can still be installed)"
    fi

    local ext
    for ext in dlvhdr/gh-dash dlvhdr/gh-enhance; do
        if gh extension list 2>/dev/null | grep -qF "$ext"; then
            log_info "gh extension already installed: $ext"
        else
            log_info "Installing gh extension: $ext"
            gh extension install "$ext" || log_warning "Failed to install gh extension: $ext (non-critical)"
        fi
    done
}

# https://github.com/marcosnils/bin — bootstrap via AUR bin-bin, self-install, then drop the package.
setup_marcosnils_bin() {
    INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

    if command -v bin >/dev/null 2>&1 && ! pkg_installed bin-bin; then
        log_info "marcosnils/bin already on PATH; skipping AUR bootstrap"
        ensure_marcos_bin_config_default_path || true
        return 0
    fi

    if ! pkg_installed bin-bin; then
        log_info "Installing bin-bin (AUR) to bootstrap marcosnils/bin"
        install_pkg bin-bin
    fi

    if ! command -v bin >/dev/null 2>&1; then
        log_error "bin not on PATH after installing bin-bin"
        return 1
    fi

    ensure_marcos_bin_config_default_path || true

    log_info "Installing marcosnils/bin via bin (self-manage)"
    bin install github.com/marcosnils/bin || {
        log_error "marcosnils/bin self-install failed"
        return 1
    }

    if pkg_installed bin-bin; then
        log_info "Removing AUR bootstrap package bin-bin"
        remove_pkg bin-bin
    fi

    log_success "marcosnils/bin ready"
}

# Single source of truth: menu label and bash function name gum returns (label:function).
# Order here is the safe execution order; gum selection order is ignored.
SETUP_STEPS=(
    'Remove webapps:step_remove_webapps'
    'Remove packages:step_remove_packages'
    'Install Node dev env:step_install_node'
    'Install packages:step_install_packages'
    'Install GitHub CLI extensions:step_install_gh_extensions'
    'Setup marcosnils/bin:step_setup_marcosnils_bin'
    'Setup Television:step_setup_television'
    'Zotero setup:step_setup_zotero'
    'LaTeX templates:step_latex_templates'
    'Setup tmux TPM:step_setup_tmux_tpm'
    'Setup Tailscale:step_setup_tailscale'
    'Setup Syncthing:step_setup_syncthing'
    'Install tree-sitter:step_install_tree_sitter'
    'Setup Julia (juliaup):step_setup_julia'
)

install_packages_from_gum() {
    local list_file="$PACKAGE_LISTS_DIR/packages-install.txt"
    local -a pkg_lines=()
    local selected

    mapfile -t pkg_lines < <(list_packages_from_file "$list_file")
    if [[ ${#pkg_lines[@]} -eq 0 ]]; then
        log_warning "No packages listed in $list_file; skipping installs."
        return 0
    fi

    if ! selected=$(
        printf '%s\n' "${pkg_lines[@]}" | gum choose --no-limit --selected='*' \
            --header="Select packages to install (tab toggles, enter confirms)"
    ); then
        return 1
    fi
    if [[ -z "${selected//[$'\t\r\n ']/}" ]]; then
        log_info "No packages selected; skipping package installs."
        return 0
    fi

    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        [[ -z "${pkg// /}" ]] && continue
        install_pkg "$pkg"
    done <<<"$selected"
}

step_remove_webapps() {
    read_list_file "$PACKAGE_LISTS_DIR/webapps-remove.txt" remove_webapp
}

step_remove_packages() {
    read_list_file "$PACKAGE_LISTS_DIR/packages-remove.txt" remove_pkg
}

step_install_node() {
    omarchy-install-dev-env node
}

step_install_packages() {
    if [[ "${DOTFILES_SETUP_UNATTENDED:-0}" == "1" ]]; then
        read_list_file "$PACKAGE_LISTS_DIR/packages-install.txt" install_pkg
    else
        install_packages_from_gum || return 1
    fi
}

step_install_gh_extensions() {
    setup_github_cli_extensions
}

step_setup_marcosnils_bin() {
    setup_marcosnils_bin || log_warning "marcosnils/bin setup failed; continuing"
}

step_setup_television() {
    setup_television
}

step_setup_zotero() {
    if pkg_installed zotero-bin; then
        log_info "Setting up Zotero extensions..."
        "$HOME/dotfiles/bin/dotfiles-setup-zotero.sh" || log_info "Zotero setup failed (non-critical)"
    fi
}

step_latex_templates() {
    install_latex_template \
        "UiO Beamer Theme" \
        "https://www.mn.uio.no/ifi/tjenester/it/hjelp/latex/uiobeamer.zip" \
        "$HOME/texmf/tex/latex/beamer/uiobeamer" \
        "$HOME/texmf/tex/latex/beamer/uiobeamer/beamerthemeUiO.sty"
    refresh_latex_database
}

step_setup_tmux_tpm() {
    setup_tmux_tpm
}

step_setup_tailscale() {
    setup_tailscale
}

step_setup_syncthing() {
    setup_syncthing
}

step_install_tree_sitter() {
    if ! command -v bin >/dev/null 2>&1; then
        log_error "marcosnils/bin ('bin') not on PATH. Run the 'Setup marcosnils/bin' step first, or install https://github.com/marcosnils/bin manually."
        return 1
    fi
    ensure_cmd jq
    marcos_bin_install_or_update_github "github.com/tree-sitter/tree-sitter" "tree-sitter"
}

step_setup_julia() {
    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && ~/dotfiles/bin/julia-setup.jl"
}

all_main_step_keys() {
    local entry
    for entry in "${SETUP_STEPS[@]}"; do
        printf '%s\n' "${entry#*:}"
    done
}

pick_main_steps() {
    local selected=""
    if ! selected=$(
        printf '%s\n' "${SETUP_STEPS[@]}" | gum choose --no-limit --selected='*' --label-delimiter=':' \
            --header="Select setup steps (tab toggles, enter confirms)"
    ); then
        return 1
    fi
    if [[ -z "${selected//[$'\t\r\n ']/}" ]]; then
        log_error "No setup steps selected; aborting."
        return 1
    fi
    printf '%s' "$selected"
}

run_selected_steps() {
    local steps="$1" entry fn
    for entry in "${SETUP_STEPS[@]}"; do
        fn="${entry#*:}"
        line_in_list "$fn" "$steps" || continue
        if ! declare -F "$fn" >/dev/null; then
            log_error "Missing step function: $fn"
            return 1
        fi
        "$fn"
    done
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0 [--all]

Prune selected Omarchy webapps/packages and install the package set used on this machine
(yay). By default, uses gum to select which steps (and which packages) to run.

  --all   Run every step and install all packages from the list; no menus (non-interactive).
EOF
        exit 0
    fi

    DOTFILES_SETUP_UNATTENDED=0
    if [[ "${1:-}" == "--all" ]]; then
        DOTFILES_SETUP_UNATTENDED=1
        shift
    fi

    if [[ -n "${1:-}" ]]; then
        log_error "Unknown argument: $1"
        exit 1
    fi

    ensure_cmd yay

    local steps=""

    if [[ "$DOTFILES_SETUP_UNATTENDED" == "1" ]]; then
        steps=$(all_main_step_keys) || {
            log_error "Failed to build step list"
            exit 1
        }
    else
        ensure_cmd gum
        if ! steps=$(pick_main_steps); then
            log_error "Setup step selection cancelled or failed."
            exit 1
        fi
    fi

    run_selected_steps "$steps"

    update-desktop-database ~/.local/share/applications/ || true

    log_info "Done."
}

main "$@"
