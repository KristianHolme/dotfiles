#!/usr/bin/env bash

# Apply dotfiles with GNU Stow: default package to ~, then optional profile overlay

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

TARGET_HOME="$HOME"

# Simple function to unstow any existing profile packages at repo root
unstow_all_profiles() {
	local packages_dir="$1"
	local target_dir="$2"
	log_info "Unstowing any existing profiles..."
	shopt -s nullglob
	for pkg_dir in "$packages_dir"/*; do
		[[ -d "$pkg_dir" ]] || continue
		local pkg_name
		pkg_name=$(basename "$pkg_dir")
		# Skip non-profile packages
		if [[ "$pkg_name" == "default" || "$pkg_name" == "bin" ]]; then
			continue
		fi
		stow -d "$packages_dir" -t "$target_dir" -D "$pkg_name" 2>/dev/null || true
	done
	shopt -u nullglob
}

stow_with_conflict_detection() {
	local packages_dir="$1" # e.g. /path/to/dotfiles
	local package_name="$2" # e.g. "dot-config" or "home"
	local target_dir="$3"   # e.g. ~/.config or ~
	local description="$4"  # e.g. "config files" or "home files"
	shift 4
	# Any remaining args are extra stow flags (e.g., --override, etc.)
	local extra_flags=("$@")

	# Check if package exists
	[[ -d "$packages_dir/$package_name" ]] || return 0

	log_info "Checking for conflicts in $description..."

	# Dry run to detect conflicts
	set +e
	local dry_run_output
	# Use -S for stow (not -R) when we have --override to avoid restow conflicts
	local stow_op="-R"
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
		# No conflicts, proceed with normal stow
		log_info "No conflicts detected, proceeding with $description symlinks..."
		stow -d "$packages_dir" -t "$target_dir" $stow_op -v --dotfiles "${extra_flags[@]}" "$package_name"
		log_success "Successfully linked $description"
	else
		# Conflicts detected, present user with options
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

########################################
# Apply configs using GNU Stow (symlinks)
########################################
apply_configs() {
	log_info "Linking with GNU Stow"

	ensure_cmd "stow"

	# Packages directory (repo root of omarchy-tweaks)
	PACKAGES_DIR="$(realpath "$SCRIPT_DIR/..")"
	# Optional profile argument (e.g. "work" -> config-work)
	local profile="${1:-}"

	# Apply base default package (includes dotfiles under dot-* inside it)
	stow_with_conflict_detection "$PACKAGES_DIR" "default" "$TARGET_HOME" "default files" --override='.*'

	# If a profile was provided, handle profile switching via top-level packages named by profile
	if [[ -n "$profile" ]]; then
		local profile_pkg_name="$profile"
		if [[ -d "$PACKAGES_DIR/$profile_pkg_name" ]]; then
			# First, unstow any existing profile overlays
			unstow_all_profiles "$PACKAGES_DIR" "$TARGET_HOME"

			# Then overlay the selected profile using override to replace base-owned files
			stow_with_conflict_detection "$PACKAGES_DIR" "$profile_pkg_name" "$TARGET_HOME" "profile files" --override='.*'
		else
			log_info "No profile package '$profile_pkg_name' found; skipping profile overlay"
		fi
	fi

	log_success "Configuration linking completed"
}

# Link agent skills/commands to Cursor and OpenCode config directories.
# Skills and commands are stored in ~/.agents/ (via stow from dot-agents/).
# OpenCode reads ~/.agents/skills/ natively; everything else needs symlinks.
link_agent_configs() {
	local agents_dir="$HOME/.agents"

	# Skip if ~/.agents doesn't exist (stow hasn't run yet)
	if [[ ! -d "$agents_dir" ]]; then
		log_info "~/.agents not found, skipping agent config linking"
		return 0
	fi

	log_info "Linking agent skills/commands to Cursor and OpenCode..."
	create_symlink_with_backup "$agents_dir/skills" "$HOME/.cursor/skills" "Cursor skills"
	create_symlink_with_backup "$agents_dir/commands" "$HOME/.cursor/commands" "Cursor commands"
	create_symlink_with_backup "$agents_dir/commands" "$HOME/.config/opencode/commands" "OpenCode commands"
}

# hyprctl needs HYPRLAND_INSTANCE_SIGNATURE; local terminals get it from uwsm,
# but SSH sessions do not. Discover the running instance via XDG_RUNTIME_DIR.
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

# Check for blank monitors (0x0 resolution) and fix them
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

	# Check for monitors with 0x0 resolution
	local blank_monitors
	blank_monitors=$(echo "$monitors_json" | jq -r '.[] | select(.width == 0 or .height == 0) | .name' 2>/dev/null)

	if [[ -n "$blank_monitors" ]]; then
		log_warning "Detected blank monitors (0x0 resolution): $(echo "$blank_monitors" | tr '\n' ' ')"
		log_info "Attempting to refresh monitors..."

		# Try safe refresh methods first
		# Turn DPMS off and on for each blank monitor
		while IFS= read -r monitor; do
			[[ -z "$monitor" ]] && continue
			hyprctl dispatch dpms off "$monitor" >/dev/null 2>&1
			sleep 0.2
			hyprctl dispatch dpms on "$monitor" >/dev/null 2>&1
		done <<<"$blank_monitors"

		sleep 0.5

		# Check if still blank
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

# Post-reload fixups: blank-monitor recovery and waybar restart.
# Waybar queries monitors at startup, so wait for them to be ready first.
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

# Reload hyprland
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
		# Workspace/monitor binding warnings are expected when switching profiles
		# with different monitor setups; anything else is a real failure.
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
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		cat <<EOF
Usage: $0 [PROFILE]

Apply dotfiles with GNU Stow: default package to ~, then optional profile overlay
(e.g. bengal, kaspi, sibir) if that top-level package exists in the repo.
EOF
		exit 0
	fi

	local profile_arg="${1:-}"
	if [[ -n "$profile_arg" ]]; then
		log_info "Applying Omarchy tweaks (profile: $profile_arg)..."
	else
		log_info "Applying Omarchy tweaks..."
	fi

	apply_configs "$profile_arg"

	# Link agent skills/commands to Cursor and OpenCode after stow has run
	link_agent_configs

	reload_hyprland
	log_success "All tweaks applied successfully!"
}

main "$@"
exit $?
