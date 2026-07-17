#!/usr/bin/env bash
#
# Fix browser audio issues in PipeWire
# Unmutes, uncorks, and sets volume for browser audio streams
#
# Usage: dotfiles-fix-browser-audio.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0

Unmute / uncork PipeWire sink-inputs for browser-like streams (needs active
browser audio). Requires pactl.
EOF
    exit 0
fi

# Check if pactl is available
if ! command -v pactl >/dev/null 2>&1; then
    log_error "pactl not found. Please install pipewire-pulse or pulseaudio."
    exit 1
fi

log_info "Checking for browser audio streams..."

# Get list of sink inputs
sink_inputs=$(pactl list sink-inputs short 2>/dev/null || true)

if [[ -z "$sink_inputs" ]]; then
    log_warning "No active audio streams found. Start playing audio in your browser first."
    exit 0
fi

fixed_count=0

# Process each sink input
while IFS=$'\t' read -r idx rest; do
    # Get application name for this sink input
    app_info=$(pactl list sink-inputs | sed -n "/Sink Input #$idx/,/Sink Input/p" | grep "application.name" | head -1 || true)
    
    if [[ -z "$app_info" ]]; then
        continue
    fi
    
    app_name=$(echo "$app_info" | sed -n 's/.*application.name = "\([^"]*\)".*/\1/p')
    
    # Check if it's a browser
    if [[ "$app_name" =~ (Chromium|Firefox|Chrome|Brave|Edge|Opera|Vivaldi|chromium|firefox|chrome|brave) ]]; then
        log_info "Found $app_name (sink-input $idx) - checking status..."
        
        # Get current status
        sink_info=$(pactl list sink-inputs | sed -n "/Sink Input #$idx/,/Sink Input/p")
        corked=$(echo "$sink_info" | grep -E "^\s*Corked:" | awk '{print $2}' || echo "unknown")
        muted=$(echo "$sink_info" | grep -E "^\s*Mute:" | awk '{print $2}' || echo "unknown")
        volume=$(echo "$sink_info" | grep -E "^\s*Volume:" | head -1 || echo "")
        
        # Fix issues
        needs_fix=false
        
        if [[ "$corked" == "yes" ]]; then
            log_info "  Uncorking stream..."
            pactl cork-sink-input "$idx" 0 2>/dev/null || log_warning "  Failed to uncork"
            needs_fix=true
        fi
        
        if [[ "$muted" == "yes" ]]; then
            log_info "  Unmuting stream..."
            pactl set-sink-input-mute "$idx" 0 2>/dev/null || log_warning "  Failed to unmute"
            needs_fix=true
        fi
        
        # Check if volume is 0%
        if echo "$volume" | grep -q "0%"; then
            log_info "  Setting volume to 100%..."
            pactl set-sink-input-volume "$idx" 100% 2>/dev/null || log_warning "  Failed to set volume"
            needs_fix=true
        fi
        
        if [[ "$needs_fix" == "true" ]]; then
            fixed_count=$((fixed_count + 1))
            log_success "Fixed $app_name (sink-input $idx)"
        else
            log_info "$app_name (sink-input $idx) appears to be working correctly"
        fi
    fi
done <<< "$sink_inputs"

if [[ $fixed_count -eq 0 ]]; then
    log_info "No browser audio streams found or all streams are working correctly."
    log_info "Make sure you have audio playing in your browser."
else
    log_success "Fixed $fixed_count browser audio stream(s)."
fi
