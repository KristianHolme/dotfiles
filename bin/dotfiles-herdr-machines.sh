#!/usr/bin/env bash

# Register the herdr saved machines listed in hosts.toml [herdr].

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	cat <<EOF
Usage: $0 [--replace]

Add each [herdr] entry in hosts.toml as a herdr saved machine:
  herdr machine add <target> --label <label> --remote-session <label>
The session name is the label, so hosts that share a home directory keep
separate herdr state. Machines already saved with the same target and
session are skipped. A saved label with a different target or session is
reported and left unchanged, or removed and re-added with --replace.

2FA hosts need a live ControlMaster first: run dotfiles-ssh-login.sh.
EOF
	exit 0
fi

replace=0
[[ "${1:-}" == "--replace" ]] && replace=1

ensure_cmd herdr
ensure_cmd jq

saved="$(herdr machine list --json)"

mapfile -t entries < <(hosts_herdr_machines)
if [[ ${#entries[@]} -eq 0 ]]; then
	log_info "No [herdr] machines in $(hosts_toml_path)"
	exit 0
fi

failed=0
for entry in "${entries[@]}"; do
	label="${entry%%$'\t'*}"
	target="${entry#*$'\t'}"

	existing="$(jq -r --arg l "$label" '.[] | select(.label == $l) | "\(.id)\t\(.target)\t\(.session)"' <<<"$saved")"
	if [[ -n $existing ]]; then
		id="${existing%%$'\t'*}"
		existing="${existing#*$'\t'}"
		if [[ $existing == "$target"$'\t'"$label" ]]; then
			log_info "$label: already saved"
			continue
		fi
		if ((!replace)); then
			log_warning "$label: saved as ${existing/$'\t'/ session=}, expected $target session=$label (rerun with --replace)"
			continue
		fi
		log_info "$label: replacing ${existing/$'\t'/ session=}"
		herdr machine remove "$id" >/dev/null
	fi

	log_info "$label: adding $target (session $label)"
	if herdr machine add "$target" --label "$label" --remote-session "$label"; then
		log_success "$label: saved"
	else
		log_warning "$label: herdr machine add failed"
		failed=1
	fi
done

exit "$failed"
