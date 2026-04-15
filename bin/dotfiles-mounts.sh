#!/bin/bash

# SSHFS Mount Manager - Simple TUI and CLI for managing remote mounts
# Uses systemd user units for mounting, templates for definitions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Paths
TEMPLATES_DIR="$(realpath "$SCRIPT_DIR/../templates/systemd/user")"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Get local hostname
get_hostname() {
	hostname | cut -d. -f1
}

# List all available mount templates (excluding local hostname)
list_available_mounts() {
	if [[ ! -d "$TEMPLATES_DIR" ]]; then
		return 0
	fi
	local local_host
	local_host=$(get_hostname)
	find "$TEMPLATES_DIR" -name "*.mount" -type f 2>/dev/null | while read -r f; do
		local mount_name
		mount_name=$(basename "$f" .mount | sed 's/^mnt-//')
		# Skip mounts that point to the local host (can't SSH to self)
		if [[ "$mount_name" != "$local_host" ]]; then
			echo "$mount_name"
		fi
	done | sort
}

# Check if a mount is enabled (has symlink and systemd enabled)
is_mount_enabled() {
	local mount_name="$1"
	local target_link="$SYSTEMD_USER_DIR/mnt-$mount_name.mount"
	[[ -L "$target_link" ]] && systemctl --user is-enabled "mnt-$mount_name.mount" &>/dev/null
}

# Check if a mount is currently active
is_mount_active() {
	local mount_name="$1"
	systemctl --user is-active "mnt-$mount_name.mount" &>/dev/null
}

# Enable a mount
do_enable() {
	local mount_name="$1"
	local template_file="$TEMPLATES_DIR/mnt-$mount_name.mount"
	local target_link="$SYSTEMD_USER_DIR/mnt-$mount_name.mount"
	
	# Check if template exists
	if [[ ! -f "$template_file" ]]; then
		log_error "Mount template not found: mnt-$mount_name.mount"
		return 1
	fi
	
	# Check if already enabled
	if [[ -L "$target_link" ]]; then
		log_info "$mount_name is already enabled"
		return 0
	fi
	
	# Create symlink and enable
	mkdir -p "$SYSTEMD_USER_DIR"
	ln -s "$template_file" "$target_link"
	systemctl --user daemon-reload
	systemctl --user enable "mnt-$mount_name.mount" 2>/dev/null || true
	
	log_success "Enabled $mount_name"
}

# Disable a mount
do_disable() {
	local mount_name="$1"
	local target_link="$SYSTEMD_USER_DIR/mnt-$mount_name.mount"
	
	# Check if already disabled
	if [[ ! -L "$target_link" ]] && [[ ! -f "$target_link" ]]; then
		log_info "$mount_name is already disabled"
		return 0
	fi
	
	# Stop, disable, and remove symlink
	if systemctl --user is-active "mnt-$mount_name.mount" &>/dev/null; then
		systemctl --user stop "mnt-$mount_name.mount" 2>/dev/null || true
	fi
	if systemctl --user is-enabled "mnt-$mount_name.mount" &>/dev/null; then
		systemctl --user disable "mnt-$mount_name.mount" 2>/dev/null || true
	fi
	
	rm -f "$target_link"
	systemctl --user daemon-reload
	
	log_success "Disabled $mount_name"
}

# Interactive TUI
interactive_tui() {
	if ! command -v gum &>/dev/null; then
		log_error "gum is required for interactive mode. Install with: pacman -S gum"
		return 1
	fi
	
	local available_mounts
	available_mounts=$(list_available_mounts)
	
	if [[ -z "$available_mounts" ]]; then
		log_error "No mount templates found"
		return 1
	fi
	
	# Build options with current status
	local options=()
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue
		
		local status=""
		if is_mount_active "$mount_name"; then
			status=" (active)"
		elif is_mount_enabled "$mount_name"; then
			status=" (enabled)"
		fi
		
		if [[ -n "$status" ]]; then
			options+=("$mount_name$status")
		else
			options+=("$mount_name")
		fi
	done <<< "$available_mounts"
	
	# Show picker
	gum style --foreground 212 "Toggle mounts with space, confirm with enter"
	echo
	
	local selected
	selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected-prefix="✅ " --unselected-prefix="❌ " --cursor-prefix="❌ ")
	
	if [[ -z "$selected" ]]; then
		log_info "No selection made"
		return 0
	fi
	
	# Apply selections
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		local mount_name
		mount_name=$(echo "$line" | awk '{print $1}')
		
		# Check current state and toggle
		if is_mount_enabled "$mount_name"; then
			do_disable "$mount_name"
		else
			do_enable "$mount_name"
		fi
	done <<< "$selected"
}

