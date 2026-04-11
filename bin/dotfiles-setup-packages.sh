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
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        "$fn" "$line"
    done <"$file"
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

        # Ask if user wants to enable SSH using gum
        if command -v gum >/dev/null 2>&1; then
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

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0

Prune selected Omarchy webapps/packages and install the package set used on this machine
(yay, interactive where needed). No arguments.
EOF
        exit 0
    fi

    ensure_cmd yay

    # 1) Remove webapps
    read_list_file "$PACKAGE_LISTS_DIR/webapps-remove.txt" remove_webapp

    # 2) Remove packages
    read_list_file "$PACKAGE_LISTS_DIR/packages-remove.txt" remove_pkg

    # 3) Install packages (Node dev env first, then list; Television + Zotero after packages)
    omarchy-install-dev-env node
    read_list_file "$PACKAGE_LISTS_DIR/packages-install.txt" install_pkg
    setup_github_cli_extensions
    setup_television
    if pkg_installed zotero-bin; then
        log_info "Setting up Zotero extensions..."
        "$HOME/dotfiles/bin/dotfiles-setup-zotero.sh" || log_info "Zotero setup failed (non-critical)"
    fi

    # 4) Install LaTeX templates
    install_latex_template \
        "UiO Beamer Theme" \
        "https://www.mn.uio.no/ifi/tjenester/it/hjelp/latex/uiobeamer.zip" \
        "$HOME/texmf/tex/latex/beamer/uiobeamer" \
        "$HOME/texmf/tex/latex/beamer/uiobeamer/beamerthemeUiO.sty"

    # Setup development environment tools
    refresh_latex_database
    setup_tmux_tpm

    # Network and connectivity setup
    setup_tailscale
    setup_syncthing

    # Install tree-sitter from GitHub releases (Arch package is outdated)
    install_tree_sitter "$HOME/.local/bin" || log_warning "tree-sitter installation failed; continuing"

    # Install tools via curl installers
    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && ~/dotfiles/bin/julia-setup.jl"
    install_via_curl "cursor-cli" "cursor-agent" "https://cursor.com/install"

    # 5) Refresh desktop database (user apps)
    update-desktop-database ~/.local/share/applications/ || true

    log_info "Done."
}

main "$@"
