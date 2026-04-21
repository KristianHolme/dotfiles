#!/usr/bin/env bash
set -Eeuo pipefail

# Installs/updates user-local CLI tools without sudo (RHEL-compatible):
# - Bootstraps https://github.com/marcosnils/bin into INSTALL_DIR, then uses
#   `bin install` for GitHub-release CLIs (eza, zoxide, rg, lazygit, fzf, fd,
#   starship, tree-sitter, git-lfs, btop, gum, yazi, dust, gh).
# - GNU stow: built from source into ~/.local (not available via bin).
# - Neovim: AppImage + glibc-aware repo (neovim vs neovim-releases), not via bin.
# - juliaup (curl), LazyVim starter, tpm, omarchy clone.
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

replica_prepend_path() {
    case ":${PATH:-}:" in
    *":$INSTALL_DIR:"*) ;;
    *) export PATH="$INSTALL_DIR${PATH:+:${PATH}}" ;;
    esac
}

# Resolve bin config.json path (mirrors marcosnils/bin getConfigPath).
replica_bin_config_path() {
    if [[ -n "${BIN_CONFIG:-}" ]]; then
        echo "$BIN_CONFIG"
        return 0
    fi
    if [[ -f "$HOME/.bin/config.json" ]]; then
        echo "$HOME/.bin/config.json"
        return 0
    fi
    if [[ -n "${XDG_CONFIG_HOME:-}" && -d "$XDG_CONFIG_HOME" ]]; then
        echo "$XDG_CONFIG_HOME/bin/config.json"
        return 0
    fi
    if [[ -d "$HOME/.config" ]]; then
        echo "$HOME/.config/bin/config.json"
        return 0
    fi
    echo "$HOME/.bin/config.json"
}

# Create a minimal bin config so first run does not prompt for a download directory.
ensure_bin_config_default_path() {
    local conf="" dir=""
    conf=$(replica_bin_config_path)
    dir=$(dirname "$conf")
    mkdir -p "$dir"
    if [[ -f "$conf" ]]; then
        return 0
    fi
    local expanded_dir="${INSTALL_DIR/#\~/$HOME}"
    jq -n --arg p "$expanded_dir" '{default_path: $p, bins: {}}' >"$conf" || {
        log_error "Failed to write bin config at $conf"
        return 1
    }
    log_info "Initialized bin config default_path -> $expanded_dir ($conf)"
}

# Bootstrap marcosnils/bin from GitHub releases (no prior gh/bin required).
install_marcos_bin_bootstrap() {
    local arch="" api_url="https://api.github.com/repos/marcosnils/bin/releases/latest"
    local asset_url="" tmp_dl="" hdr=()

    if [[ -x "$INSTALL_DIR/bin" ]]; then
        log_info "bin already present at $INSTALL_DIR/bin"
        return 0
    fi

    case "$(uname -m)" in
    x86_64 | amd64) arch="linux_amd64" ;;
    aarch64 | arm64) arch="linux_arm64" ;;
    *)
        log_error "Unsupported architecture for bin bootstrap: $(uname -m)"
        return 1
        ;;
    esac

    [[ -n "${GITHUB_AUTH_TOKEN:-}" ]] && hdr=(-H "Authorization: Bearer $GITHUB_AUTH_TOKEN")

    log_info "Bootstrapping marcosnils/bin ($arch) into $INSTALL_DIR/bin"
    asset_url=$(
        curl -fsSL "${hdr[@]}" --max-time "${CURL_TIMEOUT:-30}" "$api_url" |
            grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"https://github.com/marcosnils/bin/releases/download/[^"]*bin_[^"]*_'$arch'"' |
            head -n1 |
            sed 's/.*"\(https[^"]*\)"/\1/'
    ) || true

    if [[ -z "$asset_url" ]]; then
        log_error "Could not resolve bin release asset for $arch"
        return 1
    fi

    mkdir -p "$INSTALL_DIR"
    tmp_dl=$(mktemp)
    trap 'f="${tmp_dl:-}"; [[ -n "$f" ]] && rm -f "$f"' RETURN
    curl -fsSL --max-time "${CURL_TIMEOUT:-120}" -o "$tmp_dl" "$asset_url" || {
        log_error "Failed to download bin from $asset_url"
        return 1
    }
    install -m 0755 "$tmp_dl" "$INSTALL_DIR/bin"
    rm -f "$tmp_dl"
    trap - RETURN
    log_success "Installed bin -> $INSTALL_DIR/bin"
}

