#!/usr/bin/env bash
#
# Shared host inventory helpers backed by a single TOML file.
# Sourced by dotfiles-mounts.sh, dotfiles-rsync-ssh.sh, and dotfiles-ssh-tmux.sh:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-hosts.sh"
#
# TOML is parsed once per shell via toml_to_json (go-yq preferred, tomlq fallback)
# and queried with jq.
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
#
#   [defaults]
#   sync_root = "Code"               # optional; relative to remote_path, or absolute if starts with /
#
#   [machines.<alias>]
#   sync_root = "/fp/projects/.../Code"   # optional override; local landing defaults to ~/Code

if [[ -n "${LIB_HOSTS_SH_SOURCED:-}" ]]; then
    return 0
fi
LIB_HOSTS_SH_SOURCED=1

_LIB_HOSTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v ensure_cmd >/dev/null 2>&1; then
    # shellcheck source=lib-dotfiles.sh
    source "$_LIB_HOSTS_DIR/lib-dotfiles.sh"
fi

# Short local hostname (for filtering self out of host menus).
hosts_local_hostname() {
    hostname -s 2>/dev/null || hostname | cut -d. -f1
}

_HOSTS_TOML_PATH=""
_HOSTS_JSON=""

_hosts_resolve() {
    if [[ -n "$_HOSTS_TOML_PATH" ]]; then
        echo "$_HOSTS_TOML_PATH"
        return 0
    fi
    if ! toml_backend_available; then
        log_error "No TOML parser available; install go-yq (Arch: yay -S go-yq; replica: packages.toml [bin.replica])"
        return 1
    fi
    ensure_cmd jq

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

_hosts_json() {
    if [[ -n "$_HOSTS_JSON" ]]; then
        echo "$_HOSTS_JSON"
        return 0
    fi
    local f
    f="$(_hosts_resolve)" || return 1
    _HOSTS_JSON="$(toml_to_json "$f")" || return 1
    echo "$_HOSTS_JSON"
}

# Path of the resolved hosts.toml (for error messages).
hosts_toml_path() {
    _hosts_resolve
}

# All group keys, sorted.
hosts_groups() {
    _hosts_json | jq -r '.groups // {} | keys[]' | sort
}

# All [machines.*] keys, sorted.
hosts_standalone_machines() {
    _hosts_json | jq -r '.machines // {} | keys[]' | sort
}

# Members of a single group.
hosts_group_machines() {
    local group="$1"
    _hosts_json | jq -r --arg g "$group" '.groups[$g].machines[]?'
}

# Union of every SSH alias known to this file (machines.* keys + groups.*.machines), deduped, sorted.
hosts_all_machines() {
    local json
    json="$(_hosts_json)" || return 1
    {
        jq -r '.machines // {} | keys[]' <<<"$json"
        jq -r '.groups   // {} | to_entries[].value.machines[]?' <<<"$json"
    } | sort -u
}

# Filesystem keys: machines with both paths set + groups with mount_via and both paths set.
hosts_filesystems() {
    local json
    json="$(_hosts_json)" || return 1
    {
        jq -r '.machines // {} | to_entries[] | select(.value.local_path and .value.remote_path) | .key' <<<"$json"
        jq -r '.groups   // {} | to_entries[] | select(.value.mount_via and .value.local_path and .value.remote_path) | .key' <<<"$json"
    } | sort -u
}

# "machine" | "group" | "unknown"
hosts_filesystem_kind() {
    local key="$1"
    _hosts_json | jq -r --arg k "$key" '
        if (.machines[$k]? // null) != null and (.machines[$k].local_path? // null) != null then "machine"
        elif (.groups[$k]?   // null) != null and (.groups[$k].mount_via?   // null) != null then "group"
        else "unknown"
        end
    '
}

# SSH alias used to mount this filesystem.
hosts_filesystem_host() {
    local key="$1" kind
    kind="$(hosts_filesystem_kind "$key")"
    case "$kind" in
        machine) echo "$key" ;;
        group)   _hosts_json | jq -r --arg k "$key" '.groups[$k].mount_via' ;;
        *)       log_error "Unknown filesystem: $key"; return 1 ;;
    esac
}

hosts_filesystem_remote_path() {
    local key="$1" kind
    kind="$(hosts_filesystem_kind "$key")"
    case "$kind" in
        machine) _hosts_json | jq -r --arg k "$key" '.machines[$k].remote_path' ;;
        group)   _hosts_json | jq -r --arg k "$key" '.groups[$k].remote_path'   ;;
        *)       log_error "Unknown filesystem: $key"; return 1 ;;
    esac
}

