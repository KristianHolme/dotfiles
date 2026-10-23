#!/usr/bin/env bash

# Open SSH ControlMasters for the 2FA hosts on the hub (abacus-as). Sockets live
# in /run/user/UID (see hub/dot-ssh/hpc.conf); each master is moved into its own
# systemd user scope so it survives logout and herdr restarts.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

HUB_HOSTS=(saga olivia)

usage() {
	cat <<EOF2
Usage: $0 [host ...]

Start a background ControlMaster for each host that has none; the password/2FA
prompt happens here once. Agents then reuse it through plain \`ssh <host>\`.
Hosts default to: ${HUB_HOSTS[*]}
EOF2
}

hosts=()
for arg in "$@"; do
	case "$arg" in
	-h | --help)
		usage
		exit 0
		;;
	*) hosts+=("$arg") ;;
	esac
done
[[ ${#hosts[@]} -gt 0 ]] || hosts=("${HUB_HOSTS[@]}")

run=()
if command -v systemd-run >/dev/null 2>&1; then
	run=(systemd-run --user --scope --quiet)
fi

failed=0
log_info "Machine: $(hostname -s) (hub)"
for host in "${hosts[@]}"; do
	if ssh -O check "$host" >/dev/null 2>&1; then
		log_info "$host: already logged in"
		continue
	fi
	log_info "$host: logging in"
	if "${run[@]}" ssh -o ControlMaster=yes -o BatchMode=no -o ControlPersist=24h -fN "$host" &&
		ssh -O check "$host" >/dev/null 2>&1; then
		log_success "$host: logged in"
	else
		log_warning "$host: login failed"
		failed=1
	fi
done

"$SCRIPT_DIR/dotfiles-hub-status.sh" --write >/dev/null 2>&1 || true
exit "$failed"
