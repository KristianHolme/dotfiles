#!/usr/bin/env bash
set -Eeuo pipefail

# Installs/updates user-local CLI tools without sudo (RHEL-compatible):
# - Bootstraps https://github.com/marcosnils/bin: download release binary to a
#   temp path, run `bin install github.com/marcosnils/bin` (README flow; no PATH skip here), then
#   use `bin install` for gh (skipped if gh is already on PATH), then require PAT or `gh auth login`,
#   export token, then `bin install` for the rest (packages.toml [bin.replica]) unless each
#   tool's CLI already exists on PATH (eza, zoxide, rg, lazygit, fzf, fd, starship, git-lfs,
#   btop, gum, superfile, dust, television, bat, shfmt; bin-managed specs still skip via config).
# - go-yq (mikefarah/yq): bootstrapped via bin immediately after bin self-install (before packages.toml);
#   also listed in packages.toml [bin.replica] for updates on re-runs.
# - GNU stow: built from source into ~/.local (not available via bin).
# - Neovim: AppImage + glibc-aware repo (neovim vs neovim-releases), not via bin.
# - juliaup (curl); optional Cursor CLI (gum confirm → official curl installer); LazyVim starter, tpm, omarchy clone.
# - uv tool install for Python CLIs (packages.toml [uv.replica], e.g. trash-cli/trash-list,
#   zotero-mcp-server → zotero-cli). Replica configures zotero-cli for the Zotero Web API
#   using ZOTERO_API_KEY + ZOTERO_LIBRARY_ID (env or ~/.config/zotero-mcp/credentials.env).
# - yazi + ya from GitHub release zip; cargo crates from packages.toml; ya pkg plugins.
#
# PATH skip: distro or other installs satisfy the checker (e.g. bat but not Debian's batcat-only name).
#
# Idempotent: safe to re-run. Pass --upgrade to check for updates and upgrade
# bin-managed tools, uv, cargo crates, rustup, stow (prefix install), juliaup,
# tpm, and Cursor CLI when already installed. Neovim, yazi, yazi plugins, and
# omarchy already version-check on every run.
#
# Config via env vars (override as needed):
#   INSTALL_DIR - where to place binaries (default: ~/.local/bin, or
#                 hosts.toml install_root/bin when set for this machine)
#   OMARCHY_DIR         - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL    - git URL for omarchy (default: empty; skip clone if unset)
#   NVIM_OPT_DIR        - reserved / Neovim install base comment (default: ~/.local/opt/neovim)
#   GITHUB_AUTH_TOKEN   - optional PAT (no scopes) for GitHub API; avoids rate limits for bin
#   BIN_CONFIG          - optional path to bin's config.json (see marcosnils/bin)
#   DEBUG               - set to 1 for verbose debug output
#   CURL_TIMEOUT        - timeout for curl operations in seconds (default: 30 for API, 120 for downloads)
#   DOTFILES_SETUP_UPGRADE - set to 1 for the same effect as --upgrade

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-install.sh"

# INSTALL_DIR defaults to ~/.local/bin, or hosts.toml install_root/bin on this machine.
# An INSTALL_DIR already set in the environment wins over hosts.toml.
if [[ -n "${INSTALL_DIR:-}" ]]; then
    DOTFILES_INSTALL_DIR_FROM_USER=1
else
    DOTFILES_INSTALL_DIR_FROM_USER=0
fi
export DOTFILES_INSTALL_DIR_FROM_USER

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"
NVIM_OPT_DIR="${NVIM_OPT_DIR:-"$HOME/.local/opt/neovim"}"

# Backward compat: GITHUB_TOKEN was documented historically; bin uses GITHUB_AUTH_TOKEN.
if [[ -z "${GITHUB_AUTH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
    GITHUB_AUTH_TOKEN="$GITHUB_TOKEN"
    export GITHUB_AUTH_TOKEN
fi

arch_is_supported() {
    case "$(uname -m)" in
    x86_64 | amd64 | aarch64 | arm64) return 0 ;;
    *) return 1 ;;
    esac
}

ensure_github_api_access() {
    export_github_token_from_gh_if_needed
    if [[ -n "${GITHUB_AUTH_TOKEN:-}" ]]; then
        return 0
    fi
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub authentication required for the remainder of this script (bin installs, Neovim release metadata)."
        log_error "Set GITHUB_AUTH_TOKEN (PAT, no scopes), or ensure gh is on PATH (from bin install) and run: gh auth login"
        return 1
    fi
    if ! gh_is_authed; then
        log_error "GitHub CLI is present at $(command -v gh) but not authenticated."
        log_error "Run: gh auth login"
        log_error "Then re-run this script."
        return 1
    fi
    export_github_token_from_gh_if_needed
    if [[ -n "${GITHUB_AUTH_TOKEN:-}" ]]; then
        return 0
    fi
    log_error "Could not read a token from gh; try: gh auth login"
    return 1
}

