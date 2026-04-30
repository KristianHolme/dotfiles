#!/bin/bash

# SSHFS Mount Manager - Simple TUI and CLI for managing remote mounts.
# Filesystem inventory comes from hosts.toml (see bin/lib-hosts.sh). Mounts are
# managed directly with user-owned sshfs so interactive SSH/MFA flows work.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

SYSTEMD_SYSTEM_DIR="/etc/systemd/system"
SYSTEMD_LEGACY_USER_DIR="${SYSTEMD_LEGACY_USER_DIR:-$HOME/.config/systemd/user}"

SSHFS_OPTS=(
	-o reconnect
	-o ServerAliveInterval=15
	-o follow_symlinks
	-o transform_symlinks
	-o compression=yes
)

get_hostname() {
	hostname | cut -d. -f1
}

# systemd-escape-derived unit basename for Where= path (paired .mount /.automount).
unit_mount_for_path() {
	local local_path="$1"
	systemd-escape -p --suffix=mount "$local_path"
}

unit_automount_for_path() {
	local local_path="$1"
	systemd-escape -p --suffix=automount "$local_path"
}

unit_mount_for_key() {
	local key="$1"
	local local_path
	local_path=$(hosts_filesystem_local_path "$key") || return 1
	unit_mount_for_path "$local_path"
}

unit_automount_for_key() {
	local key="$1"
	local local_path
	local_path=$(hosts_filesystem_local_path "$key") || return 1
	unit_automount_for_path "$local_path"
}

cleanup_legacy_user_unit() {
	local unit="$1"
	local legacy="$SYSTEMD_LEGACY_USER_DIR/$unit"

	if [[ -e "$legacy" || -L "$legacy" ]]; then
		log_info "Cleaning legacy user systemd unit ${unit}"
		rm -f "$legacy"
	fi
	return 0
}

cleanup_legacy_systemd_units() {
	local mount_name="$1"
	local unit_mount unit_auto
	unit_mount=$(unit_mount_for_key "$mount_name") || return 1
	unit_auto=$(unit_automount_for_key "$mount_name") || return 1

	cleanup_legacy_user_unit "$unit_mount"
	cleanup_legacy_user_unit "$unit_auto"

	local path_mount path_auto needs_cleanup=0
	path_mount="$SYSTEMD_SYSTEM_DIR/$unit_mount"
	path_auto="$SYSTEMD_SYSTEM_DIR/$unit_auto"

	if [[ -e "$path_mount" || -L "$path_mount" || -e "$path_auto" || -L "$path_auto" ]]; then
		needs_cleanup=1
	fi
	if systemctl is-active "$unit_auto" &>/dev/null || systemctl is-enabled "$unit_auto" &>/dev/null; then
		needs_cleanup=1
	fi

	if [[ "$needs_cleanup" -eq 0 ]]; then
		return 0
	fi

	log_info "Cleaning legacy systemd units for ${mount_name}"
	if [[ -e "$path_mount" || -L "$path_mount" || -e "$path_auto" || -L "$path_auto" ]]; then
		sudo systemctl stop "$unit_mount" &>/dev/null || true
	fi
	sudo systemctl disable --now "$unit_auto" &>/dev/null || true
	sudo systemctl stop "$unit_auto" &>/dev/null || true
	sudo rm -f "$path_mount" "$path_auto"
	sudo systemctl daemon-reload
}

# List mountable filesystems from hosts.toml, excluding any whose mount-via host
# matches the local hostname (can't SSH to self).
list_available_mounts() {
	local local_host
	local_host=$(get_hostname)
	local key host
	while IFS= read -r key; do
		[[ -z "$key" ]] && continue
		host=$(hosts_filesystem_host "$key") || continue
		if [[ "$host" != "$local_host" ]]; then
			echo "$key"
		fi
	done < <(hosts_filesystems)
}

hosts_filesystem_exists() {
	local mount_name="$1"
	local key
	while IFS= read -r key; do
		[[ "$key" == "$mount_name" ]] && return 0
	done < <(hosts_filesystems)
	return 1
}

