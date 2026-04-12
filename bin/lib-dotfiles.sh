#!/usr/bin/env bash
#
# Common library for dotfiles scripts
# Should be sourced by other scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-dotfiles.sh"

# Standard error handling - inherit from calling script if already set
if [[ ! "${-}" =~ e ]]; then
    set -Eeuo pipefail
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Centralized logging functions
# Usage: log_info "This is an info message"
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

gh_is_authed() {
    command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1
}

check_github_rate_limit() {
    local remaining reset now wait mins
    if ! gh_is_authed; then
        log_error "gh is not authenticated; cannot check GitHub rate limits"
        return 1
    fi

    remaining=$(gh api /rate_limit --jq '.resources.core.remaining' 2>/dev/null || true)
    reset=$(gh api /rate_limit --jq '.resources.core.reset' 2>/dev/null || true)

    if [[ -z "${remaining:-}" || -z "${reset:-}" ]]; then
        log_warning "Could not read GitHub rate limit info"
        return 0
    fi

    if [[ "$remaining" -eq 0 ]]; then
        now=$(date +%s)
        wait=$((reset - now))
        if [[ "$wait" -lt 0 ]]; then
            wait=0
        fi
        mins=$((wait / 60))
        hours=$((mins / 60))
        mins=$((mins % 60))
        log_error "GitHub API rate limit reached. Reset in ~${hours}h ${mins}m (epoch: $reset)."
        return 1
    fi

    [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: GitHub API rate limit remaining: $remaining"
    return 0
}
# Standardized dependency check
# Usage: ensure_cmd "git" "curl"
ensure_cmd() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || {
            log_error "Missing required command: $cmd"
            exit 1
        }
    done
}

# Portable helper to install a tool via piping curl to bash.
# Usage: install_via_curl "Name" check_cmd url [post_install_cmd] [installer_args...]
install_via_curl() {
    local name="$1"
    local check_cmd="$2"
    local url="$3"
    local post_install_cmd="${4:-}"
    local installer_args=("${@:5}")

    if command -v "$check_cmd" >/dev/null 2>&1; then
        log_info "$name already installed; skipping installer"
    else
        log_info "Installing $name"
        curl -fsSL "$url" | bash -s -- "${installer_args[@]}"
        if [[ -n "$post_install_cmd" ]]; then
            eval "$post_install_cmd"
        fi
    fi
}

# Creates a symlink to a target file or directory, backing up the target if it exists and is not already a symlink.
# This function is idempotent.
# Usage: create_symlink_with_backup "/path/to/source" "/path/to/target" "Description for logging"
create_symlink_with_backup() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"

    # Check if source exists
    if [[ ! -e "$source_path" ]]; then
        log_warning "Source for $description not found: $source_path; skipping"
        return 0
    fi

    # Check if already correctly symlinked
    if [[ -L "$target_path" ]]; then
        local current_target
        current_target="$(readlink "$target_path")"
        if [[ "$current_target" == "$source_path" ]] || [[ "$(realpath "$target_path" 2>/dev/null)" == "$(realpath "$source_path" 2>/dev/null)" ]]; then
            log_info "$description already symlinked correctly; skipping"
            return 0
        fi

        # Different symlink exists, remove it
        log_warning "Removing existing incorrect symlink: $target_path -> $current_target"
        rm "$target_path"
    elif [[ -e "$target_path" ]]; then
        # File/directory exists but isn't a symlink, backup it
        local backup_path="$target_path.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up existing $description: $target_path -> $backup_path"
        mv "$target_path" "$backup_path"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target_path")"

    # Create the symlink
    log_info "Creating symlink for $description: $target_path -> $source_path"
    ln -sf "$source_path" "$target_path"
}

clone_or_update_omarchy() {
    local omarchy_dir="${1:-$HOME/.local/share/omarchy}"
    local omarchy_repo_url="${2:-https://github.com/basecamp/omarchy}"

    if [[ -d "$omarchy_dir/.git" ]]; then
        log_info "Updating omarchy in $omarchy_dir"
        git -C "$omarchy_dir" pull --ff-only || log_warning "omarchy update failed; continuing"
        return 0
    fi
    if [[ -z "${omarchy_repo_url}" ]]; then
        log_warning "OMARCHY_REPO_URL not set and no existing clone at $omarchy_dir; skipping clone"
        return 0
    fi
    mkdir -p "$(dirname "$omarchy_dir")"
    log_info "Cloning omarchy from $omarchy_repo_url -> $omarchy_dir"
    git clone "$omarchy_repo_url" "$omarchy_dir" || log_warning "omarchy clone failed; continuing"
}