install_neovim() {
    local latest_tag="" latest_ver="" current_ver="" glibc_ver="" asset_url="" tmp=""
    local nvim_repo="neovim/neovim"

    glibc_ver=$(detect_glibc_version || true)

    if [[ -n "$glibc_ver" ]] && ver_ge "$glibc_ver" "2.29"; then
        nvim_repo="neovim/neovim"
    else
        nvim_repo="neovim/neovim-releases"
    fi

    latest_tag=$(get_latest_tag "$nvim_repo" || true)
    latest_ver="${latest_tag#v}"

    if command -v nvim >/dev/null 2>&1; then
        local raw_version
        raw_version=$(nvim --version 2>/dev/null | head -n1 || true)
        current_ver=$(echo "$raw_version" | first_version_from_output || true)
        [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: neovim raw version output: '$raw_version', extracted: '$current_ver'"
    else
        current_ver=""
    fi

    if [[ -n "$current_ver" && -n "$latest_ver" ]]; then
        if [[ "$current_ver" == "$latest_ver" ]]; then
            log_info "neovim already up to date ($current_ver)"
            return 0
        fi
        if ver_ge "$current_ver" "$latest_ver"; then
            log_info "neovim is newer or equal ($current_ver >= $latest_ver); skipping"
            return 0
        fi
    fi

    mkdir -p "$INSTALL_DIR"

    case "$(uname -m)" in
    aarch64 | arm64)
        asset_url=$(find_asset_url "$nvim_repo" 'nvim-linux-arm64\.appimage$' || true)
        ;;
    *)
        asset_url=$(find_asset_url "$nvim_repo" 'nvim-linux-x86_64\.appimage$' || true)
        ;;
    esac
    if [[ -z "$asset_url" ]]; then
        log_error "Could not find neovim AppImage asset"
        return 1
    fi
    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading neovim AppImage from $asset_url"
    local timeout="${CURL_TIMEOUT:-300}"
    curl --max-time "$timeout" -fsSL "$asset_url" -o "$tmp/nvim.AppImage" || {
        log_error "Failed to download neovim"
        return 1
    }
    install -m 0755 "$tmp/nvim.AppImage" "$INSTALL_DIR/nvim.appimage"
    ln -sf "$INSTALL_DIR/nvim.appimage" "$INSTALL_DIR/nvim"
    log_success "Installed neovim (AppImage) -> $INSTALL_DIR/nvim (symlink)"
}

install_lazyvim() {
    local nvim_config_dir="$HOME/.config/nvim"

    if [[ -f "$nvim_config_dir/lua/config/lazy.lua" ]] || [[ -f "$nvim_config_dir/init.lua" ]]; then
        log_info "LazyVim config already exists; skipping"
        return 0
    fi

    if ! command -v nvim >/dev/null 2>&1; then
        log_warning "nvim not found; skipping LazyVim installation"
        return 0
    fi

    log_info "Installing LazyVim starter configuration..."

    mkdir -p "$nvim_config_dir"

    local tmp_dir=""
    tmp_dir=$(mktemp -d)
    trap 't="${tmp_dir:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN

    if git clone https://github.com/LazyVim/starter "$tmp_dir/lazyvim-starter" >/dev/null 2>&1; then
        rm -rf "$tmp_dir/lazyvim-starter/.git"

        pushd "$tmp_dir/lazyvim-starter" >/dev/null
        cp -r . "$nvim_config_dir/"
        popd >/dev/null

        log_success "LazyVim starter configuration installed"
        log_info "Run 'nvim' to complete the setup and install plugins"
    else
        log_error "Failed to clone LazyVim starter template"
        return 1
    fi
}