# Install gh via release redirect when not already on PATH (no GitHub API).
install_gh_bootstrap_curl() {
    local gh_bin="$INSTALL_DIR/gh"
    local os_arch="" releases_url="https://github.com/cli/cli/releases/latest"
    local effective_url="" version="" asset_url="" tmp="" timeout="${CURL_TIMEOUT:-120}" http_code=""

    case "$(uname -m)" in
    x86_64 | amd64) os_arch="linux_amd64" ;;
    aarch64 | arm64) os_arch="linux_arm64" ;;
    *)
        log_error "Unsupported architecture for gh bootstrap: $(uname -m)"
        return 1
        ;;
    esac

    if command -v gh >/dev/null 2>&1; then
        log_info "gh already on PATH; skipping curl bootstrap"
        return 0
    fi

    log_info "Installing GitHub CLI (gh) via release download (for auth / token export)..."

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN

    effective_url=$(curl --max-time "$timeout" -fsSL -o /dev/null -w "%{url_effective}" "$releases_url" 2>/dev/null || true)
    if [[ -z "$effective_url" ]]; then
        log_error "Failed to resolve gh latest release URL"
        return 1
    fi

    version=$(echo "$effective_url" | sed -n 's#.*/tag/v\([0-9.]\+\).*#\1#p' | head -n1)
    if [[ -z "$version" ]]; then
        log_error "Failed to parse gh version from: $effective_url"
        return 1
    fi

    asset_url="https://github.com/cli/cli/releases/download/v${version}/gh_${version}_${os_arch}.tar.gz"
    log_info "Downloading gh from $asset_url"
    http_code=$(curl --max-time "$timeout" -fsSL -o "$tmp/gh.tar.gz" -w "%{http_code}" "$asset_url" 2>/dev/null || true)
    if [[ "$http_code" != "200" ]]; then
        log_error "Failed to download gh (HTTP $http_code)"
        return 1
    fi

    tar -xzf "$tmp/gh.tar.gz" -C "$tmp"
    local gh_extracted
    gh_extracted=$(find "$tmp" -type f -path "*/bin/gh" | head -n1 || true)
    if [[ -z "$gh_extracted" ]]; then
        log_error "Could not locate gh binary in archive"
        return 1
    fi

    install -m 0755 "$gh_extracted" "$gh_bin"
    log_success "Installed gh -> $gh_bin"
}

ensure_github_api_access() {
    export_github_token_from_gh_if_needed
    if [[ -n "${GITHUB_AUTH_TOKEN:-}" ]]; then
        return 0
    fi
    if gh_is_authed; then
        export_github_token_from_gh_if_needed
        [[ -n "${GITHUB_AUTH_TOKEN:-}" ]] && return 0
    fi
    log_error "GitHub authentication required for bin installs and Neovim release metadata."
    log_error "Export GITHUB_AUTH_TOKEN (PAT, no scopes) or run: gh auth login"
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

replica_bin_install() {
    local spec="$1"
    log_info "bin install $spec"
    bin install "$spec" || return 1
}

configure_git_lfs_hooks() {
    if command -v git-lfs >/dev/null 2>&1; then
        git lfs install --skip-smudge 2>/dev/null || log_warning "Failed to install git-lfs hooks"
        log_info "Configured git-lfs hooks"
    fi
}

replica_install_tools_with_bin() {
    local specs=(
        github.com/marcosnils/bin
        github.com/cli/cli
        github.com/eza-community/eza
        github.com/ajeetdsouza/zoxide
        github.com/BurntSushi/ripgrep
        github.com/jesseduffield/lazygit
        github.com/junegunn/fzf
        github.com/sharkdp/fd
        github.com/bootandy/dust
        github.com/tree-sitter/tree-sitter
        github.com/git-lfs/git-lfs
        github.com/aristocratos/btop
        github.com/sxyazi/yazi
        github.com/starship/starship
        github.com/charmbracelet/gum
    )
    local s
    for s in "${specs[@]}"; do
        replica_bin_install "$s" || log_warning "bin install failed: $s; continuing"
    done
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage: $0

Install user-local CLI tools and omarchy (no sudo) using marcosnils/bin for
GitHub release binaries. Binaries go to INSTALL_DIR (default ~/.local/bin).

Authentication: set GITHUB_AUTH_TOKEN (PAT, no scopes required) or install gh
and run gh auth login so the token can be exported for bin.

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
    replica_prepend_path

    if ! install_marcos_bin_bootstrap; then
        log_error "bin bootstrap failed; cannot continue"
        exit 1
    fi
    replica_prepend_path

    if ! command -v gh >/dev/null 2>&1 && [[ -z "${GITHUB_AUTH_TOKEN:-}" ]]; then
        install_gh_bootstrap_curl || log_warning "gh curl bootstrap failed; set GITHUB_AUTH_TOKEN or install gh manually"
    fi
    replica_prepend_path

    if ! ensure_github_api_access; then
        exit 1
    fi

    if ! check_github_rate_limit; then
        log_error "GitHub API rate limit reached; try again later."
        exit 1
    fi

    if ! ensure_bin_config_default_path; then
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

    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "source ~/.bashrc && $SCRIPT_DIR/julia-setup.jl" --yes

    install_tpm || log_warning "tpm installation failed; continuing"

    clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"

    log_success "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
