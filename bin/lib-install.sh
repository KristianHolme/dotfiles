#!/usr/bin/env bash
#
# Installation/bootstrap helpers for dotfiles setup scripts:
# GitHub API + release downloads, marcosnils/bin, juliaup, omarchy, tpm,
# bashrc bootstrap. Sourced only by the setup/apply scripts that install
# things; everyday utilities only need lib-dotfiles.sh.
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-install.sh"

if [[ -n "${LIB_INSTALL_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_INSTALL_SH_SOURCED=1

_LIB_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$_LIB_INSTALL_DIR/lib-dotfiles.sh"

# Populate GITHUB_AUTH_TOKEN from gh when possible (marcosnils/bin and curl GitHub API use this).
export_github_token_from_gh_if_needed() {
    [[ -n "${GITHUB_AUTH_TOKEN:-}" ]] && return 0
    command -v gh >/dev/null 2>&1 || return 0
    gh auth status -h github.com >/dev/null 2>&1 || return 0
    GITHUB_AUTH_TOKEN="$(gh auth token -h github.com 2>/dev/null || true)"
    [[ -n "${GITHUB_AUTH_TOKEN:-}" ]] && export GITHUB_AUTH_TOKEN
    return 0
}

check_github_rate_limit() {
    local remaining reset now wait mins hours
    export_github_token_from_gh_if_needed

    if [[ -n "${GITHUB_AUTH_TOKEN:-}" ]]; then
        if ! command -v jq >/dev/null 2>&1; then
            log_warning "jq not found; skipping GitHub rate limit check (token auth)"
            return 0
        fi
        local rate_json=""
        rate_json=$(
            curl -fsSL --max-time "${CURL_TIMEOUT:-30}" \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $GITHUB_AUTH_TOKEN" \
                https://api.github.com/rate_limit
        ) || {
            log_warning "Could not read GitHub rate limit (token auth)"
            return 0
        }
        remaining=$(jq -r '.resources.core.remaining' <<<"$rate_json") || remaining=""
        reset=$(jq -r '.resources.core.reset' <<<"$rate_json") || reset=""
    elif gh_is_authed; then
        remaining=$(gh api /rate_limit --jq '.resources.core.remaining' 2>/dev/null || true)
        reset=$(gh api /rate_limit --jq '.resources.core.reset' 2>/dev/null || true)
    else
        log_warning "No GitHub token or authenticated gh; skipping rate limit check"
        return 0
    fi

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

# Ensure ~/.bashrc exists with a minimal interactive stub (Debian-style).
ensure_basic_bashrc() {
    local bashrc_path="${1:-$HOME/.bashrc}"
    if [[ -f "$bashrc_path" ]]; then
        return 0
    fi
    log_info "Creating minimal $bashrc_path"
    cat >"$bashrc_path" <<'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.
# Created by dotfiles (ensure_basic_bashrc)

# If not running interactively, don't do anything.
case $- in
    *i*) ;;
      *) return;;
esac
EOF
}

# Ensure login shells (SSH, etc.) load ~/.bashrc — required on many RHEL/university images.
ensure_bash_profile_sources_bashrc() {
    local profile_path="${1:-$HOME/.bash_profile}"
    local bashrc_path="${2:-$HOME/.bashrc}"
    local source_line="[[ -f $bashrc_path ]] && . $bashrc_path"

    if [[ -f "$profile_path" ]] && grep -qE '(^|\s)(\.|source)\s+.*\.bashrc' "$profile_path" 2>/dev/null; then
        log_info "$profile_path already sources bashrc; skipping"
        return 0
    fi

    if [[ ! -f "$profile_path" ]]; then
        log_info "Creating $profile_path to source $bashrc_path"
        cat >"$profile_path" <<EOF
# ~/.bash_profile: executed by bash(1) for login shells.
# Created by dotfiles (ensure_bash_profile_sources_bashrc)

$source_line
EOF
        return 0
    fi

    log_info "Adding bashrc source to $profile_path"
    printf '\n# Load interactive settings (added by dotfiles)\n%s\n' "$source_line" >>"$profile_path"
}

# Prepend juliaup/julia bin dirs without sourcing bashrc (non-interactive scripts return early).
refresh_julia_path() {
    local dir
    for dir in "$HOME/.juliaup/bin" "$HOME/.julia/bin"; do
        if [[ -d "$dir" ]] && [[ ":$PATH:" != *":$dir:"* ]]; then
            PATH="$dir${PATH:+:$PATH}"
        fi
    done
    export PATH
}

# Resolve julia for post-install setup (PATH, then common juliaup locations).
find_julia_executable() {
    refresh_julia_path
    local candidate
    if command -v julia >/dev/null 2>&1; then
        command -v julia
        return 0
    fi
    for candidate in "$HOME/.juliaup/bin/julia" "$HOME/.julia/bin/julia"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# Backup stale juliaup.json when a previous install left config but no juliaup/julia binary.
prepare_juliaup_install() {
    local juliaup_json="$HOME/.julia/juliaup/juliaup.json"
    if [[ ! -f "$juliaup_json" ]]; then
        return 0
    fi
    if command -v juliaup >/dev/null 2>&1; then
        return 0
    fi
    if find_julia_executable >/dev/null 2>&1; then
        return 0
    fi
    local backup="${juliaup_json}.dotfiles-backup.$(date +%Y%m%d_%H%M%S)"
    log_warning "Stale juliaup config at $juliaup_json without juliaup/julia on PATH; moving to $backup"
    mv "$juliaup_json" "$backup"
}

# Run julia-setup.jl using an explicit julia path (do not rely on #!/usr/bin/env julia).
run_julia_setup_script() {
    local setup_script="$1"
    if [[ -z "$setup_script" ]]; then
        log_error "run_julia_setup_script: missing script path"
        return 1
    fi
    if [[ ! -f "$setup_script" ]]; then
        log_warning "Julia setup script not found: $setup_script; skipping"
        return 0
    fi

    ensure_basic_bashrc

    local julia_bin=""
    if ! julia_bin=$(find_julia_executable); then
        log_warning "julia not found after juliaup install; skipping $setup_script"
        log_warning "Restart your shell or run: $setup_script"
        return 1
    fi

    log_info "Running Julia setup with $julia_bin"
    "$julia_bin" "$setup_script" || {
        log_warning "Julia setup script failed: $setup_script"
        return 1
    }
    return 0
}

# Install juliaup via official curl installer, then run optional setup script.
install_juliaup_and_setup() {
    local setup_script="${1:-}"
    local juliaup_was_present=0
    if command -v juliaup >/dev/null 2>&1; then
        juliaup_was_present=1
    fi

    prepare_juliaup_install
    install_via_curl "Julia (juliaup)" "juliaup" "https://install.julialang.org" "" --yes

    if [[ "$juliaup_was_present" -eq 1 ]]; then
        log_info "juliaup was already installed; run setup manually if needed: ${setup_script:-}"
        return 0
    fi

    if [[ -n "$setup_script" ]]; then
        run_julia_setup_script "$setup_script" || true
    fi
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

# Install tmux plugin manager (tpm) into ~/.config/tmux/plugins/tpm (idempotent).
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

cargo_prepend_path() {
    local cargo_bin="$HOME/.cargo/bin"
    case ":${PATH:-}:" in
    *":$cargo_bin:"*) ;;
    *) export PATH="$cargo_bin${PATH:+:${PATH}}" ;;
    esac
}

ensure_cargo() {
    cargo_prepend_path
    if command -v cargo >/dev/null 2>&1; then
        return 0
    fi

    ensure_cmd curl
    log_info "Installing Rust toolchain via rustup..."
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        log_error "rustup installation failed"
        return 1
    fi

    cargo_prepend_path
    if ! command -v cargo >/dev/null 2>&1; then
        log_error "cargo not on PATH after rustup install"
        return 1
    fi

    log_success "Rust toolchain ready"
    return 0
}

# Install crates from package-lists/cargo-install.txt (crate or crate:command per line).
setup_cargo_crates() {
    local list_file="${1:-$_LIB_INSTALL_DIR/package-lists/cargo-install.txt}"

    if [[ ! -f "$list_file" ]]; then
        log_info "No cargo install list at $list_file; skipping"
        return 0
    fi

    local -a entries=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        entries+=("$line")
    done <"$list_file"

    if [[ ${#entries[@]} -eq 0 ]]; then
        log_info "No crates listed in $list_file; skipping"
        return 0
    fi

    if ! ensure_cargo; then
        log_warning "cargo unavailable; cannot install crates"
        return 1
    fi

    local entry crate cmd
    for entry in "${entries[@]}"; do
        if [[ "$entry" == *:* ]]; then
            crate="${entry%%:*}"
            cmd="${entry##*:}"
        else
            crate="$entry"
            cmd="$entry"
        fi

        cargo_prepend_path
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "$cmd already on PATH; skipping cargo install $crate"
            continue
        fi

        log_info "Installing $crate via cargo (binary: $cmd)..."
        if cargo install "$crate"; then
            cargo_prepend_path
            if command -v "$cmd" >/dev/null 2>&1; then
                log_success "Installed $cmd -> $(command -v "$cmd")"
            else
                log_warning "$cmd not on PATH after cargo install $crate"
            fi
        else
            log_warning "cargo install $crate failed (non-critical)"
        fi
    done
}

# Install yazi and ya from the official GitHub release zip (bin only installs one binary).
yazi_cmd_works() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 && "$cmd" --version >/dev/null 2>&1
}

yazi_release_asset_re() {
    local glibc_ver="" use_musl=0
    glibc_ver=$(detect_glibc_version || true)
    if [[ -z "$glibc_ver" ]] || ! ver_ge "$glibc_ver" "2.39"; then
        use_musl=1
        if [[ -n "$glibc_ver" ]]; then
            log_info "glibc $glibc_ver < 2.39; using musl yazi release"
        else
            log_info "glibc version unknown; using musl yazi release"
        fi
    fi

    case "$(uname -m)" in
    aarch64 | arm64)
        if [[ "$use_musl" -eq 1 ]]; then
            echo 'yazi-aarch64-unknown-linux-musl\.zip$'
        else
            echo 'yazi-aarch64-unknown-linux-gnu\.zip$'
        fi
        ;;
    x86_64 | amd64)
        if [[ "$use_musl" -eq 1 ]]; then
            echo 'yazi-x86_64-unknown-linux-musl\.zip$'
        else
            echo 'yazi-x86_64-unknown-linux-gnu\.zip$'
        fi
        ;;
    *)
        log_error "Unsupported architecture for yazi release: $(uname -m)"
        return 1
        ;;
    esac
}

