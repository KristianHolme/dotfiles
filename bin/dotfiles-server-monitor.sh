#!/usr/bin/env bash

# Server monitor: tmux session with one window per selected SSH server, each running btop.
# Usage: ./dotfiles-server-monitor.sh
# Host inventory comes from hosts.toml (lib-hosts.sh); group members are selected by default.
# When run in Ghostty, the tab title is set to "server-monitor".

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

SESSION_NAME="server-monitor"
TAB_TITLE=$SESSION_NAME

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0

Tmux session with one window per SSH host; pick hosts with gum (Space, Enter).
Hosts come from hosts.toml; group members are preselected. Omits current hostname.
EOF
    exit 0
fi

ensure_cmd gum tmux

CURRENT_HOST="$(hosts_local_hostname)"
FILTERED_SERVERS=()
while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    if [[ "${s,,}" != "${CURRENT_HOST,,}" ]]; then
        FILTERED_SERVERS+=("$s")
    fi
done < <(hosts_all_machines)

# Default selection: members of any group in hosts.toml (the compute clusters)
GROUP_MEMBERS="$(
    while IFS= read -r g; do
        hosts_group_machines "$g"
    done < <(hosts_groups) | sort -u
)"
DEFAULT_SELECTED=()
for s in "${FILTERED_SERVERS[@]}"; do
    if grep -qx "$s" <<<"$GROUP_MEMBERS"; then
        DEFAULT_SELECTED+=("$s")
    fi
done

# Comma-separated for gum --selected
SELECTED_DEFAULT=""
if ((${#DEFAULT_SELECTED[@]} > 0)); then
    SELECTED_DEFAULT=$(
        IFS=','
        echo "${DEFAULT_SELECTED[*]}"
    )
fi

# Multi-select with gum; default set pre-selected (height so all servers visible)
SELECTED_RAW=$(printf '%s\n' "${FILTERED_SERVERS[@]}" | gum choose \
    --no-limit \
    --height="$((${#FILTERED_SERVERS[@]} + 2))" \
    --header "Select servers (Space toggle, Enter confirm). Group members preselected." \
    ${SELECTED_DEFAULT:+--selected="$SELECTED_DEFAULT"} \
    --ordered)

if [[ -z "$SELECTED_RAW" ]]; then
    echo "No servers selected. Exiting."
    exit 0
fi

# Split into array (newline), strip empty entries so every selection gets a window
SELECTED_SERVERS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && SELECTED_SERVERS+=("$line")
done <<<"$SELECTED_RAW"

if ((${#SELECTED_SERVERS[@]} == 0)); then
    echo "No servers selected. Exiting."
    exit 0
fi

# Set Ghostty (and other terminals) tab/window title
printf '\033]0;%s\007' "$TAB_TITLE"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Sync session to new selection: add missing windows, remove unselected ones
    CURRENT_WINDOWS=()
    while IFS= read -r name; do
        CURRENT_WINDOWS+=("$name")
    done < <(tmux list-windows -t "$SESSION_NAME" -F "#W")

    TO_ADD=()
    for s in "${SELECTED_SERVERS[@]}"; do
        if [[ " ${CURRENT_WINDOWS[*]} " != *" $s "* ]]; then
            TO_ADD+=("$s")
        fi
    done
    TO_REMOVE=()
    for w in "${CURRENT_WINDOWS[@]}"; do
        if [[ " ${SELECTED_SERVERS[*]} " != *" $w "* ]]; then
            TO_REMOVE+=("$w")
        fi
    done

    for w in "${TO_REMOVE[@]}"; do
        tmux kill-window -t "${SESSION_NAME}:${w}" 2>/dev/null || true
    done

    # If we killed all windows the session may be gone; create it with new selection
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        first="${SELECTED_SERVERS[0]}"
        tmux new-session -s "$SESSION_NAME" -d -n "$first" "ssh $first -t btop --force-utf"
        for s in "${SELECTED_SERVERS[@]:1}"; do
            tmux new-window -t "$SESSION_NAME" -n "$s" "ssh $s -t btop --force-utf"
        done
    else
        for s in "${TO_ADD[@]}"; do
            tmux new-window -t "$SESSION_NAME" -n "$s" "ssh $s -t btop --force-utf"
        done
    fi

    tmux set-option -t "$SESSION_NAME" set-titles on 2>/dev/null || true
    tmux set-option -t "$SESSION_NAME" set-titles-string "$TAB_TITLE" 2>/dev/null || true
    exec tmux attach -t "$SESSION_NAME"
fi

# Create new session: first window
first="${SELECTED_SERVERS[0]}"
tmux new-session -s "$SESSION_NAME" -d -n "$first" "ssh $first -t btop --force-utf"

# Remaining windows (every selected server gets its own window)
for s in "${SELECTED_SERVERS[@]:1}"; do
    [[ -z "$s" ]] && continue
    tmux new-window -t "$SESSION_NAME" -n "$s" "ssh $s -t btop --force-utf"
done

tmux set-option -t "$SESSION_NAME" set-titles on
tmux set-option -t "$SESSION_NAME" set-titles-string "$TAB_TITLE"
exec tmux attach -t "$SESSION_NAME"
