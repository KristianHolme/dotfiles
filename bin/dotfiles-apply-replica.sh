#!/usr/bin/env bash
set -Eeuo pipefail

# Applies omarchy-tweaks configs for university servers:
# - Stows default/dot-config into ~/.config (nvim, tmux, starship, hypr, etc.)
# - Creates symlink for Julia config (~/.julia/config)
# - Adds source line to server's ~/.bashrc for our dot-bashrc (idempotent)
# - Ensures omarchy repo is cloned/updated first
#
# Config via env vars:
#   OMARCHY_DIR          - omarchy clone dir (default: ~/.local/share/omarchy)
#   OMARCHY_REPO_URL     - git URL for omarchy (default: https://github.com/basecamp/omarchy)
#   DOTFILES_REPLICA_ALL - if set to 1, same as --all (skip menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

OMARCHY_DIR="${OMARCHY_DIR:-"$HOME/.local/share/omarchy"}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/basecamp/omarchy}"

# Menu labels (order is canonical run order)
TASK_OMARCHY="Clone or update omarchy"
TASK_JULIA_SETUP="Run Julia setup script (julia-setup.jl)"
TASK_JULIA_CONFIG="Symlink Julia config (~/.julia/config)"
TASK_STOW="Stow dot-config into ~/.config"
TASK_TMUX_LEGACY="Remove legacy ~/.tmux.conf symlink"
TASK_BASHRC="Add dot-bashrc source to ~/.bashrc"

MENU_OPTIONS=(
	"$TASK_OMARCHY"
	"$TASK_JULIA_SETUP"
	"$TASK_JULIA_CONFIG"
	"$TASK_STOW"
	"$TASK_TMUX_LEGACY"
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

# Stow the whole default/dot-config tree into ~/.config (--adopt helps merge existing plain files).
stow_dot_config_into_xdg() {
	local dotfiles_dir="$HOME/dotfiles"
	local original_pwd="$PWD"

	cd "$dotfiles_dir" || {
		log_error "Failed to cd to $dotfiles_dir"
		return 1
	}

	log_info "Stowing default/dot-config into \$HOME/.config (first with --adopt if existing files conflict)..."
	if stow -d default -t "$HOME/.config" --dotfiles -S dot-config --adopt -v; then
		log_success "Stowed dot-config into ~/.config"
	else
		log_warning "Stow with --adopt failed; retrying without --adopt"
		if stow -d default -t "$HOME/.config" --dotfiles -S dot-config -v; then
			log_success "Stowed dot-config into ~/.config"
		else
			log_error "Failed to stow dot-config"
			cd "$original_pwd" || true
			return 1
		fi
	fi

	cd "$original_pwd" || true
}

# tmux reads ~/.tmux.conf before XDG; remove only our old symlink so ~/.config/tmux/tmux.conf wins.
remove_legacy_home_tmux_conf_symlink() {
	local legacy="$HOME/.tmux.conf"
	local xdg_conf="$HOME/.config/tmux/tmux.conf"
	local repo_conf="$HOME/dotfiles/default/dot-config/tmux/tmux.conf"
	[[ -e "$xdg_conf" ]] || return 0
	[[ -L "$legacy" ]] || return 0
	if [[ "$(realpath "$legacy" 2>/dev/null)" == "$(realpath "$repo_conf" 2>/dev/null)" ]]; then
		log_info "Removing legacy ~/.tmux.conf (tmux uses ~/.config/tmux/tmux.conf via stow)"
		rm "$legacy"
	fi
}

ensure_bashrc_source() {
	local bashrc_path="$HOME/.bashrc"
	local source_line="source '$HOME/dotfiles/default/dot-bashrc'"

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
	if task_is_selected "$TASK_STOW" "$selection"; then
		cmds+=(stow)
	fi
	if task_is_selected "$TASK_JULIA_SETUP" "$selection"; then
		cmds+=(curl)
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
	fi

	if task_is_selected "$TASK_JULIA_SETUP" "$selection"; then
		if command -v julia >/dev/null 2>&1; then
			log_info "Running Julia setup script"
			"$SCRIPT_DIR/julia-setup.jl" || log_warning "julia-setup.jl failed"
		else
			log_warning "Julia not found; install it via dotfiles-setup-replica.sh first"
		fi
	fi

	if task_is_selected "$TASK_JULIA_CONFIG" "$selection"; then
		setup_julia_config
	fi

	if task_is_selected "$TASK_STOW" "$selection"; then
		stow_dot_config_into_xdg || {
			log_error "dot-config stow failed; aborting"
			exit 1
		}
	fi

	if task_is_selected "$TASK_TMUX_LEGACY" "$selection"; then
		remove_legacy_home_tmux_conf_symlink
	fi

	if task_is_selected "$TASK_BASHRC" "$selection"; then
		ensure_bashrc_source
	fi
}

main() {
	local skip_menu=false
	local pick_rc

	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			cat <<EOF
Usage: $0 [OPTIONS]

Apply dotfiles on a restricted server (interactive menu by default).

Options:
  --all       Run all steps; skip the gum menu
  -h, --help  Show this help

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
			log_error "Unknown option: $1"
			echo "Try: $0 --help" >&2
			exit 1
			;;
		esac
	done

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

	log_info "Done. Restart your shell or: source ~/.bashrc"
}

main "$@"