#######################################
# GitHub Release Installation Helpers
# From dotfiles-setup-replica.sh
#######################################

github_api() {
    # $1: path like repos/owner/repo/releases/latest
    # Requires gh and authentication
    local path="$1"

    if ! command -v gh >/dev/null 2>&1; then
        log_error "gh not installed; cannot access GitHub API"
        return 1
    fi

    if ! gh_is_authed; then
        log_error "gh is not authenticated; cannot access GitHub API"
        return 1
    fi

    # Add small delay to be nice to GitHub API
    sleep 0.2

    [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: gh api $path"
    gh api -H "Accept: application/vnd.github+json" "$path" 2>/dev/null || {
        log_error "gh api failed for $path"
        check_github_rate_limit || true
        return 1
    }
}

get_latest_tag() {
    # $1: owner/repo
    # outputs tag (e.g. v0.23.0)
    local api_response tag
    api_response=$(github_api "repos/$1/releases/latest") || {
        [[ "${DEBUG:-}" == "1" ]] && log_error "DEBUG: github_api failed for $1"
        return 1
    }
    tag=$(echo "$api_response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [[ -z "$tag" ]]; then
        [[ "${DEBUG:-}" == "1" ]] && log_error "DEBUG: Could not extract tag from response for $1"
        return 1
    fi
    echo "$tag"
}

find_asset_url() {
    # $1: owner/repo
    # $2: regex to match asset name (extended regex)
    # outputs browser_download_url
    local or="$1" re="$2" api_response url
    api_response=$(github_api "repos/$or/releases/latest") || {
        [[ "${DEBUG:-}" == "1" ]] && log_error "DEBUG: github_api failed for $or"
        return 1
    }
    url=$(echo "$api_response" |
        awk -v RS=',' '1' |
        sed -n 's/\s*"browser_download_url"\s*:\s*"\([^"]*\)".*/\1/p' |
        grep -E "$re" | head -n1)
    if [[ -z "$url" ]]; then
        [[ "${DEBUG:-}" == "1" ]] && log_warning "DEBUG: No asset found matching pattern: $re"
        return 1
    fi
    echo "$url"
}

first_version_from_output() {
    # Reads stdin, extracts first x.y or x.y.z... sequence (robust)
    # Handles various version formats: v1.2.3, 1.2.3, v1.2.3-beta, etc.
    # Requires grep with -E and -o support
    grep -Eo '[0-9]+(\.[0-9]+)+' | head -n1
}

ver_ge() {
    # $1 >= $2 ?  return 0 if true
    # relies on sort -V
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

install_tree_sitter() {
    local INSTALL_DIR="${1:-$HOME/.local/bin}"
    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp=""

    latest_tag=$(get_latest_tag "tree-sitter/tree-sitter" || true)
    latest_ver="${latest_tag#v}"

    if command -v tree-sitter >/dev/null 2>&1; then
        local raw_version
        raw_version=$(tree-sitter --version 2>/dev/null || true)
        current_ver=$(echo "$raw_version" | first_version_from_output || true)
        [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: tree-sitter raw version output: '$raw_version', extracted: '$current_ver'"
        if [[ -z "$current_ver" ]]; then
            log_warning "tree-sitter detected but version could not be determined; reinstalling"
        fi
        log_info "tree-sitter detected: current=$current_ver, latest=$latest_ver"
    else
        current_ver=""
        log_info "tree-sitter not found in PATH"
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log_info "tree-sitter already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "tree-sitter is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    mkdir -p "$INSTALL_DIR"

    # tree-sitter releases as tree-sitter-linux-x64.gz
    asset_url=$(find_asset_url "tree-sitter/tree-sitter" 'tree-sitter-linux-x64\.gz$' || true)
    if [[ -z "$asset_url" ]]; then
        log_error "Could not find tree-sitter linux binary"
        return 1
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading tree-sitter from $asset_url"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/tree-sitter.gz" || {
        log_error "Failed to download tree-sitter"
        return 1
    }
    gunzip "$tmp/tree-sitter.gz"
    install -m 0755 "$tmp/tree-sitter" "$INSTALL_DIR/tree-sitter"
    log_success "Installed tree-sitter -> $INSTALL_DIR/tree-sitter"
}

install_from_tarball() {
    # Downloads and installs a binary from a GitHub release asset: tarball/zip or a single raw executable.
    # Performs version checking to avoid unnecessary downloads
    #
    # Arguments:
    # $1 name               - Human readable name for logging
    # $2 owner/repo         - GitHub repository in format "owner/repo"
    # $3 asset_name_regex   - Extended regex to match release asset filename (path tail of browser_download_url)
    # $4 binary_name        - Name the binary should have in INSTALL_DIR
    # $5 version_cmd        - Command to get current version (quoted string)
    # $6 INSTALL_DIR        - Target directory (optional, defaults to ~/.local/bin)
    #
    # Example:
    #   install_from_tarball "ripgrep" "BurntSushi/ripgrep" \\
    #     'ripgrep-[^/]*-x86_64-unknown-linux-musl\.tar\.gz$' \\
    #     "rg" "rg --version" "$HOME/.local/bin"
    local name="$1" or="$2" asset_pat="$3" bin_name="$4" version_cmd="$5"
    local INSTALL_DIR="${6:-$HOME/.local/bin}"

    local latest_tag="" latest_ver="" current_ver="" asset_url="" tmp="" dir="" bin_path=""

    log_info "Checking $name releases..."
    latest_tag=$(get_latest_tag "$or") || {
        log_warning "Failed to get $name latest tag (repo: $or)"
        [[ "${DEBUG:-}" == "1" ]] && log_error "DEBUG: get_latest_tag output: $latest_tag"
        latest_tag=""
    }
    latest_ver="${latest_tag#v}"

    if [[ -z "$latest_tag" ]]; then
        log_warning "Skipping $name installation due to API error"
        return 0
    fi

    [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: $name latest tag: $latest_tag, version: $latest_ver"

    if command -v "$bin_name" >/dev/null 2>&1; then
        current_ver=$({ eval "$version_cmd" 2>/dev/null || true; } | first_version_from_output || true)
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log_info "$name already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "$name is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    asset_url=$(find_asset_url "$or" "$asset_pat") || {
        log_error "Could not find asset for $name matching /$asset_pat/ (repo: $or)"
        [[ "${DEBUG:-}" == "1" ]] && log_error "DEBUG: find_asset_url output: $asset_url"
        return 1
    }

    if [[ "${DEBUG:-}" == "1" ]]; then
        log_info "DEBUG: Found asset URL: $asset_url"
        log_info "DEBUG: Asset name: ${asset_url##*/}"
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading $name from $asset_url"

    local timeout="${CURL_TIMEOUT:-120}"
    [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: Downloading with timeout ${timeout}s"

    mkdir -p "$INSTALL_DIR"

    if [[ "$asset_url" =~ \.(zip|tar\.gz|tgz|tar\.bz2|tbz|tar\.xz|txz)$ ]]; then
        local archive_name extract_opts
        if [[ "$asset_url" =~ \.zip$ ]]; then
            archive_name="archive.zip"
            extract_opts=""
        elif [[ "$asset_url" =~ \.tbz$ ]] || [[ "$asset_url" =~ \.tar\.bz2$ ]]; then
            archive_name="archive.tar.bz2"
            extract_opts="-xjf"
        elif [[ "$asset_url" =~ \.tar\.xz$ ]] || [[ "$asset_url" =~ \.txz$ ]]; then
            archive_name="archive.tar.xz"
            extract_opts="-xJf"
        else
            archive_name="archive.tar.gz"
            extract_opts="-xzf"
        fi

        curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/$archive_name" || {
            log_error "Failed to download $name from $asset_url"
            return 1
        }

        mkdir -p "$tmp/extract"
        if [[ "$archive_name" == "archive.zip" ]]; then
            unzip -q "$tmp/$archive_name" -d "$tmp/extract"
        else
            tar $extract_opts "$tmp/$archive_name" -C "$tmp/extract"
        fi

        bin_path=$(find "$tmp/extract" -type f -name "$bin_name" -perm -u+x | head -n1 || true)
        if [[ -z "$bin_path" ]]; then
            bin_path=$(find "$tmp/extract" -type f -name "$bin_name" | head -n1 || true)
        fi
        if [[ -z "$bin_path" ]]; then
            log_error "Binary $bin_name not found in archive for $name"
            return 1
        fi

        install -m 0755 "$bin_path" "$INSTALL_DIR/$bin_name"
    else
        local bin_dl="$tmp/release-asset.bin"
        curl --max-time "$timeout" -fsSL "$asset_url" -o "$bin_dl" || {
            log_error "Failed to download $name from $asset_url"
            return 1
        }
        install -m 0755 "$bin_dl" "$INSTALL_DIR/$bin_name"
    fi

    log_success "Installed/updated $name -> $INSTALL_DIR/$bin_name"
}