is_mount_active() {
	local mount_name="$1"
	local local_path
	local_path=$(hosts_filesystem_local_path "$mount_name") || return 1
	findmnt --mountpoint "$local_path" &>/dev/null
}

is_mount_enabled() {
	is_mount_active "$@"
}

prepare_mountpoint() {
	local local_path="$1"
	local uid gid

	if [[ ! -d "$local_path" ]]; then
		if ! sudo mkdir -p "$local_path"; then
			log_error "Failed to create mountpoint ${local_path}"
			return 1
		fi
	fi

	uid=$(stat -c %u "$local_path")
	gid=$(stat -c %g "$local_path")
	if [[ "$uid" != "$(id -u)" || "$gid" != "$(id -g)" ]]; then
		if ! sudo chown "${USER}:$(id -gn "$USER")" "$local_path"; then
			log_error "Failed to chown mountpoint ${local_path}"
			return 1
		fi
	fi

	if ! chmod 0755 "$local_path" 2>/dev/null; then
		if ! sudo chmod 0755 "$local_path"; then
			log_error "Failed to chmod mountpoint ${local_path}"
			return 1
		fi
	fi
}

do_enable() {
	local mount_name="$1"

	if ! hosts_filesystem_exists "$mount_name"; then
		log_error "Unknown filesystem: $mount_name (not declared in $(hosts_toml_path))"
		return 1
	fi

	local host remote_path local_path
	host=$(hosts_filesystem_host "$mount_name")
	remote_path=$(hosts_filesystem_remote_path "$mount_name")
	local_path=$(hosts_filesystem_local_path "$mount_name")

	if [[ "$remote_path" == "TODO" || "$local_path" == "TODO" || "$host" == "TODO" ]]; then
		log_error "$mount_name has placeholder TODO fields in $(hosts_toml_path); fill them in first"
		return 1
	fi

	if ! cleanup_legacy_systemd_units "$mount_name"; then
		return 1
	fi

	if is_mount_active "$mount_name"; then
		log_info "${mount_name} is already mounted at ${local_path}"
		return 0
	fi

	ensure_cmd sshfs findmnt
	if ! prepare_mountpoint "$local_path"; then
		return 1
	fi

	if sshfs "${SSHFS_OPTS[@]}" "${host}:${remote_path}" "$local_path"; then
		log_success "Mounted ${mount_name} (${host}:${remote_path} -> ${local_path})"
		return 0
	fi

	log_error "Failed to mount ${mount_name} (${host}:${remote_path} -> ${local_path})"
	return 1
}

do_disable() {
	local mount_name="$1"
	local local_path
	local_path=$(hosts_filesystem_local_path "$mount_name") || return 1

	if ! cleanup_legacy_systemd_units "$mount_name"; then
		return 1
	fi

	if ! is_mount_active "$mount_name"; then
		log_info "$mount_name is already unmounted"
		return 0
	fi

	ensure_cmd fusermount3
	if ! fusermount3 -u "$local_path"; then
		log_error "Failed to unmount ${mount_name} at ${local_path}"
		return 1
	fi

	chmod 0755 "$local_path" 2>/dev/null || sudo chmod 0755 "$local_path" 2>/dev/null || true
	chown "${USER}:$(id -gn "$USER")" "$local_path" 2>/dev/null || sudo chown "${USER}:$(id -gn "$USER")" "$local_path" 2>/dev/null || true

	log_success "Unmounted $mount_name"
}

