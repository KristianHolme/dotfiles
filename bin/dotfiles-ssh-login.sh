#!/usr/bin/env bash

# Open SSH ControlMasters for the 2FA hosts in hosts.toml [defaults] ssh_masters.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

usage() {
	cat <<EOF
Usage: $0 [--rex] [--pause] [host ...]

Start a background ControlMaster (ssh -fN) for each host that has none, so
the 2FA prompt happens here once and later connections (Rex ssh:// hosts,
theme sync, rsync, rex-monitor) reuse it until ControlPersist expires.
Hosts default to hosts.toml [defaults] ssh_masters.

  --rex     no terminal: ssh asks in the Rex app's command palette
            (dotfiles-rex-askpass), and a summary shows there at the end.
            The Rex action ssh_login (Ctrl+Shift+L) runs this.
  --pause   wait for a key before exiting
EOF
}

pause=0
rex=0
hosts=()
for arg in "$@"; do
	case "$arg" in
	-h | --help)
		usage
		exit 0
		;;
	--pause) pause=1 ;;
	--rex) rex=1 ;;
	*) hosts+=("$arg") ;;
	esac
done

if [[ ${#hosts[@]} -eq 0 ]]; then
	mapfile -t hosts < <(hosts_ssh_masters)
fi

if ((rex)); then
	export SSH_ASKPASS="$SCRIPT_DIR/dotfiles-rex-askpass"
	export SSH_ASKPASS_REQUIRE=force
	exec </dev/null
fi

# Shows text in the Rex app's palette with OK, or Retry when retry is set.
# Prints the chosen id.
rex_summary() {
	local title="$1" detail="$2" retry="$3"
	local rex_bin
	rex_bin="$(command -v rex || echo "${HOME}/.local/bin/rex")"
	# shellcheck disable=SC2016
	env -u REX_BLOCK "$rex_bin" do --args "$(jq -n --arg t "$title" --arg d "$detail" --argjson r "$retry" \
		'{title: $t, detail: $d, retry: $r}')" -e '
local a = rex.args
local items = { { id = "ok", title = "OK", subtitle = a.detail } }
if a.retry then table.insert(items, 1, { id = "retry", title = "Retry", subtitle = a.detail }) end
local id = rex.ui.pick{ title = a.title, items = items, timeout = 3600 }
return id or "ok"' 2>/dev/null | tr -d '"'
}

# One login run at a time: overlapping runs send duplicate 2FA pushes.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-ssh-login.lock"
if ! flock -n 9; then
	log_warning "Another ssh login is already running"
	((rex)) && rex_summary "SSH login" "Another ssh login is already running" false >/dev/null
	if ((pause)); then
		read -rsn1 -p "Press any key to close"
		echo
	fi
	exit 1
fi

machine="$(hostname -s)"
log_info "Machine: $machine"

while true; do
failed=0
failed_hosts=()
ok_hosts=()
for host in "${hosts[@]}"; do
	if ssh -O check "$host" >/dev/null 2>&1; then
		# A master whose connection died (network change, sleep) still
		# answers -O check; only a command through it shows it is stale.
		if timeout 10 ssh -o BatchMode=yes "$host" true >/dev/null 2>&1; then
			log_info "$host: already logged in"
			ok_hosts+=("$host")
			continue
		fi
		log_warning "$host: master is stale, logging in again"
		ssh -O exit "$host" >/dev/null 2>&1
	fi
	log_info "$host: logging in"
	if DOTFILES_ASKPASS_HOST="$host" ssh -fN "$host"; then
		log_success "$host: logged in"
		ok_hosts+=("$host")
	else
		log_warning "$host: login failed"
		failed=1
		failed_hosts+=("$host")
	fi
done
((rex)) || break
if ((failed)); then
	detail="Failed: ${failed_hosts[*]}"
	((${#ok_hosts[@]})) && detail+=". Logged in: ${ok_hosts[*]}"
	[[ "$(rex_summary "SSH login on $machine" "$detail" true)" == retry ]] || break
	hosts=("${failed_hosts[@]}")
	continue
fi
rex_summary "SSH login on $machine" "Logged in: ${ok_hosts[*]}" false >/dev/null
break
done

if ((pause)); then
	read -rsn1 -p "Press any key to close"
	echo
fi

exit "$failed"
