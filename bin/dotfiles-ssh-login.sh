#!/usr/bin/env bash

# Open SSH ControlMasters for the 2FA hosts in hosts.toml [defaults] ssh_masters.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

usage() {
	cat <<EOF
Usage: $0 [--pick] [--pause] [host ...]

Start a background ControlMaster (ssh -fN) for each host that has none, so
the 2FA prompt happens here once and later connections (Rex ssh:// hosts,
theme sync, rsync, rex-monitor) reuse it until ControlPersist expires.
Hosts default to hosts.toml [defaults] ssh_masters.

  --pick    choose the hosts in a gum menu first, all selected at the start:
            x or tab toggle, ctrl+a toggle all, enter log in, esc cancel
  --pause   wait for a key before exiting (for the Rex floating pane)

The Rex action ssh_login (Ctrl+Shift+L) runs this with --pick --pause.
EOF
}

pause=0
pick=0
hosts=()
for arg in "$@"; do
	case "$arg" in
	-h | --help)
		usage
		exit 0
		;;
	--pause) pause=1 ;;
	--pick) pick=1 ;;
	*) hosts+=("$arg") ;;
	esac
done

finish() {
	if ((pause)); then
		read -rsn1 -p "Press any key to close"
		echo
	fi
	exit "$1"
}

if [[ ${#hosts[@]} -eq 0 ]]; then
	mapfile -t hosts < <(hosts_ssh_masters)
fi

# Prints the hosts chosen in a gum multi-select menu, one per line.
# Exits 1 on cancel.
pick_hosts() {
	local h status
	local -a options=()
	for h in "$@"; do
		status="-"
		ssh -O check "$h" >/dev/null 2>&1 && status="master up"
		options+=("$(printf '%-10s %s' "$h" "$status"):$h")
	done
	gum choose --no-limit --selected='*' --label-delimiter=: \
		--header="SSH login on $machine" "${options[@]}"
}

# One login run at a time: overlapping runs send duplicate 2FA pushes.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-ssh-login.lock"
if ! flock -n 9; then
	log_warning "Another ssh login is already running"
	finish 1
fi

machine="$(hostname -s)"
log_info "Machine: $machine"

if ((pick && ${#hosts[@]} > 1)); then
	if ! picked="$(pick_hosts "${hosts[@]}")"; then
		log_warning "SSH login cancelled"
		finish 0
	fi
	if [[ -z $picked ]]; then
		log_info "No hosts selected"
		finish 0
	fi
	mapfile -t hosts <<<"$picked"
fi

while true; do
	failed_hosts=()
	for host in "${hosts[@]}"; do
		if ssh -O check "$host" >/dev/null 2>&1; then
			# A master whose connection died (network change, sleep) still
			# answers -O check; only a command through it shows it is stale.
			if timeout 10 ssh -o BatchMode=yes "$host" true >/dev/null 2>&1; then
				log_info "$host: already logged in"
				continue
			fi
			log_warning "$host: master is stale, logging in again"
			ssh -O exit "$host" >/dev/null 2>&1
		fi
		log_info "$host: logging in"
		if ssh -fN "$host"; then
			log_success "$host: logged in"
		else
			log_warning "$host: login failed"
			failed_hosts+=("$host")
		fi
	done
	((${#failed_hosts[@]})) || finish 0
	[[ -t 0 ]] || finish 1
	read -rp "Retry ${failed_hosts[*]}? [y/N] " answer
	[[ $answer == [yY]* ]] || finish 1
	hosts=("${failed_hosts[@]}")
done
