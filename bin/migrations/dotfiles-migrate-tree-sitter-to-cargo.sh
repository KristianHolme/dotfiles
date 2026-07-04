#!/usr/bin/env bash
#
# Remove marcosnils/bin-managed tree-sitter so setup_cargo_crates can install
# tree-sitter-cli via cargo (~/.cargo/bin/tree-sitter).
#
# ~/.local/bin precedes ~/.cargo/bin in dot-bashrc, and setup_cargo_crates skips
# when tree-sitter is already on PATH — so the bin copy must go first.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib-dotfiles.sh
source "$SCRIPT_DIR/../lib-dotfiles.sh"
# shellcheck source=../lib-install.sh
source "$SCRIPT_DIR/../lib-install.sh"

usage() {
    cat <<EOF
Usage: $0 [--dry-run] [-h|--help]

Remove bin-managed tree-sitter from ~/.local/bin (and bin config) so the cargo
crate tree-sitter-cli can be installed by dotfiles-setup-packages.sh or
dotfiles-setup-replica.sh (Setup cargo crates step).

  --dry-run   Show what would be removed; make no changes.

After this script, run:
  dotfiles-setup-packages.sh   # select "Setup cargo crates"
  # or: cargo install tree-sitter-cli

EOF
}

dry_run=0

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --dry-run)
        dry_run=1
        shift
        ;;
    --*)
        log_error "Unknown option: $1"
        usage >&2
        exit 1
        ;;
    *)
        log_error "Unexpected argument: $1"
        usage >&2
        exit 1
        ;;
    esac
done

install_path="${INSTALL_DIR:-$HOME/.local/bin}/tree-sitter"
managed=0

if marcos_bin_is_managed_at "$install_path"; then
    managed=1
elif [[ -x "$install_path" ]]; then
    log_warning "tree-sitter exists at $install_path but is not tracked in bin config"
    log_warning "If this is a bin install with a mismatched config, remove it manually or re-run after fixing bin config"
    if [[ "$dry_run" -eq 1 ]]; then
        log_info "[dry-run] Would not auto-remove untracked binary at $install_path"
        exit 0
    fi
    exit 0
else
    log_info "No bin-managed tree-sitter at $install_path; nothing to migrate"
    exit 0
fi

if [[ "$dry_run" -eq 1 ]]; then
    log_info "[dry-run] Would remove bin-managed tree-sitter at $install_path"
    if command -v bin >/dev/null 2>&1; then
        log_info "[dry-run] Would run: bin remove tree-sitter"
    else
        log_info "[dry-run] Would delete $install_path and prune bin config entry"
    fi
    log_info "[dry-run] Then run Setup cargo crates or: cargo install tree-sitter-cli"
    exit 0
fi

marcos_bin_prepend_path

if command -v bin >/dev/null 2>&1; then
    log_info "Removing bin-managed tree-sitter..."
    bin remove tree-sitter || {
        log_error "bin remove tree-sitter failed"
        exit 1
    }
else
    log_warning "bin not on PATH; removing binary and config entry manually"
    local_conf=$(marcos_bin_config_path)
    if [[ -f "$local_conf" ]]; then
        tmp=$(mktemp)
        jq --arg p "$install_path" 'del(.bins[$p])' "$local_conf" >"$tmp" && mv "$tmp" "$local_conf"
    fi
    rm -f "$install_path"
fi

if [[ -x "$install_path" ]]; then
    log_error "tree-sitter still present at $install_path after removal"
    exit 1
fi

log_success "Removed bin-managed tree-sitter"
log_info "Next: run dotfiles-setup-packages.sh and select 'Setup cargo crates', or: cargo install tree-sitter-cli"