install_yazi_from_release() {
    local install_base="${INSTALL_DIR:-$HOME/.local/bin}"
    local need_yazi=0 need_ya=0 asset_re="" asset_url="" tmp="" extract_dir=""

    marcos_bin_prepend_path
    yazi_cmd_works yazi || need_yazi=1
    yazi_cmd_works ya || need_ya=1
    if [[ "$need_yazi" -eq 0 && "$need_ya" -eq 0 ]]; then
        log_info "yazi and ya already on PATH; skipping release install"
        return 0
    fi

    ensure_cmd curl unzip install

    asset_re=$(yazi_release_asset_re) || return 1

    asset_url=$(find_asset_url "sxyazi/yazi" "$asset_re") || {
        log_error "Could not find yazi release zip matching $asset_re"
        return 1
    }

    tmp=$(mktemp -d)
    trap 't="${tmp:-}"; [[ -n "$t" ]] && rm -rf "$t"' RETURN

    log_info "Downloading yazi release (yazi + ya) from $asset_url"
    curl -fsSL --max-time "${CURL_TIMEOUT:-120}" -o "$tmp/yazi.zip" "$asset_url" || {
        log_error "Failed to download yazi release"
        return 1
    }
    unzip -q "$tmp/yazi.zip" -d "$tmp"

    extract_dir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)
    if [[ -z "$extract_dir" || ! -f "$extract_dir/yazi" || ! -f "$extract_dir/ya" ]]; then
        log_error "yazi release zip missing yazi or ya binary"
        return 1
    fi

    mkdir -p "$install_base"
    if [[ "$need_yazi" -eq 1 ]]; then
        install -m 0755 "$extract_dir/yazi" "$install_base/yazi"
        log_success "Installed yazi -> $install_base/yazi"
    fi
    if [[ "$need_ya" -eq 1 ]]; then
        install -m 0755 "$extract_dir/ya" "$install_base/ya"
        log_success "Installed ya -> $install_base/ya"
    fi

    marcos_bin_prepend_path
    if ! yazi_cmd_works ya; then
        log_error "ya installed but does not run (check glibc / try musl build)"
        return 1
    fi
}