# List status
list_status() {
	log_info "Mount status"
	
	local available_mounts
	available_mounts=$(list_available_mounts)
	
	if [[ -z "$available_mounts" ]]; then
		log_info "No mounts available"
		return 0
	fi
	
	printf "\n%-15s %-10s %-10s %-10s\n" "Mount" "Enabled" "Active" "Status"
	printf "%-15s %-10s %-10s %-10s\n" "---------------" "----------" "----------" "----------"
	
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue
		
		local enabled="no"
		local active="no"
		local status="available"
		
		if is_mount_enabled "$mount_name"; then
			enabled="yes"
			status="enabled"
		fi
		if is_mount_active "$mount_name"; then
			active="yes"
			status="active"
		fi
		
		printf "%-15s %-10s %-10s %-10s\n" "$mount_name" "$enabled" "$active" "$status"
	done <<< "$available_mounts"
	echo
}

# Show help
show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [MOUNT...]

Manage SSHFS mounts with interactive TUI or command-line operations.

OPTIONS:
    -i, --interactive   Interactive TUI (default when no args)
    -l, --list          List current mount status
    -e, --enable        Enable mount(s)
    -d, --disable       Disable mount(s)
    -h, --help          Show this help

EXAMPLES:
    $(basename "$0")                  # Interactive TUI
    $(basename "$0") -l               # List status
    $(basename "$0") -e sibir         # Enable sibir mount
    $(basename "$0") -e sibir claw    # Enable multiple mounts
    $(basename "$0") -d claw          # Disable claw mount
    $(basename "$0") -d claw sibir   # Disable multiple mounts

NOTES:
    - Can combine --enable and --disable for different mounts
    - Must specify mount name(s) with --enable/--disable
    - Same mount in both --enable and --disable is an error
    - Available mounts are read from templates/systemd/user/
EOF
}

# Main
main() {
	local mode=""
	local enable_mounts=()
	local disable_mounts=()
	local current_mode=""
	
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-i|--interactive)
				if [[ -n "$mode" && "$mode" != "interactive" ]]; then
					log_error "Cannot use --interactive with other modes"
					exit 1
				fi
				mode="interactive"
				current_mode=""
				shift
				;;
			-l|--list)
				if [[ -n "$mode" && "$mode" != "list" ]]; then
					log_error "Cannot use --list with other modes"
					exit 1
				fi
				mode="list"
				current_mode=""
				shift
				;;
			-e|--enable)
				if [[ -n "$mode" && "$mode" != "cli" ]]; then
					log_error "Cannot use --enable with --interactive, --list, or --help"
					exit 1
				fi
				mode="cli"
				current_mode="enable"
				shift
				;;
			-d|--disable)
				if [[ -n "$mode" && "$mode" != "cli" ]]; then
					log_error "Cannot use --disable with --interactive, --list, or --help"
					exit 1
				fi
				mode="cli"
				current_mode="disable"
				shift
				;;
			-h|--help)
				show_help
				exit 0
				;;
			-*)
				log_error "Unknown option: $1"
				show_help
				exit 1
				;;
			*)
				# Collect mount names for current mode
				if [[ "$current_mode" == "enable" ]]; then
					enable_mounts+=("$1")
				elif [[ "$current_mode" == "disable" ]]; then
					disable_mounts+=("$1")
				else
					log_error "Mount name '$1' without --enable or --disable"
					show_help
					exit 1
				fi
				shift
				;;
		esac
	done
	
	# Check for conflicts: same mount in both enable and disable
	for m in "${enable_mounts[@]}"; do
		for d in "${disable_mounts[@]}"; do
			if [[ "$m" == "$d" ]]; then
				log_error "Cannot enable and disable the same mount: $m"
				exit 1
			fi
		done
	done
	
	# Default to interactive if no mode specified
	if [[ -z "$mode" ]]; then
		mode="interactive"
	fi
	
	# Execute based on mode
	case "$mode" in
		interactive)
			interactive_tui
			;;
		list)
			list_status
			;;
		cli)
			# Validate we have mounts to process
			if [[ ${#enable_mounts[@]} -eq 0 && ${#disable_mounts[@]} -eq 0 ]]; then
				log_error "Mount name(s) required. Use --enable or --disable"
				exit 1
			fi
			# Process enables first
			for m in "${enable_mounts[@]}"; do
				do_enable "$m"
			done
			# Then disables
			for m in "${disable_mounts[@]}"; do
				do_disable "$m"
			done
			;;
	esac
}

main "$@"
