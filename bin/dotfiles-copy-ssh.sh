#!/usr/bin/env bash

# Free-copy mode for dotfiles-rsync-ssh.sh: any files and directories into one folder.
# The rsync script's mode menu execs this file. Usage: ./dotfiles-copy-ssh.sh [source] [target]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

CHOOSER="$SCRIPT_DIR/dotfiles-yazi-choose.sh"
SOURCE=""
TARGET=""
DEST=""
CLI_SOURCE=""
CLI_TARGET=""
SELECTED_HOST=""
POSITIONAL=()
PATHS=()
declare -A SIZES=()

usage() {
    cat <<EOF
Usage: $0 [source] [target]

Copy selected files and directories into one directory on another host.
Source and target are hosts.toml aliases, or "local" for this machine.
Omit either host to pick it interactively.

Yazi on the source selects files and directories (Enter confirms; Space multi-selects).
Yazi on the target selects one destination directory.
In that yazi, a creates a file or directory; a name ending in / creates a directory.

Every selection is copied by its own name into that directory.
A directory is copied as a directory. Two selections with the same name are refused.
A name that already exists in the destination is updated. Extra files already there stay.

Remote-to-remote copies pass through this machine. The source host does not SSH to the target.
Yazi opens at \$HOME on each host.

Examples:
  $0
  $0 fox
  $0 local ml3
  $0 fox local
EOF
}

host_is_local() {
    [[ "$1" == "local" ]]
}

host_label() {
    if host_is_local "$1"; then
        printf '%s\n' "this machine"
    else
        printf '%s\n' "$1"
    fi
}

item_name() {
    local path="${1%/}" name="${path##*/}"
    if [[ -z "$name" || "$name" == "." || "$name" == ".." ]]; then
        echo "❌ Refusing path: $1" >&2
        exit 1
    fi
    printf '%s\n' "$name"
}

normalize_host_arg() {
    local host="$1" alias=""
    alias="$(hosts_local_machine_alias || true)"
    if [[ "$host" == "local" || (-n "$alias" && "$host" == "$alias") ]]; then
        printf '%s\n' local
        return 0
    fi
    if ! hosts_all_machines | grep -qx "$host"; then
        echo "❌ Unknown host '$host' (not in $(hosts_toml_path))" >&2
        exit 1
    fi
    printf '%s\n' "$host"
}

