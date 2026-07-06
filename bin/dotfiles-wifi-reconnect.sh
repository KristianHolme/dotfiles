#!/usr/bin/env bash

# Pick a WiFi access point by BSSID and connect with nmcli.
# Usage: ./dotfiles-wifi-reconnect.sh SSID

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-gum.sh"
omarchy_gum_env_load

usage() {
    cat <<EOF
Usage: $0 SSID

Scan for access points matching SSID, pick one with gum, connect by BSSID.
Current AP is marked with * in the list.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 1 || -z "$1" ]]; then
    usage >&2
    exit 1
fi

SSID="$1"

ensure_cmd gum nmcli

if [[ ! -t 0 ]]; then
    log_error "Interactive terminal required for gum menu"
    exit 1
fi

log_info "Scanning for access points matching '$SSID'..."

mapfile -t AP_ROWS < <(
    nmcli -m multiline -f IN-USE,BSSID,SSID,MODE,CHAN,RATE,SIGNAL,BARS,SECURITY \
        device wifi list --rescan yes 2>/dev/null | awk -v target="$SSID" '
        function trim(s) {
            sub(/^[ \t]+/, "", s)
            sub(/[ \t]+$/, "", s)
            return s
        }
        function field_value(line) {
            return trim(substr(line, index(line, ":") + 1))
        }
        BEGIN { FS = "\034" }
        function flush() {
            if (ssid == target && bssid != "") {
                print inuse FS bssid FS ssid FS mode FS chan FS rate FS signal FS bars FS security
            }
            inuse = ""
            bssid = ""
            ssid = ""
            mode = ""
            chan = ""
            rate = ""
            signal = ""
            bars = ""
            security = ""
        }
        /^IN-USE:/ { flush(); inuse = field_value($0); next }
        /^BSSID:/ { bssid = field_value($0); next }
        /^SSID:/ { ssid = field_value($0); next }
        /^MODE:/ { mode = field_value($0); next }
        /^CHAN:/ { chan = field_value($0); next }
        /^RATE:/ { rate = field_value($0); next }
        /^SIGNAL:/ { signal = field_value($0); next }
        /^BARS:/ { bars = field_value($0); next }
        /^SECURITY:/ {
            security = field_value($0)
            flush()
            next
        }
        END { flush() }
    '
)

if ((${#AP_ROWS[@]} == 0)); then
    log_error "No access points found for SSID '$SSID'"
    log_info "Check spelling or try moving closer to the network"
    exit 1
fi

DISPLAY_LINES=()
BSSIDS=()

# gum trims leading ASCII spaces on menu items; use NBSP for inactive IN-USE column.
INACTIVE_MARKER="$(printf '\302\240%.0s' {1..8})"

for row in "${AP_ROWS[@]}"; do
    IFS=$'\034' read -r inuse bssid ssid mode chan rate signal bars security <<<"$row"

    if [[ "$inuse" == "*" ]]; then
        marker="*       "
    else
        marker="$INACTIVE_MARKER"
    fi

    DISPLAY_LINES+=("$(
        printf '%-8s%-19s%-13s%-7s%-6s%-13s%-8s%-8s  %s' \
            "$marker" "$bssid" "$ssid" "$mode" "$chan" "$rate" "$signal" "$bars" "$security"
    )")
    BSSIDS+=("$bssid")
done

SELECTED=$(
    printf '%s\n' "${DISPLAY_LINES[@]}" | gum choose \
        --height "$((${#DISPLAY_LINES[@]} + 2))" \
        --header "Select access point for $SSID (current AP marked with *)"
) || true

if [[ -z "$SELECTED" ]]; then
    exit 0
fi

SELECTED_BSSID=""
for i in "${!DISPLAY_LINES[@]}"; do
    if [[ "${DISPLAY_LINES[$i]}" == "$SELECTED" ]]; then
        SELECTED_BSSID="${BSSIDS[$i]}"
        break
    fi
done

if [[ -z "$SELECTED_BSSID" ]]; then
    log_error "Could not resolve selected access point"
    exit 1
fi

log_info "Connecting to $SELECTED_BSSID..."
if nmcli device wifi connect "$SELECTED_BSSID"; then
    log_success "Connected to $SELECTED_BSSID ($SSID)"
else
    log_error "Failed to connect to $SELECTED_BSSID"
    exit 1
fi
