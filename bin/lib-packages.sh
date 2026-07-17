#!/usr/bin/env bash
#
# Shared package inventory helpers backed by a single TOML file.
# Sourced by dotfiles-setup-packages.sh, dotfiles-setup-replica.sh,
# dotfiles-setup-zotero.sh, and lib-install.sh:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-packages.sh"
#
# TOML is parsed once per shell via toml_to_json (go-yq preferred, tomlq fallback)
# and queried with jq.
#
# The TOML file is resolved as:
#   1. $PACKAGES_TOML if set
#   2. packages.toml searched upward from this file's directory (repo root)
#
# Schema:
#   [packages]
#   install = ["pkg", ...]
#   remove  = ["pkg", ...]
#
#   [webapps]
#   remove = ["WebAppName", ...]
#
#   [cargo]
#   install = ["crate", "crate:command", ...]
#
#   [uv.replica]
#   install = ["package", "package:command", ...]
#
#   [bin.replica]
#   prereq  = ["spec:command", ...]
#   install = ["spec:command", ...]
#
#   [gh]
#   extensions = ["owner/repo", ...]
#
#   [yazi]
#   install = ["owner/repo", "owner/repo:subdir", ...]
#
#   [omarchy.themes]
#   install = ["https://github.com/owner/omarchy-name-theme", ...]
#
#   [zotero.plugins.<key>]
#   display_name = "..."
#   github_repo = "owner/repo"
#   search_pattern = "..."
#   extension_id = "...@..."

if [[ -n "${LIB_PACKAGES_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_PACKAGES_SH_SOURCED=1

_LIB_PACKAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v ensure_cmd >/dev/null 2>&1; then
    # shellcheck source=lib-dotfiles.sh
    source "$_LIB_PACKAGES_DIR/lib-dotfiles.sh"
fi

_PACKAGES_TOML_PATH=""
_PACKAGES_JSON=""

_packages_resolve() {
    if [[ -n "$_PACKAGES_TOML_PATH" ]]; then
        echo "$_PACKAGES_TOML_PATH"
        return 0
    fi
    if ! toml_backend_available; then
        log_error "No TOML parser available; install go-yq (Arch: yay -S go-yq; replica: packages.toml [bin.replica])"
        return 1
    fi
    ensure_cmd jq

    if [[ -n "${PACKAGES_TOML:-}" ]]; then
        if [[ ! -f "$PACKAGES_TOML" ]]; then
            log_error "PACKAGES_TOML set but file not found: $PACKAGES_TOML"
            return 1
        fi
        _PACKAGES_TOML_PATH="$PACKAGES_TOML"
        echo "$_PACKAGES_TOML_PATH"
        return 0
    fi

    local d="$_LIB_PACKAGES_DIR"
    while [[ "$d" != "/" ]]; do
        if [[ -f "$d/packages.toml" ]]; then
            _PACKAGES_TOML_PATH="$d/packages.toml"
            echo "$_PACKAGES_TOML_PATH"
            return 0
        fi
        d="$(dirname "$d")"
    done

    log_error "packages.toml not found (set PACKAGES_TOML or place at repo root)"
    return 1
}

_packages_json() {
    if [[ -n "$_PACKAGES_JSON" ]]; then
        echo "$_PACKAGES_JSON"
        return 0
    fi
    local f
    f="$(_packages_resolve)" || return 1
    _PACKAGES_JSON="$(toml_to_json "$f")" || return 1
    echo "$_PACKAGES_JSON"
}

# Path of the resolved packages.toml (for error messages).
packages_toml_path() {
    _packages_resolve
}

packages_install_list() {
    _packages_json | jq -r '.packages.install[]?'
}

packages_remove_list() {
    _packages_json | jq -r '.packages.remove[]?'
}

webapps_remove_list() {
    _packages_json | jq -r '.webapps.remove[]?'
}

cargo_install_list() {
    _packages_json | jq -r '.cargo.install[]?'
}

uv_replica_install_list() {
    _packages_json | jq -r '.uv.replica.install[]?'
}

bin_replica_prereq_list() {
    _packages_json | jq -r '.bin.replica.prereq[]?'
}

bin_replica_install_list() {
    _packages_json | jq -r '.bin.replica.install[]?'
}

gh_extensions_list() {
    _packages_json | jq -r '.gh.extensions[]?'
}

yazi_plugins_list() {
    _packages_json | jq -r '.yazi.install[]?'
}

omarchy_themes_install_list() {
    _packages_json | jq -r '.omarchy.themes.install[]?'
}

zotero_plugin_keys() {
    _packages_json | jq -r '.zotero.plugins // {} | keys[]' | sort
}

zotero_plugin_field() {
    local key="$1" field="$2"
    _packages_json | jq -r --arg k "$key" --arg f "$field" '.zotero.plugins[$k][$f] // empty'
}

zotero_plugin_exists() {
    local key="$1" json
    json="$(_packages_json)" || return 1
    [[ -n "$(jq -r --arg k "$key" '.zotero.plugins[$k] // empty' <<<"$json")" ]]
}
