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

# List all available mount templates
list_available_mounts() {
	if [[ ! -d "$TEMPLATES_DIR" ]]; then
		return 0
	fi
	find "$TEMPLATES_DIR" -name "*.mount" -type f 2>/dev/null | while read -r f; do
		basename "$f" .mount | sed 's/^mnt-//'
	done | sort
}

# Read enabled mounts from config
get_enabled_mounts() {
	local profile="${1:-$(get_profile)}"
	if [[ ! -f "$CONFIG_FILE" ]]; then
		return 0
	fi
	# Parse: profile: mount1 mount2
	grep "^$profile:" "$CONFIG_FILE" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | grep -v '^$' | sort -u
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
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue
		
		local template_file="$TEMPLATES_DIR/mnt-$mount_name.mount"
		local target_link="$SYSTEMD_USER_DIR/mnt-$mount_name.mount"
		
		if [[ " ${enabled_mounts[*]} " =~ " $mount_name " ]]; then
			# Enable this mount
			if [[ -f "$template_file" ]]; then
				if [[ -L "$target_link" ]]; then
					# Update symlink if needed
					local current_target
					current_target=$(readlink "$target_link")
					if [[ "$current_target" != "$template_file" ]]; then
						rm "$target_link"
						ln -s "$template_file" "$target_link"
						log_info "Updated mnt-$mount_name.mount"
					fi
				elif [[ -e "$target_link" ]]; then
					# Backup existing file
					mv "$target_link" "$target_link.bak.$(date +%Y%m%d%H%M%S)"
					ln -s "$template_file" "$target_link"
					log_info "Replaced mnt-$mount_name.mount with template"
				else
					# Create new symlink
					ln -s "$template_file" "$target_link"
					log_info "Added mnt-$mount_name.mount"
				fi
				
				# Enable and start
				systemctl --user daemon-reload
				if ! systemctl --user is-enabled "mnt-$mount_name.mount" &>/dev/null; then
					systemctl --user enable "mnt-$mount_name.mount" 2>/dev/null || true
				fi
			fi
		else
			# Disable this mount
			if [[ -L "$target_link" ]] || [[ -f "$target_link" ]]; then
				log_info "Removing mnt-$mount_name.mount"
				
				# Stop and disable if active
				if systemctl --user is-active "mnt-$mount_name.mount" &>/dev/null; then
					systemctl --user stop "mnt-$mount_name.mount" 2>/dev/null || true
				fi
				if systemctl --user is-enabled "mnt-$mount_name.mount" &>/dev/null; then
					systemctl --user disable "mnt-$mount_name.mount" 2>/dev/null || true
				fi
				
				rm "$target_link"
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
	
	# Build checkbox options
	local options=()
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue
		
		local status=""
		if echo "$enabled_mounts" | grep -q "^$mount_name$"; then
			if is_mount_active "mnt-$mount_name.mount"; then
				status=" (active)"
			elif is_mount_enabled "mnt-$mount_name.mount"; then
				status=" (enabled)"
			else
				status=" (selected)"
			fi
			options+=("✓ $mount_name$status")
		else
			options+=("  $mount_name")
		fi
	done <<< "$available_mounts"
	
	# Show interactive picker
	gum style --foreground 212 "Toggle mounts with space, confirm with enter"
	gum style --foreground 240 "Mounts for profile: $profile"
	echo
	
	local selected
	selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected-prefix="[✓] " --unselected-prefix="[ ] " --cursor-prefix="> ")
	
	# Parse selections (remove status text, keep just mount name)
	local new_enabled=()
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		# Extract mount name (remove prefix and status)
		local mount_name
		mount_name=$(echo "$line" | sed 's/^[✓ ]* //' | sed 's/ (.*)$//')
		new_enabled+=("$mount_name")
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

# Show help
show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Manage SSHFS mounts with interactive TUI or command-line operations.

OPTIONS:
    -i, --interactive   Interactive TUI (default)
    -l, --list          List current mount status
    -a, --apply         Apply saved configuration
    -p, --profile NAME  Use specific profile (default: hostname)
    -h, --help          Show this help

ENVIRONMENT:
    DOTFILES_PROFILE    Override detected profile

EXAMPLES:
    $(basename "$0")              # Interactive mode
    $(basename "$0") -l           # List status
    $(basename "$0") -p bengal    # Use bengal profile
EOF
}

# Main
main() {
	local mode="interactive"
	local profile_override=""
	
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
	esac
}

main "$@"
