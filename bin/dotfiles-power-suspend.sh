#!/usr/bin/env bash
set -Eeuo pipefail

# Configure power button to suspend instead of shutdown
# Creates systemd logind drop-in configuration

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0

Writes systemd logind drop-in (HandlePowerKey=suspend) and offers gum menu:
reboot, restart logind+Hyprland, or defer. Uses sudo.
EOF
    exit 0
fi

echo "[power-suspend] Setting up power button (suspend on press)"

# Create systemd logind drop-in config
sudo mkdir -p /etc/systemd/logind.conf.d
echo '[Login]
HandlePowerKey=suspend' | sudo tee /etc/systemd/logind.conf.d/power-button.conf >/dev/null

echo "[power-suspend] Power button config created successfully!"
echo

# Use gum to choose what to do next
if command -v gum >/dev/null 2>&1; then
    choice=$(gum choose --header "How would you like to apply the changes?" \
        "Reboot computer (safest)" \
        "Restart systemd-logind + relaunch Hyprland" \
        "Do nothing (apply on next reboot)")

    case "$choice" in
    "Reboot computer (safest)")
        echo "[power-suspend] Rebooting system..."
        sudo reboot
        ;;
    "Restart systemd-logind + relaunch Hyprland")
        echo "[power-suspend] Restarting systemd-logind and relaunching Hyprland..."
        if command -v hyprctl >/dev/null 2>&1; then
            # Exit Hyprland first, then restart logind
            echo "[power-suspend] Exiting Hyprland..."
            hyprctl dispatch exit &
            sleep 1
            echo "[power-suspend] Restarting systemd-logind..."
            sudo systemctl restart systemd-logind
        else
            echo "[power-suspend] hyprctl not found. Only restarting systemd-logind..."
            sudo systemctl restart systemd-logind
        fi
        ;;
    "Do nothing (apply on next reboot)")
        echo "[power-suspend] Changes will take effect after next reboot."
        ;;
    esac
else
    echo "[power-suspend] Install 'gum' for interactive menu, or reboot to apply changes."
fi
