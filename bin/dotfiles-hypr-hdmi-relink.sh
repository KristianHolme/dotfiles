#!/usr/bin/env bash
# Software-replug the office Samsung U32E850 after lock-screen DPMS.
#
# 4K@60 HDMI on Intel Iris Xe re-enables HDMI 2.0 scrambling too quickly for
# this panel. A physical unplug/replug recovers it; this script does the same
# in software (disable the output, then reload monitors.lua) once DPMS comes
# back on. If the monitor drops HPD entirely, only a real cable reseat works.

set -u

FLAKY_EDID="U32E850"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-hypr-hdmi-relink.lock"
REPLUG_COOLDOWN="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-hypr-hdmi-relink.replug"
REPLUG_COOLDOWN_SEC=6

usage() {
	cat <<EOF
Usage: $0 <replug|watch>

replug   Disable the Samsung output and reload Hyprland (software cable reseat)
watch    After the Samsung wakes from DPMS, replug it once
EOF
}

safe_connector() {
	[[ $1 =~ ^[A-Za-z0-9._-]+$ ]]
}

monitors_json() {
	hyprctl monitors all -j 2>/dev/null
}

flaky_name() {
	monitors_json | jq -r --arg needle "$FLAKY_EDID" '
		.[] | select((.description // "") | contains($needle)) | .name
	' 2>/dev/null | head -1
}

flaky_drm_connected() {
	local d
	for d in /sys/class/drm/card*-*; do
		[[ -f $d/status && -f $d/edid ]] || continue
		[[ $(<"$d/status") == connected ]] || continue
		strings "$d/edid" 2>/dev/null | grep -Fq "$FLAKY_EDID" && return 0
	done
	return 1
}

flaky_dpms() {
	local name=$1
	monitors_json | jq -r --arg n "$name" '.[] | select(.name == $n) | .dpmsStatus' 2>/dev/null
}

cooldown_ok() {
	local now last
	now=$(date +%s)
	last=$(<"$REPLUG_COOLDOWN" 2>/dev/null || echo 0)
	((now - last >= REPLUG_COOLDOWN_SEC)) || return 1
	printf '%s\n' "$now" >"$REPLUG_COOLDOWN"
}

cmd_replug() {
	local name
	name=$(flaky_name)
	[[ -n $name ]] && safe_connector "$name" || return 0
	cooldown_ok || return 0

	# Same sequence as unplugging: drop the output, wait for SCDC, then
	# re-apply monitors.lua so the 4K@60 mode comes back as a new link.
	hyprctl eval "hl.monitor({ output = \"$name\", disabled = true })" >/dev/null 2>&1 || true
	sleep 0.4
	hyprctl reload >/dev/null 2>&1 || true
}

cmd_watch() {
	local socket event hypr_dir name dpms prev=""
	if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
		hypr_dir=$(find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
		[[ -n $hypr_dir ]] && HYPRLAND_INSTANCE_SIGNATURE=$(basename "$hypr_dir")
	fi
	socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"

	exec 9>"$LOCK"
	flock -n 9 || exit 0

	if [[ -S $socket ]]; then
		while read -r event; do
			case "$event" in
			monitoradded\>\>* | monitoraddedv2\>\>* | monitorremoved\>\>* | monitorremovedv2\>\>*)
				# DRM still sees the panel but Hyprland dropped it: reload.
				if flaky_drm_connected && [[ -z $(flaky_name) ]]; then
					cmd_replug
				fi
				;;
			esac
		done < <(socat -U - "UNIX-CONNECT:$socket") &
	fi

	while true; do
		name=$(flaky_name)
		if [[ -n $name ]]; then
			dpms=$(flaky_dpms "$name")
			if [[ $prev == "false" && $dpms == "true" ]]; then
				sleep 0.25
				cmd_replug
			fi
			prev=$dpms
		elif flaky_drm_connected; then
			cmd_replug
			prev=""
		else
			prev=""
		fi
		sleep 1
	done
}

cmd=${1:-}
case "$cmd" in
-h | --help) usage ;;
replug) cmd_replug ;;
watch) cmd_watch ;;
*)
	usage >&2
	exit 2
	;;
esac
