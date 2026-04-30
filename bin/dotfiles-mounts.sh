#!/bin/bash

# SSHFS Mount Manager - Simple TUI and CLI for managing remote mounts.
# Filesystem inventory comes from hosts.toml (see bin/lib-hosts.sh). System
# .mount units are paired with .automount (on-demand + idle expiry) because
# user-mode automount lacks CAP_SYS_ADMIN for autofs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

SYSTEMD_SYSTEM_DIR="/etc/systemd/system"
SYSTEMD_LEGACY_USER_DIR="${SYSTEMD_LEGACY_USER_DIR:-$HOME/.config/systemd/user}"

# Idle expiry for autofs-triggered mounts (seconds).
SSHFS_IDLE_SEC="${SSHFS_IDLE_SEC:-600}"

# Fuse options excluding ssh_command (assembled in mount_options_for).
SSHFS_FUSE_OPTS_BASE="_netdev,delay_connect,reconnect,ServerAliveInterval=15,allow_other,default_permissions,dir_cache=yes,follow_symlinks,transform_symlinks,compression=yes"

get_hostname() {
	hostname | cut -d. -f1
}

# Escape embedded spaces and commas for systemd.mount(5) Options= value.
escape_systemd_mount_option_value() {
	local s="$1"
	s="${s//\\/\\\\}"
	s="${s// /\\040}"
	s="${s//,/\\x2c}"
	printf '%s' "$s"
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

# sshfs runs as root; force user SSH config / keys (~ in root's config resolves wrong).
ssh_invocation_for_systemd() {
	printf 'ssh -F %s/.ssh/config -o IdentityFile=%s -o UserKnownHostsFile=%s/.ssh/known_hosts' \
		"$HOME" "${SSHFS_IDENTITY_FILE:-$HOME/.ssh/id_ed25519}" "$HOME"
}

mount_options_for() {
	local ssh_cmd_esc
	ssh_cmd_esc="$(escape_systemd_mount_option_value "$(ssh_invocation_for_systemd)")"
	printf '%s,uid=%s,gid=%s,ssh_command=%s' \
		"$SSHFS_FUSE_OPTS_BASE" "$(id -u)" "$(id -g)" "$ssh_cmd_esc"
}

abort_if_legacy_user_unit() {
	local unit_mount="$1"
	local legacy="$SYSTEMD_LEGACY_USER_DIR/$unit_mount"

	if [[ -e "$legacy" || -L "$legacy" ]] || systemctl --user is-enabled "$unit_mount" &>/dev/null; then
		log_error "A legacy user-scoped systemd unit conflicts with ${unit_mount}."
		log_error "Remove it first, e.g.: systemctl --user disable --now ${unit_mount}; rm -f ${legacy}; systemctl --user daemon-reload"
		return 1
	fi
	return 0
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

# Render paired .mount (no [Install]) and .automount units.
render_mount_unit() {
	local key="$1"
	local host="$2"
	local remote_path="$3"
	local local_path="$4"
	local options
	options=$(mount_options_for)
	cat <<EOF
[Unit]
Description=SSHFS backing mount for ${key}
After=network-online.target
Wants=network-online.target

[Mount]
What=${host}:${remote_path}
Where=${local_path}
Type=fuse.sshfs
Options=${options}
EOF
}

render_automount_unit() {
	local key="$1"
	local local_path="$2"
	cat <<EOF
[Unit]
Description=SSHFS automount (${key})
After=network-online.target
Wants=network-online.target

[Automount]
Where=${local_path}
TimeoutIdleSec=${SSHFS_IDLE_SEC}

[Install]
WantedBy=multi-user.target
EOF
}

# Enabled = unit files under /etc/systemd/system AND automount symlink active.
is_mount_enabled() {
	local mount_name="$1"
	local ua path_sys
	ua=$(unit_automount_for_key "$mount_name") || return 1
	path_sys="$SYSTEMD_SYSTEM_DIR/$ua"
	[[ -e "$path_sys" ]] && systemctl is-enabled "$ua" &>/dev/null
}

is_mount_active() {
	local mount_name="$1"
	local ua
	ua=$(unit_automount_for_key "$mount_name") || return 1
	systemctl is-active "$ua" &>/dev/null
}

do_enable() {
	local mount_name="$1"

	if ! hosts_filesystems | grep -qx "$mount_name"; then
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

	local unit_mount unit_auto
	unit_mount=$(unit_mount_for_key "$mount_name")
	unit_auto=$(unit_automount_for_key "$mount_name")

	if ! abort_if_legacy_user_unit "$unit_mount"; then
		return 1
	fi

	local tmp_mount tmp_auto status
	tmp_mount="$(mktemp)"
	tmp_auto="$(mktemp)"
	render_mount_unit "$mount_name" "$host" "$remote_path" "$local_path" >"$tmp_mount"
	render_automount_unit "$mount_name" "$local_path" >"$tmp_auto"

	status=0
	if ! sudo install -m 0644 "$tmp_mount" "$SYSTEMD_SYSTEM_DIR/$unit_mount"; then
		status=1
	fi
	if ! sudo install -m 0644 "$tmp_auto" "$SYSTEMD_SYSTEM_DIR/$unit_auto"; then
		status=1
	fi
	rm -f "$tmp_mount" "$tmp_auto"
	if [[ "$status" -ne 0 ]]; then
		log_error "Failed installing unit files into ${SYSTEMD_SYSTEM_DIR}"
		return 1
	fi

	if ! sudo mkdir -p "$local_path"; then
		log_error "Failed to create mountpoint ${local_path}"
		return 1
	fi

	# Empty automount directories must remain traversable so non-root users can
	# trigger the mount and descend after SSHFS binds (avoid d--------- stubs → EIO on cd).
	if ! sudo chmod 0755 "$local_path"; then
		log_error "Failed to chmod mountpoint ${local_path}"
		return 1
	fi
	if ! sudo chown "${USER}:$(id -gn "$USER")" "$local_path"; then
		log_error "Failed to chown mountpoint ${local_path} (set ownership so you can traverse it)"
		return 1
	fi

	if ! sudo systemctl daemon-reload; then
		return 1
	fi
	if ! sudo systemctl enable --now "$unit_auto"; then
		log_error "Failed to enable ${unit_auto}. Run: sudo systemctl status ${unit_auto}"
		return 1
	fi

	log_success "Automount enabled for ${mount_name} (${host}:${remote_path} → ${local_path}; idle expiry ${SSHFS_IDLE_SEC}s). First access triggers the SSHFS mount."
}

do_disable() {
	local mount_name="$1"
	local local_path
	local_path=$(hosts_filesystem_local_path "$mount_name") || return 1
	local unit_mount unit_auto
	unit_mount=$(unit_mount_for_key "$mount_name") || return 1
	unit_auto=$(unit_automount_for_key "$mount_name") || return 1
	local path_mount path_auto
	path_mount="$SYSTEMD_SYSTEM_DIR/$unit_mount"
	path_auto="$SYSTEMD_SYSTEM_DIR/$unit_auto"

	if [[ ! -e "$path_mount" && ! -e "$path_auto" ]] && ! systemctl is-enabled "$unit_auto" &>/dev/null; then
		log_info "$mount_name is already disabled"
		return 0
	fi

	sudo systemctl stop "$unit_mount" 2>/dev/null || true
	if systemctl is-enabled "$unit_auto" &>/dev/null; then
		sudo systemctl disable --now "$unit_auto" 2>/dev/null || true
	elif systemctl is-active "$unit_auto" &>/dev/null; then
		sudo systemctl stop "$unit_auto" 2>/dev/null || true
	fi

	sudo chmod 0755 "$local_path" 2>/dev/null || true
	sudo chown "${USER}:$(id -gn "$USER")" "$local_path" 2>/dev/null || true

	sudo rm -f "$path_mount" "$path_auto"
	sudo systemctl daemon-reload
	sudo rmdir "$local_path" 2>/dev/null || true

	log_success "Disabled $mount_name"
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

	if ! sudo -v; then
		log_error "sudo credentials required to install system systemd units"
		return 1
	fi

	local options=()
	local preselected=()
	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue

		local label="$mount_name"
		if is_mount_enabled "$mount_name"; then
			label="$mount_name (enabled)"
			preselected+=("$label")
		fi
		options+=("$label")
	done <<< "$available_mounts"

	gum style --foreground 212 "Toggle mounts with space, confirm with enter (sudo required)"
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
	log_info "Mount status (from $(hosts_toml_path)); automount units in ${SYSTEMD_SYSTEM_DIR}"

	local available_mounts
	available_mounts=$(list_available_mounts)

	if [[ -z "$available_mounts" ]]; then
		log_info "No mountable filesystems"
		return 0
	fi

	printf "\n%-15s %-8s %-8s %-38s %-30s\n" "Mount" "Enabled" "Active" ".automount unit" "Where"
	printf "%-15s %-8s %-8s %-38s %-30s\n" "---------------" "--------" "--------" "--------------------------------------" "------------------------------"

	while IFS= read -r mount_name; do
		[[ -z "$mount_name" ]] && continue

		local enabled="no"
		local active="no"
		local ua
		local local_path=""
		local_path="$(hosts_filesystem_local_path "$mount_name")"
		if ! ua=$(unit_automount_for_key "$mount_name"); then
			ua="(?)"
		fi

		if is_mount_enabled "$mount_name"; then
			enabled="yes"
		fi
		if is_mount_active "$mount_name"; then
			active="yes"
		fi

		printf "%-15s %-8s %-8s %-38s %-30s\n" "$mount_name" "$enabled" "$active" "$ua" "${local_path}"
	done <<< "$available_mounts"
	echo
	log_info "\"Active\" is the systemd automount waiter (listening at Where). SSHFS attaches on first path access, then idle-unmounts after ${SSHFS_IDLE_SEC}s."
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [MOUNT...]

Manage SSHFS mounts with interactive TUI or command-line operations. Filesystem
inventory is read from hosts.toml at the repo root (override with HOSTS_TOML).

Units are installed system-wide as paired .mount + .automount under
${SYSTEMD_SYSTEM_DIR}: on-demand mount + idle unmount (${SSHFS_IDLE_SEC}s default)
to avoid hangs when listing parents of dead SSHFS targets. sudo is required.

Environment:
    SSHFS_IDLE_SEC      Idle-unmount timeout in seconds (${SSHFS_IDLE_SEC})
    SSHFS_IDENTITY_FILE Path for IdentityFile ssh option (default: \$HOME/.ssh/id_ed25519)

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
    - Remove any legacy user units for the same path before enabling (see error text)
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
			if [[ ${#enable_mounts[@]} -gt 0 || ${#disable_mounts[@]} -gt 0 ]]; then
				if ! sudo -v; then
					log_error "sudo required to manage system systemd units"
					exit 1
				fi
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
