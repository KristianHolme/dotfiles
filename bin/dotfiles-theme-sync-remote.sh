#!/usr/bin/env bash
#
# Push the current Omarchy theme to SSH hosts that are actively connected
# (ControlMaster up, or a live ssh process targeting the inventory alias).
# Also used by dst on connect for a single host.
#
# Usage:
#   dotfiles-theme-sync-remote.sh              # all active hosts
#   dotfiles-theme-sync-remote.sh --host ALIAS
#   dotfiles-theme-sync-remote.sh --theme "Tokyo Night" [--host ALIAS]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"
# shellcheck source=lib-hosts.sh
source "$SCRIPT_DIR/lib-hosts.sh"

usage() {
	cat <<EOF
Usage: $0 [--host ALIAS] [--theme NAME]

Sync the Omarchy theme to active SSH hosts from hosts.toml (or one host).

  --host ALIAS   Sync only this inventory alias (e.g. dst after connect)
  --theme NAME   Theme display name or kebab-case (default: local current theme)

Active = ControlMaster up (\`ssh -O check\`) or a live ssh process targeting
the alias. Omarchy desktops (Hyprland running) get a full theme set; replicas
use OMARCHY_THEME_SKIP_BACKGROUND=1. Third-party themes from packages.toml
are installed/updated on the remote first.
EOF
}

THEME_NAME=""
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
		THEME_NAME="${2:-}"
		[[ -n "$THEME_NAME" ]] || {
			log_error "--theme requires a name"
			exit 1
		}
		shift 2
		;;
	*)
		log_error "Unknown argument: $1"
		usage
		exit 1
		;;
	esac
done

# Display name preferred (omarchy theme set accepts it); fall back to theme.name.
resolve_local_theme() {
	local name path
	if command -v omarchy-theme-current >/dev/null 2>&1; then
		name="$(omarchy-theme-current 2>/dev/null || true)"
		if [[ -n "$name" && "$name" != "Unknown" ]]; then
			echo "$name"
			return 0
		fi
	fi
	path="${HOME}/.config/omarchy/current/theme.name"
	if [[ -f "$path" ]]; then
		sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g' <"$path"
		return 0
	fi
	return 1
}

# True if a live ssh process has this inventory alias as a destination argument.
host_in_live_ssh_ps() {
	local host="$1"
	ps -eo args= 2>/dev/null | awk -v h="$host" '
		{
			cmd = $0
			sub(/^[[:space:]]+/, "", cmd)
			n = split(cmd, a, /[[:space:]]+/)
			base = a[1]
			sub(/.*\//, "", base)
			if (base != "ssh") next
			for (i = 2; i <= n; i++) {
				arg = a[i]
				if (arg ~ /^-/) continue
				# Destination: host or user@host (first non-option after options)
				sub(/^[^@]+@/, "", arg)
				if (arg == h) {
					found = 1
					exit
				}
				# Only the first non-option is the destination for typical ssh
				break
			}
		}
		END { exit !found }
	'
}

# Print active inventory aliases (one per line), excluding the local hostname.
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
			continue
		fi
		if host_in_live_ssh_ps "$host"; then
			echo "$host"
		fi
	done < <(hosts_all_machines)
}

# SSH options: never block on interactive MFA for sync probes/applies.
_SSH_SYNC_OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o PreferredAuthentications=publickey)

# Apply theme on one remote host. Never exits non-zero for the caller.
sync_host() {
	local host="$1"
	local theme="$2"

	log_info "Syncing theme '$theme' -> $host"

	if ! ssh "${_SSH_SYNC_OPTS[@]}" "$host" "true" >/dev/null 2>&1; then
		log_warning "Skip $host: SSH not available (BatchMode/auth/timeout)"
		return 0
	fi

	# Remote: ensure third-party themes, then set theme (full if Hyprland, else skip bg).
	# Non-interactive: set OMARCHY_PATH/PATH and source dotfiles libs from ~/dotfiles.
	# shellcheck disable=SC2029 # intentional: expand theme into remote env assignment
	if ! ssh "${_SSH_SYNC_OPTS[@]}" "$host" \
		"THEME_NAME=$(printf '%q' "$theme") bash -s" <<'REMOTE'
set -euo pipefail

export OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$HOME/dotfiles/bin${PATH:+:$PATH}"

if [[ ! -d "$OMARCHY_PATH" ]]; then
	echo "omarchy clone missing at $OMARCHY_PATH" >&2
	exit 1
fi

if [[ ! -f "$HOME/dotfiles/bin/lib-install.sh" ]]; then
	echo "dotfiles not applied at ~/dotfiles (need dar/dac)" >&2
	exit 1
fi

# Avoid a stale guard from a prior sourced shell in rare SendEnv cases.
unset LIB_INSTALL_SH_SOURCED LIB_PACKAGES_SH_SOURCED LIB_DOTFILES_SH_SOURCED

# shellcheck disable=SC1091
source "$HOME/dotfiles/bin/lib-install.sh"

if declare -F setup_omarchy_themes >/dev/null 2>&1; then
	setup_omarchy_themes || true
else
	echo "setup_omarchy_themes missing; pull/update ~/dotfiles on this host" >&2
fi

if ! command -v omarchy-theme-set >/dev/null 2>&1; then
	echo "omarchy-theme-set not on PATH" >&2
	exit 1
fi

set +e
if pgrep -x Hyprland >/dev/null 2>&1; then
	omarchy-theme-set "$THEME_NAME"
else
	OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set "$THEME_NAME"
fi
rc=$?
set -e

# Replicas lack the desktop install symlink; point btop at Omarchy's btop.theme.
if declare -F ensure_btop_omarchy_theme >/dev/null 2>&1; then
	ensure_btop_omarchy_theme || true
fi

exit "$rc"
REMOTE
	then
		log_warning "Theme sync failed on $host (see remote stderr above)"
		return 0
	fi

	log_success "Theme synced on $host"
	return 0
}

main() {
	if [[ -z "$THEME_NAME" ]]; then
		THEME_NAME="$(resolve_local_theme)" || {
			log_error "Could not determine local Omarchy theme"
			exit 1
		}
	fi

	local -a targets=()

	if [[ -n "$HOST_FILTER" ]]; then
		targets=("$HOST_FILTER")
	else
		mapfile -t targets < <(hosts_active_ssh)
		if [[ ${#targets[@]} -eq 0 ]]; then
			log_info "No active SSH hosts to sync (theme=$THEME_NAME)"
			return 0
		fi
	fi

	local host
	for host in "${targets[@]}"; do
		sync_host "$host" "$THEME_NAME"
	done
}

main "$@"
