#!/usr/bin/env bash
set -Eeuo pipefail

# Robust Zotero plugin setup script
# Downloads and installs Zotero extensions from GitHub releases
#
# Usage:
#   ./dotfiles-setup-zotero.sh                 # Setup all configured plugins
#   ./dotfiles-setup-zotero.sh better-bibtex   # Setup specific plugin
#
# To add a new plugin:
# 1. Add entry to ZOTERO_PLUGINS array below with format:
#    ["plugin-key"]="Display Name:github-owner/repo-name:search-pattern:extension-id"
# 2. The script will automatically handle download and provide installation instructions
#
# Example:
#   ["my-plugin"]="My Plugin:username/zotero-my-plugin:my-plugin:my-plugin@example.com"
#
# Current plugins:
# - better-bibtex: Enhanced citation management and BibTeX export
# - reading-list: Track read status of items (⭐ New, 📙 To Read, 📖 In Progress, 📗 Read, 📕 Not Reading)
# - arxiv-workflow: arXiv paper workflow (metadata, PDF, versioning); requires Zotero 8+ — https://github.com/AllanChain/zotero-arxiv-workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-install.sh"

# Define paths
PROFILE_DIR="$HOME/Zotero"
EXTENSIONS_DIR="$PROFILE_DIR/extensions"
DOWNLOADS_DIR="$HOME/Downloads"

# Plugin configurations
# Format: "plugin_key:display_name:github_repo:search_patterns:extension_id"
declare -A ZOTERO_PLUGINS=(
    ["better-bibtex"]="Better BibTeX:retorquere/zotero-better-bibtex:better-bibtex:better-bibtex@iris-advies.com"
    ["reading-list"]="Reading List:Dominic-DallOsto/zotero-reading-list:reading-list:reading-list@dominic-dallosto.com"
    ["arxiv-workflow"]="arXiv Workflow:AllanChain/zotero-arxiv-workflow:zotero-arxiv-workflow:arxiv@allanchain.github.com"
)

# Parse plugin configuration
parse_plugin_config() {
    local plugin_key="$1"
    local config="${ZOTERO_PLUGINS[$plugin_key]}"

    IFS=':' read -r display_name github_repo search_pattern extension_id <<<"$config"

    # Export for use in other functions
    export PLUGIN_DISPLAY_NAME="$display_name"
    export PLUGIN_GITHUB_REPO="$github_repo"
    export PLUGIN_SEARCH_PATTERN="$search_pattern"
    export PLUGIN_EXTENSION_ID="$extension_id"
}

check_plugin_installed() {
    local plugin_key="$1"
    parse_plugin_config "$plugin_key"

    # Check if plugin is already installed in Zotero's extensions directory
    if [[ -d "$EXTENSIONS_DIR" ]]; then
        if find "$EXTENSIONS_DIR" -name "*$PLUGIN_SEARCH_PATTERN*" -o -name "*$PLUGIN_EXTENSION_ID*" | grep -q .; then
            return 0 # Found
        fi
    fi

    # Check if the XPI file was already downloaded
    if ls "$DOWNLOADS_DIR/"*"$PLUGIN_SEARCH_PATTERN"*.xpi >/dev/null 2>&1; then
        return 0 # Downloaded but maybe not installed yet
    fi

    return 1 # Not found
}

download_plugin() {
    local plugin_key="$1"
    parse_plugin_config "$plugin_key"

    log_info "Setting up $PLUGIN_DISPLAY_NAME extension..."

    # Check if plugin is already installed or downloaded
    if check_plugin_installed "$plugin_key"; then
        log_success "$PLUGIN_DISPLAY_NAME extension already downloaded/installed. Skipping download."
        return 0
    fi

    # Get the latest release download URL using library function
    log_info "Fetching latest $PLUGIN_DISPLAY_NAME release information..."
    local xpi_url
    xpi_url=$(find_asset_url "$PLUGIN_GITHUB_REPO" '\.xpi$')

    if [[ -z "$xpi_url" ]]; then
        log_error "Failed to find XPI download URL for $PLUGIN_DISPLAY_NAME"
        log_error "Please check the GitHub repository: $PLUGIN_GITHUB_REPO"
        return 1
    fi

    log_info "Found latest release: $(basename "$xpi_url")"

    # Download the .xpi file to Downloads
    local download_path="$DOWNLOADS_DIR/$(basename "$xpi_url")"
    log_info "Downloading $PLUGIN_DISPLAY_NAME extension to $download_path..."
    if ! curl -fsSL -o "$download_path" "$xpi_url"; then
        log_error "Failed to download $PLUGIN_DISPLAY_NAME extension from $xpi_url"
        return 1
    fi

    # Verify download
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
    # Check if Zotero is installed
    if ! command -v zotero >/dev/null 2>&1; then
        log_error "Zotero not found in PATH. Please install Zotero first."
        return 1
    fi

    local failed_plugins=()
    local success_count=0

    # Process each configured plugin
    for plugin_key in "${!ZOTERO_PLUGINS[@]}"; do
        if download_plugin "$plugin_key"; then
            # Pre-increment: ((success_count++)) is false when count was 0 and exits under set -e.
            ((++success_count))
        else
            failed_plugins+=("$plugin_key")
        fi
        echo # Add spacing between plugins
    done

    # Summary
    log_info "=== Setup Summary ==="
    log_success "$success_count plugin(s) processed successfully"

    if [[ ${#failed_plugins[@]} -gt 0 ]]; then
        log_warning "Failed to setup: ${failed_plugins[*]}"
        return 1
    fi
}

setup_single_plugin() {
    local plugin_key="$1"

    if [[ -z "${ZOTERO_PLUGINS[$plugin_key]:-}" ]]; then
        log_error "Unknown plugin: $plugin_key"
        log_info "Available plugins: ${!ZOTERO_PLUGINS[*]}"
        return 1
    fi

    # Check if Zotero is installed
    if ! command -v zotero >/dev/null 2>&1; then
        log_error "Zotero not found in PATH. Please install Zotero first."
        return 1
    fi

    download_plugin "$plugin_key"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0 [PLUGIN_KEY]

Install Zotero extensions from GitHub releases. Run with no arguments to set up
all configured plugins, or pass a key: ${!ZOTERO_PLUGINS[*]}
EOF
        exit 0
    fi

    if [[ $# -eq 0 ]]; then
        # No arguments - setup all plugins
        setup_all_plugins
    elif [[ $# -eq 1 ]]; then
        # Single argument - setup specific plugin
        setup_single_plugin "$1"
    else
        log_error "Usage: $0 [plugin_name]"
        log_info "Available plugins: ${!ZOTERO_PLUGINS[*]}"
        log_info "Run without arguments to setup all plugins"
        return 1
    fi
}

main "$@"
