#!/usr/bin/env bash

# Report which hub ControlMasters are up. Prints one "host up|down" line per
# host; --write also stores it in $XDG_RUNTIME_DIR/hpc-status for agents and
# the systemd timer. Exit status 1 if any host is down.

set -Eeuo pipefail

HUB_HOSTS=(saga olivia)
write=0
hosts=()
for arg in "$@"; do
	case "$arg" in
	--write) write=1 ;;
	-h | --help)
		echo "Usage: $0 [--write] [host ...]"
		exit 0
		;;
	*) hosts+=("$arg") ;;
	esac
done
[[ ${#hosts[@]} -gt 0 ]] || hosts=("${HUB_HOSTS[@]}")

out=""
down=0
for host in "${hosts[@]}"; do
	if ssh -O check "$host" >/dev/null 2>&1; then
		out+="$host up"$'\n'
	else
		out+="$host down"$'\n'
		down=1
	fi
done

printf '%s' "$out"
if ((write)); then
	status_file="${XDG_RUNTIME_DIR:-/tmp}/hpc-status"
	{
		printf '# checked %s on %s\n' "$(date -Is)" "$(hostname -s)"
		printf '%s' "$out"
	} >"$status_file.tmp"
	mv "$status_file.tmp" "$status_file"
fi
exit "$down"
