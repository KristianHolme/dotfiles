#!/usr/bin/env bash
#
# Shared host inventory helpers backed by a single TOML file.
# Sourced by dotfiles-mounts.sh, dotfiles-rsync-ssh.sh, and dotfiles-ssh-tmux.sh:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-hosts.sh"
#
# The TOML file is resolved as:
#   1. $HOSTS_TOML if set
#   2. hosts.toml searched upward from this file's directory (repo root)
#
# Schema:
#   [machines.<alias>]               # SSH alias as in ~/.ssh/config
#   remote_path = "/home/..."        # optional; together with local_path => mountable
#   local_path  = "/mnt/..."
#
#   [groups.<name>]                  # set of machines sharing a filesystem
#   machines    = ["a", "b", ...]
#   mount_via   = "<alias>"          # optional; together with paths => mountable
#   remote_path = "/home/..."
#   local_path  = "/mnt/..."

if [[ -n "${LIB_HOSTS_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_HOSTS_SH_SOURCED=1

_LIB_HOSTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v ensure_cmd >/dev/null 2>&1; then
    # shellcheck source=lib-dotfiles.sh
    source "$_LIB_HOSTS_DIR/lib-dotfiles.sh"
fi

_HOSTS_TOML_PATH=""

_hosts_resolve() {
    if [[ -n "$_HOSTS_TOML_PATH" ]]; then
        echo "$_HOSTS_TOML_PATH"
        return 0
    fi
    ensure_cmd tomlq

    if [[ -n "${HOSTS_TOML:-}" ]]; then
        if [[ ! -f "$HOSTS_TOML" ]]; then
            log_error "HOSTS_TOML set but file not found: $HOSTS_TOML"
            return 1
        fi
        _HOSTS_TOML_PATH="$HOSTS_TOML"
        echo "$_HOSTS_TOML_PATH"
        return 0
    fi

    local d="$_LIB_HOSTS_DIR"
    while [[ "$d" != "/" ]]; do
        if [[ -f "$d/hosts.toml" ]]; then
            _HOSTS_TOML_PATH="$d/hosts.toml"
            echo "$_HOSTS_TOML_PATH"
            return 0
        fi
        d="$(dirname "$d")"
    done

    log_error "hosts.toml not found (set HOSTS_TOML or place at repo root)"
    return 1
}

# Path of the resolved hosts.toml (for error messages).
hosts_toml_path() {
    _hosts_resolve
}

# All group keys, sorted.
hosts_groups() {
    local f
    f="$(_hosts_resolve)" || return 1
    tomlq -r '.groups // {} | keys[]' "$f" | sort
}

# All [machines.*] keys, sorted.
hosts_standalone_machines() {
    local f
    f="$(_hosts_resolve)" || return 1
    tomlq -r '.machines // {} | keys[]' "$f" | sort
}

# Members of a single group.
hosts_group_machines() {
    local group="$1"
    local f
    f="$(_hosts_resolve)" || return 1
    tomlq -r --arg g "$group" '.groups[$g].machines[]?' "$f"
}

# Union of every SSH alias known to this file (machines.* keys + groups.*.machines), deduped, sorted.
hosts_all_machines() {
    local f
    f="$(_hosts_resolve)" || return 1
    {
        tomlq -r '.machines // {} | keys[]' "$f"
        tomlq -r '.groups   // {} | to_entries[].value.machines[]?' "$f"
    } | sort -u
}

# Filesystem keys: machines with both paths set + groups with mount_via and both paths set.
hosts_filesystems() {
    local f
    f="$(_hosts_resolve)" || return 1
    {
        tomlq -r '.machines // {} | to_entries[] | select(.value.local_path and .value.remote_path) | .key' "$f"
        tomlq -r '.groups   // {} | to_entries[] | select(.value.mount_via and .value.local_path and .value.remote_path) | .key' "$f"
    } | sort -u
}

# "machine" | "group" | "unknown"
hosts_filesystem_kind() {
    local key="$1"
    local f
    f="$(_hosts_resolve)" || return 1
    tomlq -r --arg k "$key" '
        if (.machines[$k]? // null) != null and (.machines[$k].local_path? // null) != null then "machine"
        elif (.groups[$k]?   // null) != null and (.groups[$k].mount_via?   // null) != null then "group"
        else "unknown"
        end
    ' "$f"
}

# SSH alias used to mount this filesystem.
hosts_filesystem_host() {
    local key="$1" kind f
    kind="$(hosts_filesystem_kind "$key")"
    f="$(_hosts_resolve)" || return 1
    case "$kind" in
        machine) echo "$key" ;;
        group)   tomlq -r --arg k "$key" '.groups[$k].mount_via' "$f" ;;
        *)       log_error "Unknown filesystem: $key"; return 1 ;;
    esac
}

hosts_filesystem_remote_path() {
    local key="$1" kind f
    kind="$(hosts_filesystem_kind "$key")"
    f="$(_hosts_resolve)" || return 1
    case "$kind" in
        machine) tomlq -r --arg k "$key" '.machines[$k].remote_path' "$f" ;;
        group)   tomlq -r --arg k "$key" '.groups[$k].remote_path'   "$f" ;;
        *)       log_error "Unknown filesystem: $key"; return 1 ;;
    esac
}

hosts_filesystem_local_path() {
    local key="$1" kind f
    kind="$(hosts_filesystem_kind "$key")"
    f="$(_hosts_resolve)" || return 1
    case "$kind" in
        machine) tomlq -r --arg k "$key" '.machines[$k].local_path' "$f" ;;
        group)   tomlq -r --arg k "$key" '.groups[$k].local_path'   "$f" ;;
        *)       log_error "Unknown filesystem: $key"; return 1 ;;
    esac
}
