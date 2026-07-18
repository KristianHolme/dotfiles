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
After ControlMaster is up, syncs the local Omarchy theme to that host
(dotfiles-theme-sync-remote.sh) before attaching tmux.
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

ensure_ssh_controlmaster "$SELECTED"

# Align remote Omarchy theme with this machine before attaching tmux
if [[ -x "$SCRIPT_DIR/dotfiles-theme-sync-remote.sh" ]]; then
	echo "🎨 Syncing Omarchy theme to $SELECTED..."
	"$SCRIPT_DIR/dotfiles-theme-sync-remote.sh" --host "$SELECTED" ||
		log_warning "Theme sync to $SELECTED failed; continuing connect"
	echo
fi

# Connect with SSH and handle tmux sessions
# -t forces pseudo-terminal allocation (needed for tmux)
# Attach or create named session with UTF-8 env and UTF-8 client
ssh "$SELECTED" -t 'printf "\033]0;%s\007" "$(hostname -s)"; tmux -u new-session -A -s main'

echo
echo "✅ Disconnected from $SELECTED"
