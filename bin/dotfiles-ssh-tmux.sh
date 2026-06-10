#!/usr/bin/env bash

# Simple SSH + tmux connection script
# Usage: ./dotfiles-ssh-tmux.sh
# Select a server and connect with automatic tmux session management

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0

Pick an SSH host with gum filter, connect with tmux session management.
Server list comes from hosts.toml (set HOSTS_TOML to override).
EOF
    exit 0
fi

ensure_cmd gum

readarray -t SERVERS < <(hosts_all_machines)

# Hide current host from selection
CURRENT_HOST="$(hosts_local_hostname)"
FILTERED=$(printf '%s\n' "${SERVERS[@]}" | awk -v h="$CURRENT_HOST" 'tolower($0)!=tolower(h)')

# Let user choose server with fuzzy finding
SELECTED=$(printf '%s\n' "$FILTERED" | gum filter \
    --header "🔍 Choose server to connect to:" \
    --placeholder "Type to search servers..." \
    --prompt "❯ ")

if [ -z "$SELECTED" ]; then
    echo "❌ No server selected. Exiting."
    exit 0
fi

echo "🚀 Connecting to $SELECTED..."
echo "   - Will attach to existing tmux session or create new one"
echo "   - Use Ctrl+D or 'exit' to disconnect"
echo

# Hosts with ControlMaster in ~/.ssh/config (detected via ssh -G):
# start a background master if none is alive yet.
ensure_ssh_controlmaster() {
    local host="$1" cm=""

    cm=$(ssh -G "$host" 2>/dev/null | awk '$1 == "controlmaster" { print $2; exit }')
    case "$cm" in
    auto | autoask | yes | ask) ;;
    *) return 0 ;;
    esac

    # ssh -O check is authoritative: master alive means nothing to do
    if ssh -O check "$host" >/dev/null 2>&1; then
        return 0
    fi

    echo "🔐 Starting background master connection for $host..."
    echo "   (This will prompt for 2FA + password once)"
    # -fN: background after auth, no remote command; -CX: compression + X11
    if ssh -CX -o ServerAliveInterval=30 -fN "$host"; then
        echo "✅ Master connection established"
    else
        echo "⚠️  Failed to start master connection, continuing anyway..."
    fi
    echo
}

ensure_ssh_controlmaster "$SELECTED"

# Connect with SSH and handle tmux sessions
# -t forces pseudo-terminal allocation (needed for tmux)
# Attach or create named session with UTF-8 env and UTF-8 client
ssh "$SELECTED" -t 'printf "\033]0;%s\007" "$(hostname -s)"; tmux -u new-session -A -s main'

echo
echo "✅ Disconnected from $SELECTED"