install_stow() {
    local prefix="" tmp="" src="" stow_bin="" current_ver="" latest_ver=""
    prefix="${STOW_PREFIX:-$(dirname "$INSTALL_DIR")}"
    stow_bin=$(command -v stow 2>/dev/null || true)

    if [[ -n "$stow_bin" ]]; then
        if [[ -x "$prefix/bin/stow" ]]; then
            if ! dotfiles_setup_upgrade_enabled; then
                log_info "stow already installed; skipping"
                return 0
            fi
        elif [[ -z "${DOTFILES_INSTALL_ROOT:-}" ]]; then
            if ! dotfiles_setup_upgrade_enabled; then
                log_info "stow already installed; skipping"
                return 0
            fi
            log_info "stow on PATH is not the replica prefix install ($stow_bin); skipping rebuild"
            return 0
        else
            log_info "Installing stow into prefix $prefix (existing $stow_bin left in place)"
        fi
    fi

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading stow (latest)"
    local timeout="${CURL_TIMEOUT:-120}"
    curl --max-time "$timeout" -fsSL https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz -o "$tmp/stow.tar.gz" || {
        log_error "Failed to download stow"
        return 1
    }
    tar -xzf "$tmp/stow.tar.gz" -C "$tmp"
    src=$(find "$tmp" -maxdepth 1 -type d -name 'stow-*' | head -n1 || true)
    if [[ -z "$src" ]]; then
        log_error "Failed to locate stow source directory"
        return 1
    fi

    latest_ver=$(basename "$src" | first_version_from_output || true)
    if [[ -x "$prefix/bin/stow" ]]; then
        current_ver=$("$prefix/bin/stow" --version 2>/dev/null | first_version_from_output || true)
        if [[ -n "$current_ver" && -n "$latest_ver" ]] && ver_ge "$current_ver" "$latest_ver"; then
            log_info "stow already up to date ($current_ver)"
            return 0
        fi
        log_info "stow ${current_ver:-unknown} older than $latest_ver; rebuilding"
    else
        log_info "Building stow ${latest_ver:-latest}"
    fi

    (
        cd "$src"
        ./configure --prefix="$prefix" --quiet 2>&1 | grep -v "WARNING.*missing modules" || true
        make -s 2>&1 | grep -v "WARNING.*missing modules" || true
        make -s install 2>&1 | grep -v "WARNING.*missing modules" || true
    )

    if [[ -x "$prefix/bin/stow" ]]; then
        log_success "Installed stow -> $prefix/bin/stow"
    else
        log_error "Failed to install stow"
        return 1
    fi
}

configure_git_lfs_hooks() {
    if command -v git-lfs >/dev/null 2>&1; then
        git lfs install --skip-smudge 2>/dev/null || log_warning "Failed to install git-lfs hooks"
        log_info "Configured git-lfs hooks"
    fi
}

replica_install_tools_with_bin() {
    local -a pairs=()
    mapfile -t pairs < <(bin_replica_install_list) || return 1

    local pair spec cmd
    for pair in "${pairs[@]}"; do
        spec="${pair%%:*}"
        cmd="${pair##*:}"
        # Prefer mikefarah go-yq; replace legacy Python yq or other unmanaged binaries.
        if [[ "$cmd" == "yq" && -z "${DOTFILES_INSTALL_ROOT:-}" ]]; then
            if go_yq_available; then
                log_info "go-yq already on PATH; skipping bin install ($spec)"
                continue
            fi
            marcos_bin_install_or_update_github "$spec" "$cmd" \
                || log_warning "bin install failed: $spec; continuing"
            continue
        fi
        marcos_bin_install_if_missing_and_cmd_absent "$spec" "$cmd" || log_warning "bin install failed: $spec; continuing"
    done
}

maybe_install_cursor_cli() {
    if command -v cursor >/dev/null 2>&1; then
        if dotfiles_setup_upgrade_enabled; then
            log_info "Updating Cursor CLI via official installer"
            curl -fsSL https://cursor.com/install | bash || log_warning "Cursor CLI update failed; continuing"
        fi
        return 0
    fi
    if ! command -v gum >/dev/null 2>&1; then
        log_warning "gum not found; skipping Cursor CLI prompt"
        return 0
    fi
    if ! gum confirm "Install Cursor CLI? (official curl installer)" \
        --default=false --affirmative="Yes" --negative="No"; then
        log_info "Skipping Cursor CLI"
        return 0
    fi
    install_via_curl "Cursor CLI" "cursor" "https://cursor.com/install" || log_warning "Cursor CLI installation failed; continuing"
}

