#!/usr/bin/env bash
#
# Common library for dotfiles scripts: logging, dependency checks, symlinks.
# Installation/bootstrap helpers live in lib-install.sh.
# Should be sourced by other scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-dotfiles.sh"

if [[ -n "${LIB_DOTFILES_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_DOTFILES_SH_SOURCED=1

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
