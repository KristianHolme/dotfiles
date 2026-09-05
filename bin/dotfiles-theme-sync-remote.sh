#!/usr/bin/env bash
#
# Push the already-rendered local Omarchy theme to SSH hosts that have a
# ControlMaster. Never opens a new TCP/2FA session — that races dst and can
# lock out jump hosts. Also used by dst on connect for a single host.
#
# Usage:
#   dotfiles-theme-sync-remote.sh              # all active hosts
#   dotfiles-theme-sync-remote.sh --host ALIAS

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"
# shellcheck source=lib-hosts.sh
source "$SCRIPT_DIR/lib-hosts.sh"

usage() {
	cat <<EOF
Usage: $0 [--host ALIAS]

Rsync the local staged Omarchy theme (~/.local/state/omarchy/current/theme)
to active SSH hosts from hosts.toml (or one host), then apply terminal/tmux
hooks on the remote. No Omarchy install is required on the replica.

  --host ALIAS   Sync only this inventory alias (e.g. dst after connect)

Active = ControlMaster up (\`ssh -O check\`). Never opens a new SSH session.
Skips backgrounds/preview.png. Applies btop, tmux (status + pane OSC),
terminals, gum env, pi, claude, helix, and opencode when present.
EOF
}

HOST_FILTER=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--host)
		HOST_FILTER="${2:-}"
		[[ -n "$HOST_FILTER" ]] || {
			log_error "--host requires an alias"
			exit 1
		}
		shift 2
		;;
	--theme)
		log_warning "--theme is ignored; replicas receive the locally applied theme"
		shift
		[[ $# -gt 0 && $1 != -* ]] && shift
		;;
	*)
		log_error "Unknown argument: $1"
		usage
		exit 1
		;;
	esac
done

LOCAL_CURRENT="${HOME}/.local/state/omarchy/current"
LOCAL_THEME="${LOCAL_CURRENT}/theme"

resolve_local_theme() {
	local name path
	if command -v omarchy-theme-current >/dev/null 2>&1; then
		name="$(omarchy-theme-current 2>/dev/null || true)"
		if [[ -n "$name" && "$name" != "Unknown" ]]; then
			echo "$name"
			return 0
		fi
	fi
	path="${LOCAL_CURRENT}/theme.name"
	if [[ -f "$path" ]]; then
		cat "$path"
		return 0
	fi
	return 1
}

# Print inventory aliases with a live ControlMaster (one per line), excluding local host.
hosts_active_ssh() {
	local host local_host
	local_host="$(hosts_local_hostname)"
	while IFS= read -r host; do
		[[ -n "$host" ]] || continue
		if [[ "${host,,}" == "${local_host,,}" ]]; then
			continue
		fi
		if ssh -O check "$host" >/dev/null 2>&1; then
			echo "$host"
		fi
	done < <(hosts_all_machines)
}

# SSH options: never block on interactive MFA. Callers must already have a ControlMaster.
_SSH_SYNC_OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o PreferredAuthentications=publickey)

push_theme_files() {
	local host="$1"
	local ssh_cmd="ssh ${_SSH_SYNC_OPTS[*]}"

	# shellcheck disable=SC2029
	ssh "${_SSH_SYNC_OPTS[@]}" "$host" "mkdir -p .local/state/omarchy/current/theme"

	if command -v rsync >/dev/null 2>&1 && ssh "${_SSH_SYNC_OPTS[@]}" "$host" "command -v rsync >/dev/null 2>&1"; then
		rsync -az --delete \
			--exclude backgrounds/ \
			--exclude preview.png \
			-e "$ssh_cmd" \
			"${LOCAL_THEME}/" \
			"${host}:.local/state/omarchy/current/theme/"
		if [[ -f ${LOCAL_CURRENT}/theme.name ]]; then
			rsync -az -e "$ssh_cmd" \
				"${LOCAL_CURRENT}/theme.name" \
				"${host}:.local/state/omarchy/current/theme.name"
		fi
		return 0
	fi

	tar -C "$LOCAL_THEME" --exclude=backgrounds --exclude=preview.png -cf - . |
		ssh "${_SSH_SYNC_OPTS[@]}" "$host" "tar -C .local/state/omarchy/current/theme -xf -"
	if [[ -f ${LOCAL_CURRENT}/theme.name ]]; then
		ssh "${_SSH_SYNC_OPTS[@]}" "$host" "cat > .local/state/omarchy/current/theme.name" \
			<"${LOCAL_CURRENT}/theme.name"
	fi
}

# Apply theme on one remote host. Never exits non-zero for the caller.
sync_host() {
	local host="$1"
	local theme="$2"

	if ! ssh -O check "$host" >/dev/null 2>&1; then
		log_warning "Skip $host: no ControlMaster (will not open a new SSH/2FA session)"
		return 0
	fi

	log_info "Syncing theme '$theme' -> $host"

	if ! ssh "${_SSH_SYNC_OPTS[@]}" "$host" "true" >/dev/null 2>&1; then
		log_warning "Skip $host: SSH not available (BatchMode/auth/timeout)"
		return 0
	fi

	if ! push_theme_files "$host"; then
		log_warning "Theme file push failed on $host"
		return 0
	fi

	# Apply hooks from this machine so the remote need not have updated dotfiles yet.
	if ! ssh "${_SSH_SYNC_OPTS[@]}" "$host" bash -s <<REMOTE
set -euo pipefail
$(cat "$SCRIPT_DIR/lib-theme-replica.sh")
apply_omarchy_theme_replica
REMOTE
	then
		log_warning "Theme apply failed on $host (see remote stderr above)"
		return 0
	fi

	log_success "Theme synced on $host"
	return 0
}

main() {
	local theme_name
	if [[ ! -d $LOCAL_THEME ]]; then
		log_error "No local staged theme at $LOCAL_THEME (run omarchy theme set first)"
		exit 1
	fi

	theme_name="$(resolve_local_theme || echo unknown)"

	local -a targets=()

	if [[ -n "$HOST_FILTER" ]]; then
		targets=("$HOST_FILTER")
	else
		mapfile -t targets < <(hosts_active_ssh)
		if [[ ${#targets[@]} -eq 0 ]]; then
			log_info "No active SSH hosts to sync (theme=$theme_name)"
			return 0
		fi
	fi

	local host
	for host in "${targets[@]}"; do
		sync_host "$host" "$theme_name"
	done
}

main "$@"
