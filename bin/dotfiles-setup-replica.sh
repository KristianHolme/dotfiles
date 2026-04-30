#!/usr/bin/env bash
set -Eeuo pipefail

# Installs/updates user-local CLI tools without sudo (RHEL-compatible):
# - Bootstraps https://github.com/marcosnils/bin: download release binary to a
#   temp path, run `bin install github.com/marcosnils/bin` (README flow; no PATH skip here), then
#   use `bin install` for gh (skipped if gh is already on PATH), then require PAT or `gh auth login`,
#   export token, then `bin install` for the rest unless each tool's CLI already exists on PATH
#   (eza, zoxide, rg, lazygit, fzf, fd, starship, tree-sitter, git-lfs, btop, gum, superfile, dust,
#   television, bat; bin-managed specs still skip via config when applicable).
# - GNU stow: built from source into ~/.local (not available via bin).
# - Neovim: AppImage + glibc-aware repo (neovim vs neovim-releases), not via bin.
# - juliaup (curl), LazyVim starter, tpm, omarchy clone.
#
# PATH skip: distro or other installs satisfy the checker (e.g. bat but not Debian's batcat-only name).
#
# Idempotent: safe to re-run; bin and neovim update when upstream releases change.
#
# Config via env vars (override as needed):
#   INSTALL_DIR - where to place binaries (default: ~/.local/bin); also bin's default
#   OMARCHY_DIR         - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL    - git URL for omarchy (default: empty; skip clone if unset)
#   NVIM_OPT_DIR        - reserved / Neovim install base comment (default: ~/.local/opt/neovim)
#   GITHUB_AUTH_TOKEN   - optional PAT (no scopes) for GitHub API; avoids rate limits for bin
#   BIN_CONFIG          - optional path to bin's config.json (see marcosnils/bin)
#   DEBUG               - set to 1 for verbose debug output
#   CURL_TIMEOUT        - timeout for curl operations in seconds (default: 30 for API, 120 for downloads)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
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

install_tpm() {
    local tpm_dir="$HOME/.config/tmux/plugins/tpm"

    if [[ -d "$tpm_dir" ]]; then
        log_info "tmux plugin manager (tpm) already installed; skipping"
        return 0
    fi

    log_info "Installing tmux plugin manager (tpm)..."

    mkdir -p "$(dirname "$tpm_dir")"

    if git clone https://github.com/tmux-plugins/tpm "$tpm_dir" >/dev/null 2>&1; then
        log_success "Installed tmux plugin manager -> $tpm_dir"
    else
        log_error "Failed to clone tmux plugin manager"
        return 1
    fi
}

install_stow() {
    if command -v stow >/dev/null 2>&1; then
        log_info "stow already installed; skipping"
        return 0
    fi
    local prefix="" tmp="" src=""
    prefix="${STOW_PREFIX:-$(dirname "$INSTALL_DIR")}"
    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN
    log_info "Downloading and building stow (latest)"
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

    (
        cd "$src"
        ./configure --prefix="$prefix" --quiet 2>&1 | grep -v "WARNING.*missing modules" || true
        make -s 2>&1 | grep -v "WARNING.*missing modules" || true
        make -s install 2>&1 | grep -v "WARNING.*missing modules" || true
    )

    if command -v stow >/dev/null 2>&1; then
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
    # spec:cli — CLI name is what `command -v` checks before `bin install` (spf for superfile, etc.).
    local spec_cmd_pairs=(
        github.com/eza-community/eza:eza
        github.com/ajeetdsouza/zoxide:zoxide
        github.com/BurntSushi/ripgrep:rg
        github.com/jesseduffield/lazygit:lazygit
        github.com/junegunn/fzf:fzf
        github.com/sharkdp/fd:fd
        github.com/bootandy/dust:dust
        github.com/tree-sitter/tree-sitter:tree-sitter
        github.com/git-lfs/git-lfs:git-lfs
        github.com/aristocratos/btop:btop
        github.com/yorukot/superfile:spf
        github.com/starship/starship:starship
        github.com/charmbracelet/gum:gum
        github.com/alexpasmantier/television:tv
        github.com/sharkdp/bat:bat
    )
    local pair spec cmd
    for pair in "${spec_cmd_pairs[@]}"; do
        spec="${pair%%:*}"
        cmd="${pair##*:}"
        marcos_bin_install_if_missing_and_cmd_absent "$spec" "$cmd" || log_warning "bin install failed: $spec; continuing"
    done
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0

Install user-local CLI tools and omarchy (no sudo) using marcosnils/bin for
GitHub release binaries. Binaries go to INSTALL_DIR (default ~/.local/bin).

Each listed tool skips bin install if its CLI is already on PATH (except bin bootstrap).

Authentication: after gh is available (preinstalled or via bin), set GITHUB_AUTH_TOKEN (PAT, no
scopes) or run gh auth login so the token is exported for bin and curl API calls.

See header comments for INSTALL_DIR, OMARCHY_DIR, OMARCHY_REPO_URL, etc.
EOF
        exit 0
    fi

    ensure_cmd curl tar unzip git install make perl jq

    if ! arch_is_supported; then
        log_error "Unsupported architecture $(uname -m). This script targets Linux x86_64 or arm64."
        exit 1
    fi

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

    log_info "Installing GitHub CLI (gh) via bin (skipped if gh is already on PATH)"
    if ! marcos_bin_install_if_missing_and_cmd_absent "github.com/cli/cli" gh; then
        log_error "bin install github.com/cli/cli failed; cannot continue"
        exit 1
    fi
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
    configure_git_lfs_hooks

    install_stow || log_warning "stow installation failed; continuing"

    install_neovim || log_warning "neovim installation failed; continuing"

    install_lazyvim || log_warning "LazyVim installation failed; continuing"

    juliaup_preinstalled=0
    if command -v juliaup >/dev/null 2>&1; then
        juliaup_preinstalled=1
    fi

    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && $SCRIPT_DIR/julia-setup.jl" --yes

    if [[ "$juliaup_preinstalled" -eq 1 ]]; then
        log_info "julia-setup.jl was not run (juliaup was already installed). Run it manually if you need to refresh packages: $SCRIPT_DIR/julia-setup.jl"
    fi

    install_tpm || log_warning "tpm installation failed; continuing"

    clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"

    log_success "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