hosts_filesystem_local_path() {
    local key="$1" kind
    kind="$(hosts_filesystem_kind "$key")"
    case "$kind" in
        machine) _hosts_json | jq -r --arg k "$key" '.machines[$k].local_path' ;;
        group)   _hosts_json | jq -r --arg k "$key" '.groups[$k].local_path'   ;;
        *)       log_error "Unknown filesystem: $key"; return 1 ;;
    esac
}

# Expand a leading ~ to $HOME.
hosts_expand_path() {
    local path="$1"
    if [[ "$path" == "~/"* ]]; then
        echo "$HOME/${path:2}"
    elif [[ "$path" == "~" ]]; then
        echo "$HOME"
    else
        echo "$path"
    fi
}

# Default local landing directory for sync.
hosts_sync_root_default_local() {
    echo "~/Code"
}

# Resolve SSH alias to filesystem context: kind, inventory key, remote_path, local_path (tab-separated).
hosts_ssh_alias_context() {
    local alias="$1" json machine_remote group
    json="$(_hosts_json)" || return 1

    machine_remote="$(jq -r --arg a "$alias" '.machines[$a].remote_path // empty' <<<"$json")"
    if [[ -n "$machine_remote" ]]; then
        local local_path=""
        local_path="$(jq -r --arg a "$alias" '.machines[$a].local_path // empty' <<<"$json")"
        printf '%s\t%s\t%s\t%s\n' "machine" "$alias" "$machine_remote" "$local_path"
        return 0
    fi

    group="$(jq -r --arg a "$alias" '.groups // {} | to_entries[] | select(.value.machines[]? == $a) | .key' <<<"$json" | head -n1)"
    if [[ -n "$group" ]]; then
        local remote_path="" local_path=""
        remote_path="$(jq -r --arg g "$group" '.groups[$g].remote_path // empty' <<<"$json")"
        local_path="$(jq -r --arg g "$group" '.groups[$g].local_path // empty' <<<"$json")"
        if [[ -n "$remote_path" ]]; then
            printf '%s\t%s\t%s\t%s\n' "group" "$group" "$remote_path" "$local_path"
            return 0
        fi
    fi

    log_error "No filesystem context for SSH alias: $alias"
    return 1
}

# Remote path spec for sync_root (string or .remote from table).
hosts_sync_root_remote_spec() {
    local kind="$1" key="$2"
    _hosts_json | jq -r --arg kind "$kind" --arg key "$key" '
        (.defaults.sync_root // "Code") as $default |
        (if $kind == "machine" then
            .machines[$key].sync_root // $default
        else
            .groups[$key].sync_root // $default
        end) |
        if type == "string" then .
        elif type == "object" then .remote // "Code"
        else "Code" end
    '
}

# Local landing path for sync_root (defaults to ~/Code).
hosts_sync_root_local() {
    local kind="$1" key="$2" json local_override
    json="$(_hosts_json)" || return 1
    local_override="$(jq -r --arg kind "$kind" --arg key "$key" '
        (if $kind == "machine" then
            .machines[$key].sync_root // null
        else
            .groups[$key].sync_root // null
        end) |
        if type == "object" then .local // empty else empty end
    ' <<<"$json")"
    if [[ -n "$local_override" ]]; then
        echo "$local_override"
    else
        hosts_sync_root_default_local
    fi
}

# Full remote base path for sync_root (absolute on the server).
hosts_sync_root_remote_base() {
    local kind="$1" key="$2" json remote_path remote_spec
    json="$(_hosts_json)" || return 1

    case "$kind" in
        machine) remote_path="$(jq -r --arg k "$key" '.machines[$k].remote_path' <<<"$json")" ;;
        group) remote_path="$(jq -r --arg k "$key" '.groups[$k].remote_path' <<<"$json")" ;;
        *)
            log_error "Unknown context kind: $kind"
            return 1
            ;;
    esac

    remote_spec="$(hosts_sync_root_remote_spec "$kind" "$key")" || return 1
    if [[ -z "$remote_spec" ]]; then
        log_error "Empty sync_root for $kind $key"
        return 1
    fi

    if [[ "$remote_spec" == /* ]]; then
        echo "$remote_spec"
    else
        echo "$remote_path/$remote_spec"
    fi
}
