#!/bin/bash

# SSHFS Mount Manager - Interactive TUI for enabling/disabling remote mounts
# Uses gum for interactive selection and systemd user units for mounting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

# Paths
TEMPLATES_DIR="$(realpath "$SCRIPT_DIR/../templates/systemd/user")"
CONFIG_DIR="$HOME/.config/dotfiles"
CONFIG_FILE="$CONFIG_DIR/mounts.conf"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Get current profile from dotfiles or default
get_profile() {
	local profile="${DOTFILES_PROFILE:-}"
	if [[ -z "$profile" ]]; then
		# Try to infer from hostname
		profile=$(hostname)
	fi
	echo "$profile"
}

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

# Read enabled mounts from config (excluding local hostname)
get_enabled_mounts() {
	local profile="${1:-$(get_profile)}"
	local local_host
	local_host=$(get_hostname)
	if [[ ! -f "$CONFIG_FILE" ]]; then
		return 0
	fi
	# Parse: profile: mount1 mount2, filter out local host
	grep "^$profile:" "$CONFIG_FILE" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | grep -v '^$' | while read -r mount; do
		if [[ "$mount" != "$local_host" ]]; then
			echo "$mount"
		fi
	done | sort -u || true
}

# Save enabled mounts to config
save_enabled_mounts() {
	local profile="${1:-$(get_profile)}"
	shift
	local mounts=("$@")
	
	mkdir -p "$CONFIG_DIR"
	
	# Read existing config, remove this profile's line, add new one
	local temp_file
	temp_file=$(mktemp)
	
	if [[ -f "$CONFIG_FILE" ]]; then
		grep -v "^$profile:" "$CONFIG_FILE" > "$temp_file" 2>/dev/null || true
	fi
	
	# Add new entry if there are mounts
	if [[ ${#mounts[@]} -gt 0 ]]; then
		echo "$profile: ${mounts[*]}" >> "$temp_file"
	fi
	
	# Sort and save
	sort "$temp_file" > "$CONFIG_FILE"
	rm "$temp_file"
}

# Check if a mount is currently active in systemd
is_mount_active() {
	local mount_name="$1"
	systemctl --user is-active "$mount_name" &>/dev/null
}

# Check if a mount is enabled in systemd
is_mount_enabled() {
	local mount_name="$1"
	systemctl --user is-enabled "$mount_name" &>/dev/null
}

# Apply mounts: symlink templates → systemd, enable selected, disable others
apply_mounts() {
	local profile="${1:-$(get_profile)}"
	shift
	local enabled_mounts=("$@")
	
	log_info "Applying mounts for profile: $profile"
	
	mkdir -p "$SYSTEMD_USER_DIR"
	
	# Get all available mounts
	local all_mounts
	all_mounts=$(list_available_mounts)
	
	# Process each available mount
	while IFS= read -r avail_mount; do
		[[ -z "$avail_mount" ]] && continue
		
		local template_file="$TEMPLATES_DIR/mnt-$avail_mount.mount"
		local target_link="$SYSTEMD_USER_DIR/mnt-$avail_mount.mount"
		
		if [[ " ${enabled_mounts[*]} " =~ " $avail_mount " ]]; then
			# Enable this mount
			if [[ -f "$template_file" ]]; then
				if [[ -L "$target_link" ]]; then
					# Update symlink if needed
					local current_target
					current_target=$(readlink "$target_link")
					if [[ "$current_target" != "$template_file" ]]; then
						rm -f "$target_link"
						ln -s "$template_file" "$target_link"
						log_info "Updated mnt-$avail_mount.mount"
					fi
				elif [[ -e "$target_link" ]]; then
					# Backup existing file
					mv "$target_link" "$target_link.bak.$(date +%Y%m%d%H%M%S)"
					ln -s "$template_file" "$target_link"
					log_info "Replaced mnt-$avail_mount.mount with template"
				else
					# Create new symlink
					ln -s "$template_file" "$target_link"
					log_info "Added mnt-$avail_mount.mount"
				fi
				
				# Enable and start
				systemctl --user daemon-reload
				if ! systemctl --user is-enabled "mnt-$avail_mount.mount" &>/dev/null; then
					systemctl --user enable "mnt-$avail_mount.mount" 2>/dev/null || true
				fi
			fi
		else
			# Disable this mount
			if [[ -L "$target_link" ]] || [[ -f "$target_link" ]]; then
				log_info "Removing mnt-$avail_mount.mount"
				
				# Stop and disable if active
				if systemctl --user is-active "mnt-$avail_mount.mount" &>/dev/null; then
					systemctl --user stop "mnt-$avail_mount.mount" 2>/dev/null || true
				fi
				if systemctl --user is-enabled "mnt-$avail_mount.mount" &>/dev/null; then
					systemctl --user disable "mnt-$avail_mount.mount" 2>/dev/null || true
				fi
				
				rm -f "$target_link"
			fi
		fi
	done <<< "$all_mounts"
	
	systemctl --user daemon-reload
	log_success "Mounts applied for profile: $profile"
}

# Interactive TUI using gum
interactive_tui() {
	if ! command -v gum &>/dev/null; then
		log_error "gum is required for interactive mode. Install with: pacman -S gum"
		return 1
	fi
	
	local profile
	profile=$(get_profile)
	
	log_info "Managing mounts for profile: $profile"
	
	# Get available and enabled mounts
	local available_mounts enabled_mounts
	available_mounts=$(list_available_mounts)
	enabled_mounts=$(get_enabled_mounts "$profile")
	
	if [[ -z "$available_mounts" ]]; then
		log_error "No mount templates found in $TEMPLATES_DIR"
		return 1
	fi
	
	# Build options with status (without manual checkbox prefix - let gum handle it)
	local -A mount_status
	local options=()
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue
		
		local status=""
		if echo "$enabled_mounts" | grep -q "^$mount_name$"; then
			if is_mount_active "mnt-$mount_name.mount"; then
				status="active"
			elif is_mount_enabled "mnt-$mount_name.mount"; then
				status="enabled"
			else
				status="selected"
			fi
		fi
		mount_status["$mount_name"]="$status"
		# Just mount names, no status in text (status is separate)
		options+=("$mount_name")
	done <<< "$available_mounts"
	
	# Build comma-separated list of enabled mounts for preselection
	local preselected
	preselected=$(echo "$enabled_mounts" | tr '\n' ',' | sed 's/,$//')
	
	# Show interactive picker
	gum style --foreground 212 "Toggle mounts with space, confirm with enter"
	gum style --foreground 240 "Mounts for profile: $profile"
	echo
	
	# Use gum with checkboxes and preselection
	local selected
	if [[ -n "$preselected" ]]; then
		selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected-prefix="✅ " --unselected-prefix="❌ " --cursor-prefix="❌ " --selected="$preselected")
	else
		selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected-prefix="✅ " --unselected-prefix="❌ " --cursor-prefix="❌ ")
	fi
	
	# Check if user cancelled (ESC) or made no selection
	if [[ -z "$selected" ]]; then
		log_info "No selection made, keeping current configuration"
		return 0
	fi
	
	# Parse selections (all returned lines are selected)
	local new_enabled=()
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		new_enabled+=("$line")
	done <<< "$selected"
	
	# Save and apply
	if [[ ${#new_enabled[@]} -gt 0 ]]; then
		log_info "Enabling: ${new_enabled[*]}"
	else
		log_info "Disabling all mounts"
	fi
	
	save_enabled_mounts "$profile" "${new_enabled[@]}"
	apply_mounts "$profile" "${new_enabled[@]}"
}

# List current status
list_status() {
	local profile
	profile=$(get_profile)
	
	log_info "Mount status for profile: $profile"
	
	local available_mounts enabled_mounts
	available_mounts=$(list_available_mounts)
	enabled_mounts=$(get_enabled_mounts "$profile")
	
	printf "\n%-15s %-10s %-10s %-10s\n" "Mount" "Selected" "Enabled" "Active"
	printf "%-15s %-10s %-10s %-10s\n" "---------------" "----------" "----------" "----------"
	
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue
		
		local selected="no"
		local enabled="no"
		local active="no"
		
		if echo "$enabled_mounts" | grep -q "^$mount_name$"; then
			selected="yes"
		fi
		if is_mount_enabled "mnt-$mount_name.mount"; then
			enabled="yes"
		fi
		if is_mount_active "mnt-$mount_name.mount"; then
			active="yes"
		fi
		
		printf "%-15s %-10s %-10s %-10s\n" "$mount_name" "$selected" "$enabled" "$active"
	done <<< "$available_mounts"
	echo
}

# Enable a specific mount
enable_mount() {
	local mount_name="$1"
	local profile="${2:-$(get_profile)}"
	
	# Check if mount exists
	if [[ ! -f "$TEMPLATES_DIR/mnt-$mount_name.mount" ]]; then
		log_error "Mount template not found: mnt-$mount_name.mount"
		return 1
	fi
	
	# Check if already enabled
	local enabled_mounts
	enabled_mounts=$(get_enabled_mounts "$profile")
	if echo "$enabled_mounts" | grep -q "^$mount_name$"; then
		log_info "$mount_name is already enabled"
		return 0
	fi
	
	# Add to enabled list
	local new_enabled=()
	while IFS= read -r m; do
		[[ -n "$m" ]] && new_enabled+=("$m")
	done <<< "$enabled_mounts"
	new_enabled+=("$mount_name")
	
	save_enabled_mounts "$profile" "${new_enabled[@]}"
	apply_mounts "$profile" "${new_enabled[@]}"
	log_success "Enabled $mount_name"
}

# Disable a specific mount
disable_mount() {
	local mount_name="$1"
	local profile="${2:-$(get_profile)}"
	
	# Check if already disabled
	local enabled_mounts
	enabled_mounts=$(get_enabled_mounts "$profile")
	if ! echo "$enabled_mounts" | grep -q "^$mount_name$"; then
		log_info "$mount_name is already disabled"
		return 0
	fi
	
	# Remove from enabled list
	local new_enabled=()
	while IFS= read -r m; do
		[[ "$m" == "$mount_name" ]] && continue
		[[ -n "$m" ]] && new_enabled+=("$m")
	done <<< "$enabled_mounts"
	
	save_enabled_mounts "$profile" "${new_enabled[@]}"
	apply_mounts "$profile" "${new_enabled[@]}"
	log_success "Disabled $mount_name"
}

# Show help
show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Manage SSHFS mounts with interactive TUI or command-line operations.

OPTIONS:
    -i, --interactive   Interactive TUI (default)
    -l, --list          List current mount status
    -a, --apply         Apply saved configuration
    -e, --enable NAME   Enable specific mount
    -d, --disable NAME  Disable specific mount
    -p, --profile NAME  Use specific profile (default: hostname)
    -h, --help          Show this help

ENVIRONMENT:
    DOTFILES_PROFILE    Override detected profile

EXAMPLES:
    $(basename "$0")                  # Interactive mode
    $(basename "$0") -l               # List status
    $(basename "$0") -e sibir         # Enable sibir mount
    $(basename "$0") -e sibir claw    # Enable multiple mounts
    $(basename "$0") -d claw           # Disable claw mount
    $(basename "$0") -d claw sibir    # Disable multiple mounts
    $(basename "$0") -p bengal        # Use bengal profile
EOF
}

# Main
main() {
	local mode="interactive"
	local profile_override=""
	local target_mounts=()
	
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-i|--interactive)
				mode="interactive"
				shift
				;;
			-l|--list)
				mode="list"
				shift
				;;
			-a|--apply)
				mode="apply"
				shift
				;;
			-e|--enable)
				mode="enable"
				shift
				# Collect all mount names until next option or end
				while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
					target_mounts+=("$1")
					shift
				done
				;;
			-d|--disable)
				mode="disable"
				shift
				# Collect all mount names until next option or end
				while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
					target_mounts+=("$1")
					shift
				done
				;;
			-p|--profile)
				profile_override="$2"
				shift 2
				;;
			-h|--help)
				show_help
				exit 0
				;;
			*)
				log_error "Unknown option: $1"
				show_help
				exit 1
				;;
			esac
	done
	
	# Set profile override if provided
	if [[ -n "$profile_override" ]]; then
		export DOTFILES_PROFILE="$profile_override"
	fi
	
	# Validate mount names for enable/disable modes
	if [[ "$mode" == "enable" || "$mode" == "disable" ]]; then
		if [[ ${#target_mounts[@]} -eq 0 ]]; then
			log_error "Mount name(s) required for --enable/--disable"
			show_help
			exit 1
		fi
	fi
	
	case "$mode" in
		interactive)
			interactive_tui
			;;
		list)
			list_status
			;;
		apply)
			local profile enabled
			profile=$(get_profile)
			enabled=$(get_enabled_mounts "$profile")
			apply_mounts "$profile" $enabled
			;;
		enable)
			for mount in "${target_mounts[@]}"; do
				enable_mount "$mount"
			done
			;;
		disable)
			for mount in "${target_mounts[@]}"; do
				disable_mount "$mount"
			done
			;;
	esac
}

main "$@"
