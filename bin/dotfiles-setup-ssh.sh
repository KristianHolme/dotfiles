#!/bin/bash
set -Eeuo pipefail

# SSH setup script
# - Adds ed25519 key to ssh-agent if not present
# - Copies public key to one node per mountable filesystem in hosts.toml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-hosts.sh
source "$SCRIPT_DIR/lib-hosts.sh"

log() { echo -e "[ssh-setup] $*"; }
err() { echo -e "[ssh-setup][ERROR] $*" >&2; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0

Add ed25519 key to ssh-agent and ssh-copy-id to one node per mountable
filesystem selected from hosts.toml.

Standalone machine filesystems use that machine alias. Group filesystems use
their mount_via alias. Group filesystems are preselected; standalone machine
filesystems are left unselected by default so Tailscale machines can be skipped.
Requires ~/.ssh/id_ed25519 and .pub.
EOF
    exit 0
fi

KEY_FILE="$HOME/.ssh/id_ed25519"
PUB_KEY_FILE="$HOME/.ssh/id_ed25519.pub"

# Check if key exists
if [[ ! -f "$KEY_FILE" ]]; then
    err "SSH key not found: $KEY_FILE"
    err "Generate it with: ssh-keygen -t ed25519"
    exit 1
fi

if [[ ! -f "$PUB_KEY_FILE" ]]; then
    err "Public key not found: $PUB_KEY_FILE"
    exit 1
fi

# Add key to ssh-agent if not already present
if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$KEY_FILE" | awk '{print $2}')"; then
    log "Adding SSH key to agent..."
    ssh-add "$KEY_FILE"
else
    log "SSH key already in agent"
fi

get_hostname() {
    hostname | cut -d. -f1
}

choose_mount_targets() {
    ensure_cmd gum

    local local_host key kind host label selected selected_arg
    local_host="$(get_hostname)"
    local options=()
    local preselected=()
    declare -gA TARGET_HOST_BY_LABEL=()

    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        kind="$(hosts_filesystem_kind "$key")" || continue
        host="$(hosts_filesystem_host "$key")" || continue
        [[ "$host" == "$local_host" ]] && continue

        label="${key} -> ${host}"
        options+=("$label")
        TARGET_HOST_BY_LABEL["$label"]="$host"

        if [[ "$kind" == "group" ]]; then
            preselected+=("$label")
        fi
    done < <(hosts_filesystems)

    if [[ ${#options[@]} -eq 0 ]]; then
        return 0
    fi

    selected_arg=""
    if [[ ${#preselected[@]} -gt 0 ]]; then
        selected_arg=$(IFS=,; echo "${preselected[*]}")
    fi

    gum style --foreground 212 "Choose filesystems whose mount node should receive your SSH key"
    echo

    if ! selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected-prefix="✓ " --unselected-prefix="  " --cursor-prefix="> " --selected="$selected_arg"); then
        return 1
    fi

    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        printf '%s\n' "${TARGET_HOST_BY_LABEL[$label]}"
    done <<<"$selected" | sort -u
}

mapfile -t SERVERS < <(choose_mount_targets)

if [[ ${#SERVERS[@]} -eq 0 ]]; then
    log "No SSH targets selected"
    exit 0
fi

log "Copying SSH key to ${#SERVERS[@]} selected servers from $(hosts_toml_path)..."

for server in "${SERVERS[@]}"; do
    log "Copying to $server..."
    if ssh-copy-id -i "$PUB_KEY_FILE" "$server" 2>/dev/null; then
        log "✓ Successfully copied to $server"
    else
        err "✗ Failed to copy to $server"
    fi
done

log "SSH setup complete!"
log "Test with: ssh abacus-as"
