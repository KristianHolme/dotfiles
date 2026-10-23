#!/usr/bin/env bash

# Open SSH ControlMasters for the 2FA hosts in hosts.toml [defaults] ssh_masters.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

usage() {
	cat <<EOF
Usage: $0 [--pause] [host ...]

Start a background ControlMaster (ssh -fN) for each host that has none, so
the 2FA prompt happens here once and later connections (herdr saved machines,
theme sync, rsync) reuse it until ControlPersist expires.
Hosts default to hosts.toml [defaults] ssh_masters.

  --pause   wait for a key before exiting (for herdr popups)
EOF
}

pause=0
hosts=()
for arg in "$@"; do
	case "$arg" in
	-h | --help)
		usage
		exit 0
		;;
	--pause) pause=1 ;;
	*) hosts+=("$arg") ;;
	esac
done

if [[ ${#hosts[@]} -eq 0 && "$(hostname -s)" != abacus-as ]]; then
	mapfile -t hosts < <(hosts_ssh_masters)
fi

# One login run at a time: overlapping runs send duplicate 2FA pushes.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-ssh-login.lock"
if ! flock -n 9; then
	log_warning "Another ssh login is already running"
	if ((pause)); then
		read -rsn1 -p "Press any key to close"
		echo
	fi
	exit 1
fi

failed=0
machine="$(hostname -s)"
log_info "Machine: $machine"

# abacus-as is the hub for Saga, Olivia and the ml nodes (sockets on local disk,
# no uio master); its login lives in dotfiles-hub-login.sh.
if [[ "$machine" == abacus-as ]]; then
	"$SCRIPT_DIR/dotfiles-hub-login.sh" "${hosts[@]}" || failed=1
	if ((pause)); then
		read -rsn1 -p "Press any key to close"
		echo
	fi
	exit "$failed"
fi

for host in "${hosts[@]}"; do
	if ssh -O check "$host" >/dev/null 2>&1; then
		log_info "$host: already logged in"
		continue
	fi
	log_info "$host: logging in"
	if ssh -fN "$host"; then
		log_success "$host: logged in"
	else
		log_warning "$host: login failed"
		failed=1
	fi
done

if ((pause)); then
	read -rsn1 -p "Press any key to close"
	echo
fi

exit "$failed"