main() {
    DOTFILES_SETUP_UPGRADE="${DOTFILES_SETUP_UPGRADE:-0}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h | --help)
            cat <<EOF
Usage: $0 [--upgrade]

Install user-local CLI tools and omarchy (no sudo) using marcosnils/bin for
GitHub release binaries. Binaries go to INSTALL_DIR (default ~/.local/bin).

Each listed tool skips bin install if its CLI is already on PATH (except bin bootstrap).

  --upgrade, -u   Check for updates and upgrade installed tools: bin-managed
                  binaries, uv (self + replica tools), rustup, cargo crates,
                  prefix-built stow, juliaup, tpm, and Cursor CLI if present.
                  Neovim, yazi, yazi plugins, and omarchy already version-check
                  on every run. Does not overwrite an existing LazyVim config.

Authentication: after gh is available (preinstalled or via bin), set GITHUB_AUTH_TOKEN (PAT, no
scopes) or run gh auth login so the token is exported for bin and curl API calls.

After juliaup, if gum is available, asks via gum confirm whether to install Cursor CLI.
Installs cargo crates and Yazi plugins (ya pkg) after bin tools.

zotero-cli (via uv): configured for Zotero Web API. Set ZOTERO_API_KEY and
ZOTERO_LIBRARY_ID (optional ZOTERO_LIBRARY_TYPE=user|group), or put them in
~/.config/zotero-mcp/credentials.env before running.

See header comments for INSTALL_DIR, OMARCHY_DIR, OMARCHY_REPO_URL, etc.
EOF
            exit 0
            ;;
        --upgrade | -u)
            DOTFILES_SETUP_UPGRADE=1
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
        esac
    done
    export DOTFILES_SETUP_UPGRADE

    if [[ "$DOTFILES_SETUP_UPGRADE" == "1" ]]; then
        log_info "Upgrade mode: will update installed tools when newer releases exist"
    fi

    sanitize_stale_cargo_env_sources

    ensure_cmd curl tar unzip git install make perl jq

    if ! arch_is_supported; then
        log_error "Unsupported architecture $(uname -m). This script targets Linux x86_64 or arm64."
        exit 1
    fi

    apply_dotfiles_install_root || true
    INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
    export INSTALL_DIR

    mkdir -p "$INSTALL_DIR"
    marcos_bin_prepend_path

    if ! ensure_marcos_bin_config_default_path; then
        exit 1
    fi

    if ! install_marcos_bin_bootstrap; then
        log_error "bin bootstrap failed; cannot continue"
        exit 1
    fi
    marcos_bin_prepend_path

    if ! command -v bin >/dev/null 2>&1; then
        log_error "'bin' not on PATH after bootstrap (expected $INSTALL_DIR/bin). Check INSTALL_DIR and PATH."
        exit 1
    fi

    if ! ensure_replica_yq_via_bin; then
        log_error "go-yq bootstrap failed; cannot read packages.toml"
        exit 1
    fi

    apply_dotfiles_install_root || true
    INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
    export INSTALL_DIR
    mkdir -p "$INSTALL_DIR"
    marcos_bin_prepend_path
    ensure_marcos_bin_config_default_path || exit 1

    local -a prereqs=()
    mapfile -t prereqs < <(bin_replica_prereq_list) || exit 1

    local pair spec cmd
    for pair in "${prereqs[@]}"; do
        spec="${pair%%:*}"
        cmd="${pair##*:}"
        log_info "Installing prerequisite via bin ($cmd): $spec"
        if ! marcos_bin_install_if_missing_and_cmd_absent "$spec" "$cmd"; then
            log_error "bin install $spec failed; cannot continue"
            exit 1
        fi
    done
    marcos_bin_prepend_path

    if ! ensure_github_api_access; then
        exit 1
    fi

    export_github_token_from_gh_if_needed

    if ! check_github_rate_limit; then
        log_error "GitHub API rate limit reached; try again later."
        exit 1
    fi

    if [[ "${DEBUG:-}" == "1" ]]; then
        log_info "DEBUG mode enabled"
        log_info "DEBUG: INSTALL_DIR=$INSTALL_DIR"
        log_info "DEBUG: CURL_TIMEOUT=${CURL_TIMEOUT:-default}"
    fi

    replica_install_tools_with_bin
    if dotfiles_setup_upgrade_enabled; then
        marcos_bin_update_managed
    fi
    setup_uv_replica_tools || log_warning "uv tool setup failed; continuing"
    setup_zotero_mcp_cli web || log_warning "zotero-cli web configure failed; continuing"
    install_yazi_from_release || log_warning "yazi release install failed; continuing"
    setup_cargo_crates || log_warning "cargo crate setup failed; continuing"
    setup_yazi_plugins || log_warning "Yazi plugin setup failed; continuing"
    configure_git_lfs_hooks

    install_stow || log_warning "stow installation failed; continuing"

    install_neovim || log_warning "neovim installation failed; continuing"

    install_lazyvim || log_warning "LazyVim installation failed; continuing"

    install_juliaup_and_setup "$SCRIPT_DIR/julia-setup.jl"

    maybe_install_cursor_cli

    install_tpm || log_warning "tpm installation failed; continuing"

    clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"
    ensure_btop_omarchy_theme || true

    ensure_bash_profile_user_path

    log_success "Done. Restart your shell or: source ~/.bash_profile"
}

main "$@"