interactive_tui() {
	if ! command -v gum &>/dev/null; then
		log_error "gum is required for interactive mode. Install with: pacman -S gum"
		return 1
	fi

	local available_mounts
	available_mounts=$(list_available_mounts)

	if [[ -z "$available_mounts" ]]; then
		log_error "No mountable filesystems declared in $(hosts_toml_path)"
		return 1
	fi

	local options=()
	local preselected=()
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue

		local label="$mount_name"
		if is_mount_enabled "$mount_name"; then
			label="$mount_name (mounted)"
			preselected+=("$label")
		fi
		options+=("$label")
	done <<< "$available_mounts"

	gum style --foreground 212 "Toggle mounts with space, confirm with enter"
	echo

	local selected_arg=""
	if [[ ${#preselected[@]} -gt 0 ]]; then
		selected_arg=$(IFS=,; echo "${preselected[*]}")
	fi

	local selected
	if ! selected=$(printf '%s\n' "${options[@]}" | gum choose --no-limit --selected-prefix="✅ " --unselected-prefix="❌ " --cursor-prefix="❌ " --selected="$selected_arg"); then
		log_info "Cancelled"
		return 0
	fi

	declare -A want_enabled=()
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		local mount_name
		mount_name=$(echo "$line" | awk '{print $1}')
		want_enabled["$mount_name"]=1
	done <<< "$selected"

	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue

		if [[ -n "${want_enabled[$mount_name]:-}" ]]; then
			if ! is_mount_enabled "$mount_name"; then
				do_enable "$mount_name" || log_error "Failed to enable $mount_name (continuing)"
			fi
		else
			if is_mount_enabled "$mount_name"; then
				do_disable "$mount_name" || log_error "Failed to disable $mount_name (continuing)"
			fi
		fi
	done <<< "$available_mounts"
}

list_status() {
	log_info "Mount status (from $(hosts_toml_path))"

	local available_mounts
	available_mounts=$(list_available_mounts)

	if [[ -z "$available_mounts" ]]; then
		log_info "No mountable filesystems"
		return 0
	fi

	printf "\n%-15s %-8s %-38s %-30s\n" "Mount" "Mounted" "Source" "Where"
	printf "%-15s %-8s %-38s %-30s\n" "---------------" "--------" "--------------------------------------" "------------------------------"

	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue

		local mounted="no"
		local local_path=""
		local host remote_path source
		local_path="$(hosts_filesystem_local_path "$mount_name")"
		host="$(hosts_filesystem_host "$mount_name")"
		remote_path="$(hosts_filesystem_remote_path "$mount_name")"
		source="${host}:${remote_path}"

		if is_mount_active "$mount_name"; then
			mounted="yes"
			source="$(findmnt --mountpoint "$local_path" --noheadings --output SOURCE 2>/dev/null || printf '%s' "$source")"
		fi

		printf "%-15s %-8s %-38s %-30s\n" "$mount_name" "$mounted" "$source" "${local_path}"
	done <<< "$available_mounts"
	echo
	log_info "Mounted filesystems are direct user sshfs mounts. Selecting an unmounted entry mounts it; deselecting a mounted entry unmounts it."
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [MOUNT...]

Manage SSHFS mounts with interactive TUI or command-line operations. Filesystem
inventory is read from hosts.toml at the repo root (override with HOSTS_TOML).

Mounts are created directly with sshfs as the current user. sudo is only used
to prepare /mnt mountpoint directories and clean up old systemd units.

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
    $(basename "$0") -e sibir uio-math
    $(basename "$0") -d uio-bioint

NOTES:
    - Can combine --enable and --disable for different mounts
    - Must specify mount name(s) with --enable/--disable
    - Same mount in both --enable and --disable is an error
    - Mount entries with TODO placeholders are refused until filled in
    - Legacy systemd units for the same path are cleaned up automatically
EOF
}

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

	for m in "${enable_mounts[@]}"; do
		for d in "${disable_mounts[@]}"; do
			if [[ "$m" == "$d" ]]; then
				log_error "Cannot enable and disable the same mount: $m"
				exit 1
			fi
		done
	done

	if [[ -z "$mode" ]]; then
		mode="interactive"
	fi

	case "$mode" in
		interactive)
			interactive_tui
			;;
		list)
			list_status
			;;
		cli)
			if [[ ${#enable_mounts[@]} -eq 0 && ${#disable_mounts[@]} -eq 0 ]]; then
				log_error "Mount name(s) required. Use --enable or --disable"
				exit 1
			fi
			for m in "${enable_mounts[@]}"; do
				do_enable "$m" || exit 1
			done
			for m in "${disable_mounts[@]}"; do
				do_disable "$m" || exit 1
			done
			;;
	esac
}

main "$@"