select_host_interactive() {
    local header="$1" exclude_id="${2:-}"
    local -a options=() rest=() machines=()
    local selected="" group_name="" alias="" machine=""

    alias="$(hosts_local_machine_alias || true)"

    while IFS= read -r group_name; do
        [[ -z "$group_name" ]] && continue
        rest+=("$group_name (group)")
    done < <(hosts_groups)

    while IFS= read -r machine; do
        [[ -z "$machine" ]] && continue
        if [[ -n "$alias" && "$machine" == "$alias" ]]; then
            continue
        fi
        if [[ "$exclude_id" == "$machine" ]]; then
            continue
        fi
        rest+=("$machine")
    done < <(hosts_standalone_machines)

    if [[ ${#rest[@]} -gt 0 ]]; then
        mapfile -t rest < <(printf '%s\n' "${rest[@]}" | sort)
    fi

    options=()
    if [[ "$exclude_id" != "local" ]]; then
        options+=("this machine")
    fi
    if [[ ${#rest[@]} -gt 0 ]]; then
        options+=("${rest[@]}")
    fi

    if [[ ${#options[@]} -eq 0 ]]; then
        echo "❌ No hosts available."
        exit 1
    fi

    selected=$(printf '%s\n' "${options[@]}" | gum filter \
        --header "$header" \
        --placeholder "Type to search..." \
        --prompt "❯ ")

    if [[ -z "$selected" ]]; then
        echo "❌ No selection made. Exiting."
        exit 0
    fi

    if [[ "$selected" == "this machine" ]]; then
        SELECTED_HOST="local"
        return 0
    fi

    if [[ "$selected" == *" (group)" ]]; then
        group_name="${selected% (group)}"
        machines=()
        while IFS= read -r machine; do
            [[ -z "$machine" ]] && continue
            if [[ -n "$alias" && "$machine" == "$alias" ]]; then
                [[ "$exclude_id" == "local" ]] && continue
                machines+=("this machine")
                continue
            fi
            [[ "$exclude_id" == "$machine" ]] && continue
            machines+=("$machine")
        done < <(hosts_group_machines "$group_name")

        if [[ ${#machines[@]} -eq 0 ]]; then
            echo "❌ Group '$group_name' has no machines."
            exit 1
        fi

        selected=$(printf '%s\n' "${machines[@]}" | gum filter \
            --header "🔍 Choose a machine from $group_name:" \
            --placeholder "Type to search machines..." \
            --prompt "❯ ")
        if [[ -z "$selected" ]]; then
            echo "❌ No machine selected. Exiting."
            exit 0
        fi
        if [[ "$selected" == "this machine" ]]; then
            SELECTED_HOST="local"
            return 0
        fi
        SELECTED_HOST="$selected"
        return 0
    fi

    SELECTED_HOST="$selected"
}

read_path_lines() {
    local output="$1"
    local -n _out="$2"
    local line
    _out=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        _out+=("$line")
    done <<<"$output"
}

# The chooser must already be on the remote: ssh -t keeps stdin as the TTY, so
# the script cannot be piped over the connection. Paths come back on a second
# ssh; the yazi session itself stays on the terminal.
remote_choose_tty() {
    local host="$1" mode="$2"
    local cache="dotfiles-yazi-choose-$$.paths" remote_cmd=""

    remote_cmd="\"\$HOME/dotfiles/bin/dotfiles-yazi-choose.sh\""
    remote_cmd+=" --mode $(printf '%q' "$mode")"
    remote_cmd+=" --output-file \"\$HOME/.cache/$cache\""

    ssh -t "$host" "$remote_cmd"
}

remote_choose_read() {
    local host="$1"
    local cache="dotfiles-yazi-choose-$$.paths"

    ssh "$host" "f=\"\$HOME/.cache/$cache\"; if [[ -f \"\$f\" ]]; then cat \"\$f\"; rm -f \"\$f\"; fi"
}

choose_on_host() {
    local host="$1" mode="$2" array_name="$3"
    local output="" status=0

    if host_is_local "$host"; then
        output="$("$CHOOSER" --mode "$mode")" || status=$?
        if [[ $status -ne 0 ]]; then
            exit "$status"
        fi
        read_path_lines "$output" "$array_name"
        return 0
    fi

    ensure_ssh_controlmaster "$host"
    remote_choose_tty "$host" "$mode" || status=$?
    if [[ $status -ne 0 ]]; then
        exit "$status"
    fi
    output="$(remote_choose_read "$host")" || status=$?
    if [[ $status -ne 0 ]]; then
        exit "$status"
    fi
    read_path_lines "$output" "$array_name"
}

refuse_duplicate_names() {
    local -A seen=()
    local path name
    for path in "$@"; do
        name="$(item_name "$path")"
        if [[ -n "${seen[$name]:-}" ]]; then
            echo "❌ Two selections have the same name '$name':" >&2
            echo "   ${seen[$name]}" >&2
            echo "   $path" >&2
            exit 1
        fi
        seen["$name"]="$path"
    done
}

fetch_sizes() {
    local host="$1"
    shift
    local output="" path="" size=""

    echo "📊 Fetching sizes for ${#PATHS[@]} selected items..."

    if host_is_local "$host"; then
        for path in "$@"; do
            size="$(du -sh -- "$path" 2>/dev/null | cut -f1 || true)"
            SIZES["$path"]="${size:-?}"
        done
        return 0
    fi

    output="$(ssh "$host" bash -s -- "$@" <<'EOF'
set -e
for path in "$@"; do
    size=$(du -sh -- "$path" 2>/dev/null | cut -f1)
    printf '%s\t%s\n' "$path" "${size:-?}"
done
EOF
)" || true

    while IFS=$'\t' read -r path size || [[ -n "$path" ]]; do
        [[ -n "$path" ]] || continue
        size="${size//$'\n'/}"
        SIZES["$path"]="${size:-?}"
    done <<<"$output"
}

dest_display() {
    if host_is_local "$TARGET"; then
        printf '%s\n' "$DEST"
    else
        printf '%s:%s\n' "$TARGET" "$DEST"
    fi
}

copy_item() {
    local path="$1" name="$2" dest_spec="" stage_dir=""

    # No trailing slash on the source: a directory is copied as itself.
    path="${path%/}"

    if host_is_local "$TARGET"; then
        dest_spec="${DEST}/"
    else
        dest_spec="${TARGET}:${DEST}/"
    fi

    if host_is_local "$SOURCE"; then
        rsync -az --info=progress2 --no-inc-recursive -- "$path" "$dest_spec"
    elif host_is_local "$TARGET"; then
        rsync -az --info=progress2 --no-inc-recursive -- "${SOURCE}:${path}" "$dest_spec"
    else
        stage_dir="$staging_root/$name"
        rm -rf "$stage_dir"
        rsync -az --info=progress2 --no-inc-recursive -- "${SOURCE}:${path}" "$staging_root/"
        rsync -az --info=progress2 --no-inc-recursive -- "$staging_root/$name" "$dest_spec"
        rm -rf "$stage_dir"
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

case ${#POSITIONAL[@]} in
0) ;;
1) CLI_SOURCE="${POSITIONAL[0]}" ;;
2)
    CLI_SOURCE="${POSITIONAL[0]}"
    CLI_TARGET="${POSITIONAL[1]}"
    ;;
*)
    echo "❌ Too many arguments."
    echo "Use --help for usage information"
    exit 1
    ;;
esac

ensure_cmd gum yazi rsync

if [[ -n "$CLI_SOURCE" ]]; then
    SOURCE="$(normalize_host_arg "$CLI_SOURCE")"
else
    select_host_interactive "🔍 Choose source machine:"
    SOURCE="$SELECTED_HOST"
fi

if [[ -n "$CLI_TARGET" ]]; then
    TARGET="$(normalize_host_arg "$CLI_TARGET")"
    if [[ "$SOURCE" == "$TARGET" ]]; then
        echo "❌ Source and target must be different hosts."
        exit 1
    fi
fi

choose_on_host "$SOURCE" paths PATHS
if [[ ${#PATHS[@]} -eq 0 ]]; then
    echo "❌ No selection made. Exiting."
    exit 0
fi
refuse_duplicate_names "${PATHS[@]}"

if [[ -z "$TARGET" ]]; then
    select_host_interactive "🔍 Choose target machine:" "$SOURCE"
    TARGET="$SELECTED_HOST"
    if [[ "$SOURCE" == "$TARGET" ]]; then
        echo "❌ Source and target must be different hosts."
        exit 1
    fi
fi

DEST_PATHS=()
choose_on_host "$TARGET" dir DEST_PATHS
if [[ ${#DEST_PATHS[@]} -eq 0 ]]; then
    echo "❌ No destination selected. Exiting."
    exit 0
fi
DEST="${DEST_PATHS[0]}"

if ! host_is_local "$SOURCE"; then
    ensure_ssh_controlmaster "$SOURCE"
fi
if ! host_is_local "$TARGET"; then
    ensure_ssh_controlmaster "$TARGET"
fi

fetch_sizes "$SOURCE" "${PATHS[@]}"

echo
echo "📦 Selected items:"
for path in "${PATHS[@]}"; do
    printf '   %s (%s)\n' "$path" "${SIZES[$path]:-?}"
done
echo
printf '📍 Source: %s\n' "$(host_label "$SOURCE")"
printf '📍 Target: %s\n' "$(host_label "$TARGET")"
printf '📍 Destination: %s\n' "$(dest_display)"
echo

if ! gum confirm "Copy these ${#PATHS[@]} items into $(dest_display)?"; then
    echo "❌ Copy cancelled."
    exit 0
fi

echo
echo "🚀 Starting copy..."

staging_root=""
if ! host_is_local "$SOURCE" && ! host_is_local "$TARGET"; then
    # Stage locally: the source host does not need an SSH path to the target.
    staging_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-copy.XXXXXX")"
    trap '[[ -z "${staging_root:-}" ]] || rm -rf "$staging_root"' EXIT
fi

count=${#PATHS[@]}
current=0
for path in "${PATHS[@]}"; do
    current=$((current + 1))
    name="$(item_name "$path")"
    echo
    printf '📂 [%s/%s] Copying: %s (%s)\n' "$current" "$count" "$name" "${SIZES[$path]:-?}"
    printf '   From: %s\n' "$path"
    if host_is_local "$TARGET"; then
        printf '   To: %s/%s\n' "$DEST" "$name"
    else
        printf '   To: %s:%s/%s\n' "$TARGET" "$DEST" "$name"
    fi
    echo
    copy_item "$path" "$name"
    printf '✅ [%s/%s] Completed: %s\n' "$current" "$count" "$name"
done

echo
printf '🎉 Copy into %s completed.\n' "$(dest_display)"
