#!/usr/bin/env bash
set -Eeuo pipefail

# Robust Zotero plugin setup script
# Downloads and installs Zotero extensions from GitHub releases
#
# Usage:
#   ./dotfiles-setup-zotero.sh                 # Setup all configured plugins
#   ./dotfiles-setup-zotero.sh better-bibtex   # Setup specific plugin
#
# Plugin definitions live in packages.toml under [zotero.plugins.<key>].

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-install.sh"

PROFILE_DIR="$HOME/Zotero"
EXTENSIONS_DIR="$PROFILE_DIR/extensions"
DOWNLOADS_DIR="$HOME/Downloads"

zotero_available_plugins() {
    zotero_plugin_keys | tr '\n' ' '
}

parse_plugin_config() {
    local plugin_key="$1"

    export PLUGIN_DISPLAY_NAME="$(zotero_plugin_field "$plugin_key" display_name)"
    export PLUGIN_GITHUB_REPO="$(zotero_plugin_field "$plugin_key" github_repo)"
    export PLUGIN_SEARCH_PATTERN="$(zotero_plugin_field "$plugin_key" search_pattern)"
    export PLUGIN_EXTENSION_ID="$(zotero_plugin_field "$plugin_key" extension_id)"

    if [[ -z "$PLUGIN_DISPLAY_NAME" || -z "$PLUGIN_GITHUB_REPO" || -z "$PLUGIN_SEARCH_PATTERN" || -z "$PLUGIN_EXTENSION_ID" ]]; then
        log_error "Incomplete Zotero plugin config for: $plugin_key (see $(packages_toml_path))"
        return 1
    fi
}

check_plugin_installed() {
    local plugin_key="$1"
    parse_plugin_config "$plugin_key" || return 1

    if [[ -d "$EXTENSIONS_DIR" ]]; then
        if find "$EXTENSIONS_DIR" -name "*$PLUGIN_SEARCH_PATTERN*" -o -name "*$PLUGIN_EXTENSION_ID*" | grep -q .; then
            return 0
        fi
    fi

    if ls "$DOWNLOADS_DIR/"*"$PLUGIN_SEARCH_PATTERN"*.xpi >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

download_plugin() {
    local plugin_key="$1"
    parse_plugin_config "$plugin_key" || return 1

    log_info "Setting up $PLUGIN_DISPLAY_NAME extension..."

    if check_plugin_installed "$plugin_key"; then
        log_success "$PLUGIN_DISPLAY_NAME extension already downloaded/installed. Skipping download."
        return 0
    fi

    log_info "Fetching latest $PLUGIN_DISPLAY_NAME release information..."
    local xpi_url
    xpi_url=$(find_asset_url "$PLUGIN_GITHUB_REPO" '\.xpi$')

    if [[ -z "$xpi_url" ]]; then
        log_error "Failed to find XPI download URL for $PLUGIN_DISPLAY_NAME"
        log_error "Please check the GitHub repository: $PLUGIN_GITHUB_REPO"
        return 1
    fi

    log_info "Found latest release: $(basename "$xpi_url")"

    local download_path="$DOWNLOADS_DIR/$(basename "$xpi_url")"
    log_info "Downloading $PLUGIN_DISPLAY_NAME extension to $download_path..."
    if ! curl -fsSL -o "$download_path" "$xpi_url"; then
        log_error "Failed to download $PLUGIN_DISPLAY_NAME extension from $xpi_url"
        return 1
    fi

    if [[ ! -f "$download_path" || ! -s "$download_path" ]]; then
        log_error "Downloaded file is missing or empty"
        [[ -f "$download_path" ]] && rm -f "$download_path"
        return 1
    fi

    log_success "$PLUGIN_DISPLAY_NAME extension downloaded successfully!"
    print_installation_instructions "$download_path"
}

print_installation_instructions() {
    local download_path="$1"
    log_info "To complete installation:"
    log_info "1. Open Zotero"
    log_info "2. Go to Tools → Plugins"
    log_info "3. Click the gear icon and select 'Install Plugin From File...'"
    log_info "4. Choose: $download_path"
    log_info "5. Click 'Install' and restart Zotero"
    log_warning "Automatic installation via command line is not supported by Zotero."
    log_warning "Manual installation through the GUI is required for proper extension registration."
}

setup_all_plugins() {
    if ! command -v zotero >/dev/null 2>&1; then
        log_error "Zotero not found in PATH. Please install Zotero first."
        return 1
    fi

    local failed_plugins=()
    local success_count=0
    local plugin_key

    while IFS= read -r plugin_key; do
        [[ -z "${plugin_key// /}" ]] && continue
        if download_plugin "$plugin_key"; then
            ((++success_count))
        else
            failed_plugins+=("$plugin_key")
        fi
        echo
    done < <(zotero_plugin_keys)

    log_info "=== Setup Summary ==="
    log_success "$success_count plugin(s) processed successfully"

    if [[ ${#failed_plugins[@]} -gt 0 ]]; then
        log_warning "Failed to setup: ${failed_plugins[*]}"
        return 1
    fi
}

setup_single_plugin() {
    local plugin_key="$1"

    if ! zotero_plugin_exists "$plugin_key"; then
        log_error "Unknown plugin: $plugin_key"
        log_info "Available plugins: $(zotero_available_plugins)"
        return 1
    fi

    if ! command -v zotero >/dev/null 2>&1; then
        log_error "Zotero not found in PATH. Please install Zotero first."
        return 1
    fi

    download_plugin "$plugin_key"
}

main() {
    local available
    available="$(zotero_available_plugins)"

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0 [PLUGIN_KEY]

Install Zotero extensions from GitHub releases. Plugin config: $(packages_toml_path)
Run with no arguments to set up all configured plugins, or pass a key: $available
EOF
        exit 0
    fi

    if [[ $# -eq 0 ]]; then
        setup_all_plugins
    elif [[ $# -eq 1 ]]; then
        setup_single_plugin "$1"
    else
        log_error "Usage: $0 [plugin_name]"
        log_info "Available plugins: $available"
        log_info "Run without arguments to setup all plugins"
        return 1
    fi
}

main "$@"