setup_yazi_plugins() {
    local list_file="$_LIB_INSTALL_DIR/../default/dot-config/yazi/plugins.txt"

    if ! command -v mdv >/dev/null 2>&1; then
        log_warning "mdv not on PATH (install cargo crates first); mdv-previewer will not work"
    fi

    if ! yazi_cmd_works ya; then
        log_warning "ya not working on PATH (install yazi release first); skipping Yazi plugins"
        return 0
    fi

    if [[ ! -f "$list_file" ]]; then
        log_info "No Yazi plugins list at $list_file; skipping"
        return 0
    fi

    local -a plugins=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        plugins+=("$line")
    done <"$list_file"

    if [[ ${#plugins[@]} -eq 0 ]]; then
        log_info "No Yazi plugins listed in plugins.txt; skipping"
        return 0
    fi

    local installed_list plugin
    local -a to_add=() to_upgrade=()
    installed_list=$(ya pkg list 2>/dev/null || true)

    for plugin in "${plugins[@]}"; do
        if grep -qF "$plugin" <<<"$installed_list"; then
            to_upgrade+=("$plugin")
        else
            to_add+=("$plugin")
        fi
    done

    if [[ ${#to_add[@]} -gt 0 ]]; then
        log_info "Installing Yazi plugins: ${to_add[*]}"
        ya pkg add "${to_add[@]}" || log_warning "Some Yazi plugin installs failed (non-critical)"
    fi

    if [[ ${#to_upgrade[@]} -gt 0 ]]; then
        log_info "Upgrading Yazi plugins: ${to_upgrade[*]}"
        ya pkg upgrade "${to_upgrade[@]}" || log_warning "Some Yazi plugin upgrades failed (non-critical)"
    fi
}

#######################################
# Marcosnils/bin (https://github.com/marcosnils/bin)
# Shared by dotfiles-setup-replica.sh, dotfiles-setup-packages.sh, etc.
# Uses INSTALL_DIR (default ~/.local/bin), BIN_CONFIG, CURL_TIMEOUT, GITHUB_AUTH_TOKEN.
#######################################

marcos_bin_prepend_path() {
    local d="${INSTALL_DIR:-$HOME/.local/bin}"
    case ":${PATH:-}:" in
    *":$d:"*) ;;
    *) export PATH="$d${PATH:+:${PATH}}" ;;
    esac
}

# Resolve bin config.json path (mirrors marcosnils/bin getConfigPath).
marcos_bin_config_path() {
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

# True when marcosnils/bin already tracks this install path in config.json.
marcos_bin_is_managed_at() {
    local install_path="$1" conf=""
    conf=$(marcos_bin_config_path)
    [[ -f "$conf" ]] || return 1
    jq -e --arg p "$install_path" '.bins | has($p)' "$conf" >/dev/null 2>&1
}

# True when marcosnils/bin already tracks this provider URL in config.json (idempotent re-runs).
# bin may store the short spec (github.com/owner/repo) or a full release/tag URL after install.
marcos_bin_is_registered() {
    local spec="$1" conf="" repo=""
    conf=$(marcos_bin_config_path)
    [[ -f "$conf" ]] || return 1
    repo="${spec#github.com/}"
    if [[ -z "$repo" || "$repo" == "$spec" ]]; then
        return 1
    fi
    jq -e --arg spec "$spec" --arg repo "$repo" '
        any(.bins[]?;
            .url == $spec
            or (.url | test("github\\.com/" + ($repo | gsub("\\."; "\\\\.")) + "(/|$|\\?|#)"; "i"))
        )
    ' "$conf" >/dev/null 2>&1
}

# Create a minimal bin config so first run does not prompt for a download directory.
ensure_marcos_bin_config_default_path() {
    local conf="" dir="" install_base="${INSTALL_DIR:-$HOME/.local/bin}"
    conf=$(marcos_bin_config_path)
    dir=$(dirname "$conf")
    mkdir -p "$dir"
    if [[ -f "$conf" ]]; then
        return 0
    fi
    local expanded_dir="${install_base/#\~/$HOME}"
    jq -n --arg p "$expanded_dir" '{default_path: $p, bins: {}}' >"$conf" || {
        log_error "Failed to write bin config at $conf"
        return 1
    }
    log_info "Initialized bin config default_path -> $expanded_dir ($conf)"
}

# Bootstrap marcosnils/bin from GitHub releases (no prior bin required).
# Matches upstream README: download a release binary, then run
# `./bin install github.com/marcosnils/bin` so the install is tracked by bin.
# Call after ensure_marcos_bin_config_default_path. Uses public GitHub API for the release
# curl (optional GITHUB_AUTH_TOKEN improves rate limits); self-install needs no prior gh.
install_marcos_bin_bootstrap() {
    local arch="" api_url="https://api.github.com/repos/marcosnils/bin/releases/latest"
    local asset_url="" tmpdir="" bootstrap_bin="" hdr=()
    local install_base="${INSTALL_DIR:-$HOME/.local/bin}"

    if [[ -x "$install_base/bin" ]]; then
        log_info "bin already present at $install_base/bin"
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

    log_info "Bootstrapping marcosnils/bin ($arch): temp download, then bin install github.com/marcosnils/bin -> $install_base"
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

    mkdir -p "$install_base"
    tmpdir=$(mktemp -d)
    bootstrap_bin="$tmpdir/marcos-bin-bootstrap"
    trap 'd="${tmpdir:-}"; [[ -n "$d" ]] && rm -rf "$d"' RETURN
    curl -fsSL --max-time "${CURL_TIMEOUT:-120}" -o "$bootstrap_bin" "$asset_url" || {
        log_error "Failed to download bin from $asset_url"
        return 1
    }
    chmod +x "$bootstrap_bin"
    if ! "$bootstrap_bin" install github.com/marcosnils/bin; then
        log_error "Bootstrap bin failed: install github.com/marcosnils/bin"
        return 1
    fi
    rm -rf "$tmpdir"
    tmpdir=""
    trap - RETURN

    if [[ ! -x "$install_base/bin" ]]; then
        log_error "Self-install did not produce an executable at $install_base/bin"
        return 1
    fi
    log_success "Installed bin (self-managed) -> $install_base/bin"
}

# Skip install if spec URL is already in bin config (cheap idempotent re-runs).
marcos_bin_install_if_missing() {
    local spec="$1"
    if marcos_bin_is_registered "$spec"; then
        log_info "bin already manages $spec; skipping install"
        return 0
    fi
    log_info "bin install $spec"
    bin install "$spec" || return 1
}

# Skip bin install when the expected CLI is already on PATH (e.g. distro package).
marcos_bin_install_if_missing_and_cmd_absent() {
    local spec="$1" cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        log_info "$cmd already on PATH; skipping bin install ($spec)"
        return 0
    fi
    marcos_bin_install_if_missing "$spec"
}

# tomlq from PyPI "yq" (kislyuk/yq) — jq wrapper for TOML; used by lib-hosts.sh.
# Not the Go github.com/mikefarah/yq binary (different syntax; marcos bin installs that one).
install_tomlq_if_missing() {
    local install_base="${INSTALL_DIR:-$HOME/.local/bin}"

    if command -v tomlq >/dev/null 2>&1; then
        log_info "tomlq already on PATH; skipping install"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq required for tomlq (hosts.toml scripts); install jq first"
        return 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 required for tomlq (pip install yq)"
        return 1
    fi

    log_info "Installing tomlq via pip (PyPI package yq)"
    python3 -m pip install --user yq || return 1

    marcos_bin_prepend_path
    case ":${PATH:-}:" in
    *":$install_base:"*) ;;
    *) export PATH="$install_base${PATH:+:${PATH}}" ;;
    esac

    if command -v tomlq >/dev/null 2>&1; then
        log_success "Installed tomlq -> $(command -v tomlq)"
        return 0
    fi

    log_error "tomlq not on PATH after pip install; ensure $install_base is on PATH"
    return 1
}

# If spec is registered, run bin update; otherwise bin install (e.g. prefer bin over a distro binary).
marcos_bin_install_or_update_github() {
    local spec="$1"
    local binary_name="$2"
    local install_path="${INSTALL_DIR:-$HOME/.local/bin}/$binary_name"
    local -a update_flags=()
    export_github_token_from_gh_if_needed
    if [[ "${DOTFILES_SETUP_UNATTENDED:-0}" == "1" ]]; then
        update_flags=(-y)
    fi
    if marcos_bin_is_registered "$spec" || marcos_bin_is_managed_at "$install_path"; then
        log_info "bin update $binary_name"
        bin update "$binary_name" "${update_flags[@]}" || return 1
        return 0
    fi
    log_info "bin install $spec"
    bin install "$spec" || return 1
}

#######################################
# GitHub Release Helpers
#######################################

github_api() {
    # $1: path like repos/owner/repo/releases/latest
    # Uses GITHUB_AUTH_TOKEN (curl) when set; otherwise authenticated gh.
    local path="$1"
    local url="https://api.github.com/$path"

    export_github_token_from_gh_if_needed

    if [[ -n "${GITHUB_AUTH_TOKEN:-}" ]]; then
        sleep 0.2
        [[ "${DEBUG:-}" == "1" ]] && log_info "DEBUG: GitHub API GET $url (token)"
        curl -fsSL --max-time "${CURL_TIMEOUT:-30}" \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_AUTH_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$url" || {
            log_error "GitHub API request failed for $path"
            check_github_rate_limit || true
            return 1
        }
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        log_error "gh not installed and GITHUB_AUTH_TOKEN not set; cannot access GitHub API"
        return 1
    fi

    if ! gh_is_authed; then
        log_error "gh is not authenticated and GITHUB_AUTH_TOKEN not set; cannot access GitHub API"
        return 1
    fi

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

# Prints host glibc version (e.g. 2.28) or empty if unknown.
detect_glibc_version() {
    local v=""
    if command -v ldd >/dev/null 2>&1; then
        v=$(ldd --version 2>/dev/null | head -n1 | grep -Eo '[0-9]+\.[0-9]+' | head -n1 || true)
    fi
    if [[ -z "$v" ]] && command -v getconf >/dev/null 2>&1; then
        v=$(getconf GNU_LIBC_VERSION 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+' | head -n1 || true)
    fi
    [[ -n "$v" ]] && echo "$v"
    return 0
}
