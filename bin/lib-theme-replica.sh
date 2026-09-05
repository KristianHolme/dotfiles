#!/usr/bin/env bash
#
# Apply an already-rendered Omarchy theme on a replica (no Omarchy install).
# Consumes ~/.local/state/omarchy/current/theme/{colors.toml,tmux.conf,...}.
# Sourced by remote theme sync; safe to run locally too.

if [[ -n "${LIB_THEME_REPLICA_SH_SOURCED:-}" ]]; then
	return 0
fi
LIB_THEME_REPLICA_SH_SOURCED=1

OMARCHY_CURRENT_DIR="${HOME}/.local/state/omarchy/current"
OMARCHY_CURRENT_THEME="${OMARCHY_CURRENT_DIR}/theme"

# Parse one key from the staged colors.toml (quoted values).
theme_replica_color() {
	local key="$1"
	local file="${OMARCHY_CURRENT_THEME}/colors.toml"
	[[ -f $file ]] || return 1
	awk -F'=' -v want="$key" '
		{
			k=$1
			gsub(/[ "'\''\t]/, "", k)
			if (k == want) {
				v=$0
				sub(/^[^=]*=/, "", v)
				if (v ~ /"/) {
					sub(/^[^"]*"/, "", v)
					sub(/".*/, "", v)
				} else {
					gsub(/^[ \t]+|[ \t]+$/, "", v)
					sub(/[ \t]*#.*$/, "", v)
				}
				print v
				exit
			}
		}
	' "$file"
}

theme_replica_is_light() {
	local mode bg hex r g b lum
	mode="$(theme_replica_color mode || true)"
	[[ -z $mode ]] && mode="$(theme_replica_color theme_type || true)"
	if [[ $mode == "light" ]]; then
		return 0
	fi
	if [[ $mode == "dark" ]]; then
		return 1
	fi
	if [[ -f ${OMARCHY_CURRENT_THEME}/light.mode ]]; then
		return 0
	fi
	bg="$(theme_replica_color background || true)"
	[[ $bg =~ ^#[0-9A-Fa-f]{6}$ ]] || return 1
	hex="${bg#\#}"
	r=$((16#${hex:0:2}))
	g=$((16#${hex:2:2}))
	b=$((16#${hex:4:2}))
	lum=$((r + g + b))
	((lum > 382))
}

# OSC 10/11/12/17/19 + palette 0-15 for a live terminal/tmux pane.
theme_replica_osc() {
	local i val
	_emit_osc() {
		local code="$1" key="$2"
		val="$(theme_replica_color "$key" || true)"
		[[ -n $val ]] || return 0
		printf '\033]%s;%s\007' "$code" "$val"
	}
	_emit_osc 10 foreground
	_emit_osc 11 background
	_emit_osc 12 cursor
	_emit_osc 17 selection_background
	_emit_osc 19 selection_foreground
	for i in {0..15}; do
		val="$(theme_replica_color "color$i" || true)"
		[[ -n $val ]] || continue
		printf '\033]4;%d;%s\007' "$i" "$val"
	done
}

theme_replica_export_gum_env() {
	local gum_env="${OMARCHY_CURRENT_THEME}/gum_env.lua"
	local key value
	[[ -f $gum_env ]] || return 0
	while IFS=$'\t' read -r key value; do
		[[ -n $key && -n $value ]] || continue
		export "${key}=${value}"
	done < <(awk -F'"' '/hl\.env\("[A-Z0-9_]+", "[^"]+"\)/ { print $2 "\t" $4 }' "$gum_env")
}

theme_replica_apply_btop() {
	local theme_src="${OMARCHY_CURRENT_THEME}/btop.theme"
	local themes_dir="${HOME}/.config/btop/themes"
	local link="${themes_dir}/current.theme"
	local conf="${HOME}/.config/btop/btop.conf"

	[[ -f $theme_src ]] || return 0

	mkdir -p "$themes_dir"
	ln -snf "$theme_src" "$link"

	mkdir -p "$(dirname "$conf")"
	if [[ -f $conf ]]; then
		if grep -qE '^[[:space:]]*color_theme[[:space:]]*=' "$conf"; then
			sed -i -E 's|^[[:space:]]*color_theme[[:space:]]*=.*|color_theme = "current"|' "$conf"
		else
			printf '\ncolor_theme = "current"\n' >>"$conf"
		fi
	else
		printf 'color_theme = "current"\n' >"$conf"
	fi

	pkill -SIGUSR2 btop >/dev/null 2>&1 || true
}

theme_replica_apply_pi() {
	local src="${OMARCHY_CURRENT_THEME}/pi.json"
	local dest="${HOME}/.pi/agent/themes/omarchy-system.json"
	[[ -f $src && -d ${HOME}/.pi/agent ]] || return 0
	mkdir -p "$(dirname "$dest")"
	cp -f "$src" "$dest"
}

theme_replica_apply_claude() {
	local src="${OMARCHY_CURRENT_THEME}/claude.json"
	local dest="${HOME}/.claude/themes/omarchy.json"
	[[ -f $src && -d ${HOME}/.claude ]] || return 0
	mkdir -p "$(dirname "$dest")"
	cp -f "$src" "$dest"
}

theme_replica_apply_terminals() {
	local colors_toml="${OMARCHY_CURRENT_THEME}/colors.toml"
	local foot_pid child_pid tty osc

	if [[ -f ${HOME}/.config/alacritty/alacritty.toml ]]; then
		touch "${HOME}/.config/alacritty/alacritty.toml"
	fi
	if pgrep -x kitty >/dev/null 2>&1; then
		killall -SIGUSR1 kitty >/dev/null 2>&1 || true
	fi
	if pgrep -x ghostty >/dev/null 2>&1; then
		killall -SIGUSR2 ghostty >/dev/null 2>&1 || true
	fi

	if [[ -f $colors_toml ]] && pgrep -x foot >/dev/null 2>&1; then
		osc="$(theme_replica_osc)"
		if [[ -n $osc ]]; then
			for foot_pid in $(pgrep -x foot); do
				for child_pid in $(pgrep -P "$foot_pid" || true); do
					tty=$(readlink "/proc/${child_pid}/fd/1" 2>/dev/null || true)
					[[ $tty == /dev/pts/* ]] && printf '%b' "$osc" >"$tty" 2>/dev/null || true
				done
			done
		fi
	fi
}

theme_replica_tmux_set_env() {
	local key="$1"
	local value="$2"
	local session
	tmux set-environment -g "$key" "$value" 2>/dev/null || return 0
	while IFS= read -r session; do
		[[ -n $session ]] || continue
		tmux set-environment -t "$session" "$key" "$value" 2>/dev/null || true
	done < <(tmux list-sessions -F "#{session_id}" 2>/dev/null)
}

theme_replica_apply_tmux() {
	local theme_conf="${OMARCHY_CURRENT_THEME}/tmux.conf"
	local tmux_conf="${HOME}/.config/tmux/tmux.conf"
	local key value foreground background cursor colorfgbg osc pane_tty tpgid client

	if ! command -v tmux >/dev/null 2>&1; then
		return 0
	fi
	if ! tmux list-sessions >/dev/null 2>&1; then
		return 0
	fi

	if [[ -f $theme_conf ]]; then
		tmux source-file "$theme_conf" 2>/dev/null || true
	elif [[ -f $tmux_conf ]]; then
		tmux source-file "$tmux_conf" 2>/dev/null || true
	fi

	theme_replica_export_gum_env
	while IFS=$'\t' read -r key value; do
		[[ -n $key && -n $value ]] || continue
		theme_replica_tmux_set_env "$key" "$value"
	done < <(awk -F'"' '/hl\.env\("[A-Z0-9_]+", "[^"]+"\)/ { print $2 "\t" $4 }' "${OMARCHY_CURRENT_THEME}/gum_env.lua" 2>/dev/null)

	if theme_replica_is_light; then
		colorfgbg="0;15"
	else
		colorfgbg="15;0"
	fi
	theme_replica_tmux_set_env COLORFGBG "$colorfgbg"

	foreground="$(theme_replica_color foreground || true)"
	background="$(theme_replica_color background || true)"
	cursor="$(theme_replica_color cursor || true)"
	if [[ -n $foreground && -n $background ]]; then
		tmux set-option -g window-style "fg=${foreground},bg=${background}" 2>/dev/null || true
		tmux set-option -g window-active-style "fg=${foreground},bg=${background}" 2>/dev/null || true
	fi
	if [[ -n $cursor ]]; then
		tmux set-option -g cursor-colour "$cursor" 2>/dev/null || true
	fi

	osc="$(theme_replica_osc || true)"
	if [[ -n $osc ]]; then
		while IFS= read -r pane_tty; do
			[[ $pane_tty == /dev/pts/* ]] || continue
			printf '%b' "$osc" >"$pane_tty" 2>/dev/null || true
		done < <(tmux list-panes -a -F "#{pane_tty}" 2>/dev/null | sort -u)
	fi

	while IFS= read -r pane_tty; do
		[[ $pane_tty == /dev/pts/* ]] || continue
		tpgid=$(ps -o tpgid= -t "${pane_tty#/dev/}" 2>/dev/null | awk 'NF && $1 > 0 { print $1; exit }')
		[[ -n $tpgid ]] || continue
		kill -WINCH "-$tpgid" 2>/dev/null || true
	done < <(tmux list-panes -a -F "#{pane_tty}" 2>/dev/null | sort -u)

	while IFS= read -r client; do
		[[ -n $client ]] || continue
		tmux refresh-client -t "$client" 2>/dev/null || true
	done < <(tmux list-clients -F "#{client_name}" 2>/dev/null)
}

theme_replica_apply_helix() {
	if pgrep -x helix >/dev/null 2>&1; then
		pkill -USR1 helix >/dev/null 2>&1 || true
	fi
	if pgrep -x hx >/dev/null 2>&1; then
		pkill -USR1 hx >/dev/null 2>&1 || true
	fi
}

theme_replica_apply_opencode() {
	if pgrep -x opencode >/dev/null 2>&1; then
		killall -SIGUSR2 opencode >/dev/null 2>&1 || true
	fi
}

apply_omarchy_theme_replica() {
	if [[ ! -d $OMARCHY_CURRENT_THEME ]]; then
		echo "No staged theme at $OMARCHY_CURRENT_THEME" >&2
		return 1
	fi
	theme_replica_export_gum_env
	theme_replica_apply_btop
	theme_replica_apply_pi
	theme_replica_apply_claude
	theme_replica_apply_terminals
	theme_replica_apply_tmux
	theme_replica_apply_helix
	theme_replica_apply_opencode
	return 0
}
