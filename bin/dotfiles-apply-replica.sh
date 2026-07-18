#!/usr/bin/env bash
set -Eeuo pipefail

# Applies omarchy-tweaks configs for university servers:
# - Stows default/dot-config into ~/.config (nvim, tmux, starship, hypr, etc.)
# - Stows default/dot-agents into ~/.agents (skills, commands)
# - Creates symlink for Julia config (~/.julia/config)
# - Adds source line to server's ~/.bashrc for our dot-bashrc (idempotent)
# - Ensures omarchy repo is cloned/updated first
#
# Config via env vars:
#   OMARCHY_DIR          - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL     - git URL for omarchy (default: https://github.com/basecamp/omarchy)
#   DOTFILES_REPLICA_ALL - if set to 1, same as --all (skip menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-install.sh"

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"

# Menu labels (order is canonical run order)
TASK_OMARCHY="Clone or update omarchy"
TASK_JULIA_CONFIG="Symlink Julia config (~/.julia/config)"
TASK_STOW="Stow dot-config into ~/.config"
TASK_STOW_AGENTS="Stow dot-agents into ~/.agents"
TASK_BASHRC="Add dot-bashrc source to ~/.bashrc"

MENU_OPTIONS=(
	"$TASK_OMARCHY"
	"$TASK_JULIA_CONFIG"
	"$TASK_STOW"
	"$TASK_STOW_AGENTS"
	"$TASK_BASHRC"
)

# Set by pick_tasks_interactive (newline-separated labels, canonical order)
REPLICA_SELECTION=""

# Ensure local bin is in PATH for tools like stow (idempotent)
case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) export PATH="$HOME/.local/bin${PATH:+:${PATH}}" ;;
esac

setup_julia_config() {
	local dotfiles_dir="$HOME/dotfiles/"
	local julia_config_source="$dotfiles_dir/default/dot-julia/config"
	local julia_config_target="$HOME/.julia/config"

	create_symlink_with_backup "$julia_config_source" "$julia_config_target" "Julia config"
}

