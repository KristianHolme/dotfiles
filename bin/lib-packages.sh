#!/usr/bin/env bash
#
# Shared package inventory helpers backed by a single TOML file.
# Sourced by dotfiles-setup-packages.sh, dotfiles-setup-replica.sh,
# dotfiles-setup-zotero.sh, and lib-install.sh:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-packages.sh"
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

_packages_resolve() {
    if [[ -n "$_PACKAGES_TOML_PATH" ]]; then
        echo "$_PACKAGES_TOML_PATH"
        return 0
    fi
    ensure_cmd tomlq

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

# Path of the resolved packages.toml (for error messages).
packages_toml_path() {
    _packages_resolve
}

packages_install_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.packages.install[]?' "$f"
}

packages_remove_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.packages.remove[]?' "$f"
}

webapps_remove_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.webapps.remove[]?' "$f"
}

cargo_install_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.cargo.install[]?' "$f"
}

bin_replica_prereq_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.bin.replica.prereq[]?' "$f"
}

bin_replica_install_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.bin.replica.install[]?' "$f"
}

gh_extensions_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.gh.extensions[]?' "$f"
}

yazi_plugins_list() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.yazi.install[]?' "$f"
}

zotero_plugin_keys() {
    local f
    f="$(_packages_resolve)" || return 1
    tomlq -r '.zotero.plugins // {} | keys[]' "$f" | sort
}

zotero_plugin_field() {
    local key="$1" field="$2" f
    f="$(_packages_resolve)" || return 1
    tomlq -r --arg k "$key" --arg f "$field" '.zotero.plugins[$k][$f] // empty' "$f"
}

zotero_plugin_exists() {
    local key="$1" f
    f="$(_packages_resolve)" || return 1
    [[ -n "$(tomlq -r --arg k "$key" '.zotero.plugins[$k] // empty' "$f")" ]]
}
