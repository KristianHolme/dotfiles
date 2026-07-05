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

# True when mikefarah go-yq is on PATH (the preferred TOML parser).
go_yq_available() {
    command -v yq >/dev/null 2>&1 && yq --version 2>/dev/null | grep -q mikefarah
}

# True when go-yq or legacy tomlq (PyPI yq) is available.
toml_backend_available() {
    go_yq_available || command -v tomlq >/dev/null 2>&1
}

# Print JSON for a TOML file (prefer go-yq, fall back to tomlq).
toml_to_json() {
    local file="$1"
    if go_yq_available; then
        yq -p toml -o json "$file"
        return 0
    fi
    if command -v tomlq >/dev/null 2>&1; then
        tomlq . "$file"
        return 0
    fi
    log_error "No TOML parser available; install go-yq (Arch: yay -S go-yq; replica: packages.toml [bin.replica])"
    return 1
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

# Start a background SSH ControlMaster when ~/.ssh/config enables multiplexing.
# Subsequent ssh(1) calls to the same host reuse the connection (helps 2FA/jump hosts).
ensure_ssh_controlmaster() {
    local host="$1" cm=""

    cm=$(ssh -G "$host" 2>/dev/null | awk '$1 == "controlmaster" { print $2; exit }')
    case "$cm" in
    auto | autoask | yes | ask) ;;
    *) return 0 ;;
    esac

    if ssh -O check "$host" >/dev/null 2>&1; then
        return 0
    fi

    echo "🔐 Starting background master connection for $host..."
    echo "   (This will prompt for 2FA + password once)"
    if ssh -CX -o ServerAliveInterval=30 -fN "$host"; then
        echo "✅ Master connection established"
    else
        echo "⚠️  Failed to start master connection, continuing anyway..."
    fi
    echo
}

# True when FLAG appears in the remaining args (e.g. stow_flags_include -D "${flags[@]}").
stow_flags_include() {
    local flag="$1"
    shift
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "$flag" ]]; then
            return 0
        fi
    done
    return 1
}

# Remove agent symlinks created by link_agent_configs when they point into ~/.agents.
unlink_agent_configs() {
    local agents_dir="$HOME/.agents" target resolved
    local -a targets=(
        "$HOME/.cursor/skills"
        "$HOME/.cursor/commands"
        "$HOME/.config/opencode/commands"
    )

    for target in "${targets[@]}"; do
        [[ -L "$target" ]] || continue
        resolved="$(realpath "$target" 2>/dev/null || true)"
        agents_real="$(realpath "$agents_dir" 2>/dev/null || echo "$agents_dir")"
        if [[ -n "$resolved" && "$resolved" == "$agents_real/"* ]]; then
            log_info "Removing agent symlink: $target"
            rm "$target"
        fi
    done
}

# Merge script defaults with user stow flags for apply mode. Sets merged flags via nameref.
merge_apply_stow_flags() {
    local -n _merged="$1"
    shift
    local -a user_flags=("$@")
    local arg has_override=0 has_no_folding=0

    _merged=(--dotfiles)
    for arg in "${user_flags[@]}"; do
        [[ "$arg" == --override* ]] && has_override=1
        [[ "$arg" == --no-folding ]] && has_no_folding=1
    done
    if [[ "$has_override" -eq 0 ]]; then
        _merged+=(--override='.*')
    fi
    if [[ "$has_no_folding" -eq 0 ]]; then
        _merged+=(--no-folding)
    fi
    if [[ ${#user_flags[@]} -gt 0 ]]; then
        _merged+=("${user_flags[@]}")
    fi
}