# Stow or unstow a package from default/ into a target directory.
# Remaining args are forwarded to stow (after -- from the CLI).
stow_replica_package() {
	local package="$1"
	local target="$2"
	shift 2
	local -a stow_flags=("$@")
	local stow_dir="$HOME/dotfiles/default"
	local -a apply_flags=()

	mkdir -p "$target"

	if stow_flags_include -D "${stow_flags[@]}"; then
		log_info "Unstowing default/$package from $target..."
		stow -d "$stow_dir" -t "$target" --dotfiles "${stow_flags[@]}" "$package" 2>/dev/null || true
		return 0
	fi

	if [[ ${#stow_flags[@]} -gt 0 ]]; then
		merge_apply_stow_flags apply_flags "${stow_flags[@]}"
		if ! stow_flags_include -S "${apply_flags[@]}" && ! stow_flags_include -R "${apply_flags[@]}"; then
			apply_flags+=(-S)
		fi
	else
		apply_flags=(--dotfiles --no-folding -S)
	fi

	log_info "Stowing default/$package into $target (first with --adopt if existing files conflict)..."
	if stow -d "$stow_dir" -t "$target" "${apply_flags[@]}" "$package" --adopt -v; then
		log_success "Stowed $package into $target"
		return 0
	fi

	log_warning "Stow with --adopt failed; retrying without --adopt"
	if stow -d "$stow_dir" -t "$target" "${apply_flags[@]}" "$package" -v; then
		log_success "Stowed $package into $target"
		return 0
	fi

	log_error "Failed to stow $package"
	return 1
}

run_stow_passthrough() {
	local -a stow_flags=("$@")

	ensure_cmd stow

	if stow_flags_include -D "${stow_flags[@]}"; then
		stow_replica_package dot-config "$HOME/.config" "${stow_flags[@]}"
		stow_replica_package dot-agents "$HOME/.agents" "${stow_flags[@]}"
		return 0
	fi

	stow_replica_package dot-config "$HOME/.config" "${stow_flags[@]}" || {
		log_error "dot-config stow failed; aborting"
		exit 1
	}
	stow_replica_package dot-agents "$HOME/.agents" "${stow_flags[@]}" || {
		log_error "dot-agents stow failed; aborting"
		exit 1
	}
}

ensure_bashrc_source() {
	local bashrc_path="$HOME/.bashrc"
	local source_line="source '$HOME/dotfiles/default/dot-bashrc'"

	ensure_basic_bashrc "$bashrc_path"
	ensure_bash_profile_sources_bashrc "$HOME/.bash_profile" "$bashrc_path"

	# Check if already sourced
	if grep -qF "$source_line" "$bashrc_path" 2>/dev/null; then
		log_info "dot-bashrc already sourced in $bashrc_path; skipping"
		return 0
	fi

	log_info "Adding source line for dot-bashrc to $bashrc_path"
	printf '\n# Omarchy tweaks (added by dotfiles-apply-replica)\n%s\n' "$source_line" >>"$bashrc_path"
}

task_is_selected() {
	local label="$1"
	local selection="$2"
	grep -Fxq "$label" <<<"$selection"
}

ensure_cmds_for_selection() {
	local selection="$1"
	local -a cmds=()

	if task_is_selected "$TASK_OMARCHY" "$selection"; then
		cmds+=(git)
	fi
	if task_is_selected "$TASK_STOW" "$selection" || task_is_selected "$TASK_STOW_AGENTS" "$selection"; then
		cmds+=(stow)
	fi

	if [[ ${#cmds[@]} -eq 0 ]]; then
		return 0
	fi

	ensure_cmd "${cmds[@]}"
}

# Sets REPLICA_SELECTION to newline-separated labels (canonical order).
# Returns: 0 = ok, 1 = nothing selected, 2 = user cancelled gum
pick_tasks_interactive() {
	local skip_menu="${1:-false}"
	local selection="" ordered="" opt

	REPLICA_SELECTION=""

	if [[ "$skip_menu" == true ]]; then
		REPLICA_SELECTION=$(printf '%s\n' "${MENU_OPTIONS[@]}")
		return 0
	fi

	if ! command -v gum >/dev/null 2>&1 || [[ ! -t 0 ]]; then
		log_info "gum not available or stdin not a TTY; running all tasks"
		REPLICA_SELECTION=$(printf '%s\n' "${MENU_OPTIONS[@]}")
		return 0
	fi

	if ! selection=$(gum choose --no-limit \
		--selected='*' \
		--header "Select tasks to run (Space toggles, Enter confirms)" \
		"${MENU_OPTIONS[@]}"); then
		log_info "Task selection cancelled; exiting"
		return 2
	fi

	if [[ -z "${selection//[$'\n']/}" ]]; then
		return 1
	fi

	ordered=""
	for opt in "${MENU_OPTIONS[@]}"; do
		if task_is_selected "$opt" "$selection"; then
			ordered+="$opt"$'\n'
		fi
	done
	REPLICA_SELECTION="$ordered"
	return 0
}

run_selected_steps() {
	local selection="$1"

	if task_is_selected "$TASK_OMARCHY" "$selection"; then
		clone_or_update_omarchy "$OMARCHY_DIR" "$OMARCHY_REPO_URL"
		ensure_btop_omarchy_theme || true
	fi

	if task_is_selected "$TASK_JULIA_CONFIG" "$selection"; then
		setup_julia_config
	fi

	if task_is_selected "$TASK_STOW" "$selection"; then
		stow_replica_package dot-config "$HOME/.config" || {
			log_error "dot-config stow failed; aborting"
			exit 1
		}
	fi

	if task_is_selected "$TASK_STOW_AGENTS" "$selection"; then
		stow_replica_package dot-agents "$HOME/.agents" || {
			log_error "dot-agents stow failed; aborting"
			exit 1
		}
	fi

	if task_is_selected "$TASK_BASHRC" "$selection"; then
		ensure_bashrc_source
	fi
}

main() {
	local skip_menu=false
	local pick_rc=0
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
			cat <<EOF
Usage: $0 [OPTIONS] [-- STOW_ARGS...]

Apply dotfiles on a restricted server (interactive menu by default).

Options:
  --all       Run all steps; skip the gum menu
  -h, --help  Show this help

Arguments after -- are passed to GNU Stow only (skips the menu), e.g.:
  $0 -- -D       Unstow dot-config and dot-agents
  $0 -- -D -n    Dry-run unstow

Environment:
  OMARCHY_DIR, OMARCHY_REPO_URL
  DOTFILES_REPLICA_ALL=1  Same as --all
EOF
			exit 0
			;;
		--all)
			skip_menu=true
			shift
			;;
		*)
			log_error "Unknown option: $1 (stow flags must come after --)"
			echo "Try: $0 --help" >&2
			exit 1
			;;
		esac
	done

	if [[ "$stow_passthrough" -eq 1 ]]; then
		run_stow_passthrough "${stow_flags[@]}"
		log_info "Done."
		exit 0
	fi

	if [[ "${DOTFILES_REPLICA_ALL:-}" == "1" ]]; then
		skip_menu=true
	fi

	pick_tasks_interactive "$skip_menu"
	pick_rc=$?
	if [[ "$pick_rc" -eq 1 ]]; then
		log_info "No tasks selected; nothing to do"
		exit 0
	fi
	if [[ "$pick_rc" -eq 2 ]]; then
		exit 0
	fi

	ensure_cmds_for_selection "$REPLICA_SELECTION"
	run_selected_steps "$REPLICA_SELECTION"

	log_info "Done. Restart your shell or: source ~/.bash_profile"
}

main "$@"
