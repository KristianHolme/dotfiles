#!/usr/bin/env bash

# Apply dotfiles with GNU Stow: default package to ~, then optional profile overlay

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

TARGET_HOME="$HOME"

usage() {
	cat <<EOF
Usage: $0 [-h] [PROFILE] [-- STOW_ARGS...]

Apply dotfiles with GNU Stow: default package to ~, then optional profile overlay
(e.g. bengal, kaspi, sibir) if that top-level package exists in the repo.

Arguments after -- are passed to GNU Stow (e.g. unstow: $0 -- -D, dry-run: $0 -- -D -n).
EOF
}

# Unstow any existing profile packages at repo root; optional extra stow flags after target_dir.
unstow_all_profiles() {
	local packages_dir="$1"
	local target_dir="$2"
	shift 2
	local -a extra_flags=("$@")

	log_info "Unstowing any existing profiles..."
	shopt -s nullglob
	for pkg_dir in "$packages_dir"/*; do
		[[ -d "$pkg_dir" ]] || continue
		local pkg_name
		pkg_name=$(basename "$pkg_dir")
		if [[ "$pkg_name" == "default" || "$pkg_name" == "bin" || "$pkg_name" == "templates" ]]; then
			continue
		fi
		local -a stow_extra=() arg
		for arg in "${extra_flags[@]}"; do
			[[ "$arg" == -D ]] && continue
			stow_extra+=("$arg")
		done
		stow -d "$packages_dir" -t "$target_dir" --dotfiles "${stow_extra[@]}" -D "$pkg_name" 2>/dev/null || true
	done
	shopt -u nullglob
}

stow_with_conflict_detection() {
	local packages_dir="$1"
	local package_name="$2"
	local target_dir="$3"
	local description="$4"
	shift 4
	local extra_flags=("$@")

	[[ -d "$packages_dir/$package_name" ]] || return 0

	if stow_flags_include -n "${extra_flags[@]}"; then
		log_info "Dry-run stow for $description..."
		local stow_op="-R"
		local __flag
		for __flag in "${extra_flags[@]}"; do
			if [[ "$__flag" == --override* ]]; then
				stow_op="-S"
				break
			fi
		done
		stow -d "$packages_dir" -t "$target_dir" $stow_op --dotfiles "${extra_flags[@]}" "$package_name"
		return 0
	fi

	log_info "Checking for conflicts in $description..."

	set +e
	local dry_run_output stow_op="-R" __flag
	for __flag in "${extra_flags[@]}"; do
		if [[ "$__flag" == --override* ]]; then
			stow_op="-S"
			break
		fi
	done
	dry_run_output=$(stow -n -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name" 2>&1)
	local dry_run_status=$?
	set -e

	if [[ $dry_run_status -eq 0 ]]; then
		log_info "No conflicts detected, proceeding with $description symlinks..."
		stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name"
		log_success "Successfully linked $description"
	else
		log_warning "Conflicts detected in $description:"
		echo "$dry_run_output" | grep -E "(WARNING|ERROR|existing)" || echo "$dry_run_output"
		echo

		if ! command -v gum >/dev/null 2>&1; then
			log_warning "gum not found. Install with: pacman -S gum"
			log_warning "Manual resolution required for $description conflicts"
			return 1
		fi

		local choice
		choice=$(gum choose \
			"Adopt conflicting files (move them to dotfiles repo)" \
			"Abort (keep existing files)" \
			--header "How should conflicts be resolved for $description?") || choice="Abort (keep existing files)"

		case "$choice" in
		"Adopt conflicting files"*)
			log_info "Adopting conflicting files for $description..."
			stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles --adopt "${extra_flags[@]}" "$package_name" || {
				log_warning "Adopt failed; attempting plain stow with override..."
				stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name"
			}
			log_success "Adopted conflicts and linked $description"
			log_warning "Conflicting files moved to dotfiles repo - review and commit changes"
			;;
		"Abort"*)
			log_info "Aborted $description linking due to conflicts"
			return 1
			;;
		esac
	fi
}

apply_configs() {
	local profile="${1:-}"
	shift
	local -a user_stow_flags=("$@")
	local -a stow_flags=()

	log_info "Linking with GNU Stow"
	ensure_cmd "stow"

	local packages_dir
	packages_dir="$(realpath "$SCRIPT_DIR/..")"

	if [[ ${#user_stow_flags[@]} -gt 0 ]]; then
		merge_apply_stow_flags stow_flags "${user_stow_flags[@]}"
	else
		stow_flags=(--dotfiles --override='.*' --no-folding)
	fi

	stow_with_conflict_detection "$packages_dir" "default" "$TARGET_HOME" "default files" "${stow_flags[@]}"

	if [[ -n "$profile" ]]; then
		local profile_pkg_name="$profile"
		if [[ -d "$packages_dir/$profile_pkg_name" ]]; then
			unstow_all_profiles "$packages_dir" "$TARGET_HOME"
			stow_with_conflict_detection "$packages_dir" "$profile_pkg_name" "$TARGET_HOME" "profile files" "${stow_flags[@]}"
		else
			log_info "No profile package '$profile_pkg_name' found; skipping profile overlay"
		fi
	fi

	log_success "Configuration linking completed"
}

unapply_configs() {
	local -a stow_flags=("$@")

	log_info "Unlinking with GNU Stow"
	ensure_cmd "stow"

	local packages_dir
	packages_dir="$(realpath "$SCRIPT_DIR/..")"

	unstow_all_profiles "$packages_dir" "$TARGET_HOME" "${stow_flags[@]}"
	log_info "Unstowing default package..."
	stow -d "$packages_dir" -t "$TARGET_HOME" --dotfiles "${stow_flags[@]}" default 2>/dev/null || true
	if ! stow_flags_include -n "${stow_flags[@]}"; then
		unlink_agent_configs
	fi
	log_success "Configuration unlinking completed"
}

# Link agent skills/commands to Cursor and OpenCode config directories.
link_agent_configs() {
	local agents_dir="$HOME/.agents"

	if [[ ! -d "$agents_dir" ]]; then
		log_info "~/.agents not found, skipping agent config linking"
		return 0
	fi

	log_info "Linking agent skills/commands to Cursor and OpenCode..."
	create_symlink_with_backup "$agents_dir/skills" "$HOME/.cursor/skills" "Cursor skills"
	create_symlink_with_backup "$agents_dir/commands" "$HOME/.cursor/commands" "Cursor commands"
	create_symlink_with_backup "$agents_dir/commands" "$HOME/.config/opencode/commands" "OpenCode commands"
}

ensure_hyprland_instance() {
	if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
		return 0
	fi

	local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	local hypr_dir="$runtime_dir/hypr"
	local instance_dir

	if [[ ! -d "$hypr_dir" ]]; then
		return 1
	fi

	shopt -s nullglob
	local instances=("$hypr_dir"/*)
	shopt -u nullglob

	[[ ${#instances[@]} -gt 0 ]] || return 1

	instance_dir="${instances[0]}"
	[[ -d "$instance_dir" ]] || return 1

	export HYPRLAND_INSTANCE_SIGNATURE
	HYPRLAND_INSTANCE_SIGNATURE=$(basename "$instance_dir")
	return 0
}

check_and_fix_monitors() {
	if ! command -v hyprctl &>/dev/null || ! command -v jq &>/dev/null; then
		return 0
	fi

	ensure_hyprland_instance || return 0

	local monitors_json
	monitors_json=$(hyprctl monitors -j 2>/dev/null)
	if [[ $? -ne 0 ]]; then
		return 0
	fi

	local blank_monitors
	blank_monitors=$(echo "$monitors_json" | jq -r '.[] | select(.width == 0 or .height == 0) | .name' 2>/dev/null)

	if [[ -n "$blank_monitors" ]]; then
		log_warning "Detected blank monitors (0x0 resolution): $(echo "$blank_monitors" | tr '\n' ' ')"
		log_info "Attempting to refresh monitors..."

		while IFS= read -r monitor; do
			[[ -z "$monitor" ]] && continue
			hyprctl dispatch dpms off "$monitor" >/dev/null 2>&1
			sleep 0.2
			hyprctl dispatch dpms on "$monitor" >/dev/null 2>&1
		done <<<"$blank_monitors"

		sleep 0.5

		monitors_json=$(hyprctl monitors -j 2>/dev/null)
		blank_monitors=$(echo "$monitors_json" | jq -r '.[] | select(.width == 0 or .height == 0) | .name' 2>/dev/null)

		if [[ -n "$blank_monitors" ]]; then
			log_warning "Some monitors are still blank after refresh"
			log_info "You may need to manually restart Hyprland (Super+Esc -> Relaunch) or reconnect monitors"
			return 1
		else
			log_success "Monitors refreshed successfully"
		fi
	fi
}

post_reload_fixups() {
	sleep 0.5
	check_and_fix_monitors || true

	if command -v omarchy-restart-waybar &>/dev/null; then
		log_info "Restarting waybar to ensure it appears on all monitors..."
		sleep 2
		omarchy-restart-waybar >/dev/null 2>&1 || true
		sleep 1
	fi
}

reload_hyprland() {
	if ! command -v hyprctl &>/dev/null; then
		log_warning "hyprctl not found. Please reload Hyprland manually."
		return 0
	fi

	if ! ensure_hyprland_instance; then
		log_info "Hyprland not running; skipping config reload"
		return 0
	fi

	log_info "Reloading Hyprland configuration..."
	local reload_output reload_status
	set +e
	reload_output=$(hyprctl reload 2>&1)
	reload_status=$?
	set -e

	if [[ $reload_status -ne 0 ]]; then
		if echo "$reload_output" | grep -qiE "(workspace|monitor)" && echo "$reload_output" | grep -qiE "(not found|does not exist|ignored|warning)"; then
			log_warning "Hyprland reloaded with warnings about workspace/monitor bindings (normal when switching profiles)"
		else
			log_warning "Hyprland reload failed:"
			echo "$reload_output" | head -10
			log_info "Tip: If workspace bindings are causing issues, try moving workspaces manually"
			return 1
		fi
	fi

	post_reload_fixups
	log_success "Reloaded Hyprland configuration"
}

main() {
	local profile_arg=""
	local stow_passthrough=0
	local -a stow_flags=()

	while [[ $# -gt 0 ]]; do
		if [[ "$1" == "--" ]]; then
			stow_passthrough=1
			shift
			stow_flags=("$@")
			break
		fi
		case "$1" in
		-h | --help)
			usage
			exit 0
			;;
		-*)
			log_error "Unknown option: $1 (stow flags must come after --)"
			usage >&2
			exit 1
			;;
		*)
			if [[ -n "$profile_arg" ]]; then
				log_error "Unexpected argument: $1"
				usage >&2
				exit 1
			fi
			profile_arg="$1"
			shift
			;;
		esac
	done

	if [[ "$stow_passthrough" -eq 1 ]] && stow_flags_include -D "${stow_flags[@]}"; then
		log_info "Unapplying Omarchy tweaks..."
		unapply_configs "${stow_flags[@]}"
		log_success "All tweaks unapplied successfully!"
		return 0
	fi

	if [[ -n "$profile_arg" ]]; then
		log_info "Applying Omarchy tweaks (profile: $profile_arg)..."
	else
		log_info "Applying Omarchy tweaks..."
	fi

	if [[ "$stow_passthrough" -eq 1 ]]; then
		apply_configs "$profile_arg" "${stow_flags[@]}"
	else
		apply_configs "$profile_arg"
	fi

	link_agent_configs
	reload_hyprland
	log_success "All tweaks applied successfully!"
}

main "$@"
exit $?
