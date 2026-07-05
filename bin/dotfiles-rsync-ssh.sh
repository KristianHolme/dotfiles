#!/usr/bin/env bash

# Sync directories between remote machines and ~/Code using hosts.toml sync_root.
# Usage: ./dotfiles-rsync-ssh.sh [host] [browse-path] [options]
#        ./dotfiles-rsync-ssh.sh --remote [source] [target] [browse-path] [options]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

SYNC_PUSH=false
SYNC_REMOTE=false
SOURCE_HOST=""
TARGET_HOST=""
TARGET_REMOTE_BASE=""
DELETE_FILES=true
CLI_HOST=""
CLI_TARGET=""
CLI_SUBPATH=""
POSITIONAL=()

normalize_subpath() {
    local path="$1"
    path="${path#./}"
    path="${path%/}"
    if [[ "$path" == *..* ]]; then
        echo "❌ Invalid path (.. not allowed): $1" >&2
        exit 1
    fi
    echo "$path"
}

parse_host_path_arg() {
    local arg="$1" host="${arg%%:*}"
    if ! hosts_all_machines | grep -qx "$host"; then
        echo "❌ Unknown host in '$arg'" >&2
        exit 1
    fi
    CLI_HOST="$host"
    CLI_SUBPATH="$(normalize_subpath "${arg#*:}")"
}

select_host_interactive() {
    local first_level_options=() selected_first group_name selected_host

    while IFS= read -r group; do
        [[ -z "$group" ]] && continue
        first_level_options+=("$group (group)")
    done < <(hosts_groups)
    while IFS= read -r machine; do
        [[ -z "$machine" ]] && continue
        first_level_options+=("$machine")
    done < <(hosts_standalone_machines)

    IFS=$'\n' first_level_options=($(printf '%s\n' "${first_level_options[@]}" | sort))

    selected_first=$(printf '%s\n' "${first_level_options[@]}" | gum filter \
        --header "🔍 Choose a group or machine:" \
        --placeholder "Type to search..." \
        --prompt "❯ ")

    if [[ -z "$selected_first" ]]; then
        echo "❌ No selection made. Exiting."
        exit 0
    fi

    if [[ "$selected_first" == *" (group)" ]]; then
        group_name="${selected_first% (group)}"
        readarray -t machines < <(hosts_group_machines "$group_name")
        if [[ ${#machines[@]} -eq 0 ]]; then
            echo "❌ Group '$group_name' has no machines."
            exit 1
        fi
        selected_host=$(printf '%s\n' "${machines[@]}" | gum filter \
            --header "🔍 Choose a machine from $group_name:" \
            --placeholder "Type to search machines..." \
            --prompt "❯ ")
        if [[ -z "$selected_host" ]]; then
            echo "❌ No machine selected. Exiting."
            exit 0
        fi
        SOURCE_HOST="$selected_host"
    else
        SOURCE_HOST="$selected_first"
    fi
}

select_target_host_interactive() {
    local machines=() selected_host

    while IFS= read -r machine; do
        [[ -z "$machine" || "$machine" == "$SOURCE_HOST" ]] && continue
        machines+=("$machine")
    done < <(hosts_all_machines)

    if [[ ${#machines[@]} -eq 0 ]]; then
        echo "❌ No target hosts available."
        exit 1
    fi

    selected_host=$(printf '%s\n' "${machines[@]}" | gum filter \
        --header "🔍 Choose target machine:" \
        --placeholder "Type to search machines..." \
        --prompt "❯ ")
    if [[ -z "$selected_host" ]]; then
        echo "❌ No target machine selected. Exiting."
        exit 0
    fi
    TARGET_HOST="$selected_host"
}

load_sync_context_for_host() {
    local host="$1" context kind key remote_path local_path remote_base local_base
    context="$(hosts_ssh_alias_context "$host")" || exit 1
    IFS=$'\t' read -r kind key remote_path local_path <<<"$context"
    remote_base="$(hosts_sync_root_remote_base "$kind" "$key")"
    local_base="$(hosts_expand_path "$(hosts_sync_root_local "$kind" "$key")")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$key" "$remote_path" "$local_path" "$remote_base" "$local_base"
}

resolve_host_context() {
    local context
    context="$(load_sync_context_for_host "$SOURCE_HOST")"
    IFS=$'\t' read -r FS_KIND FS_KEY FS_REMOTE_PATH FS_LOCAL_PATH REMOTE_BASE LOCAL_BASE <<<"$context"
}

parse_positionals() {
    local count=${#POSITIONAL[@]}

    case "$count" in
    0) ;;
    1)
        if hosts_all_machines | grep -qx "${POSITIONAL[0]}"; then
            CLI_HOST="${POSITIONAL[0]}"
        elif [[ "${POSITIONAL[0]}" == *:* ]]; then
            parse_host_path_arg "${POSITIONAL[0]}"
        else
            CLI_SUBPATH="$(normalize_subpath "${POSITIONAL[0]}")"
        fi
        ;;
    2)
        CLI_HOST="${POSITIONAL[0]}"
        CLI_SUBPATH="$(normalize_subpath "${POSITIONAL[1]}")"
        ;;
    *)
        echo "❌ Too many arguments."
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
}

parse_remote_positionals() {
    local count=${#POSITIONAL[@]}

    case "$count" in
    0) ;;
    1)
        if hosts_all_machines | grep -qx "${POSITIONAL[0]}"; then
            CLI_HOST="${POSITIONAL[0]}"
        elif [[ "${POSITIONAL[0]}" == *:* ]]; then
            parse_host_path_arg "${POSITIONAL[0]}"
        else
            CLI_SUBPATH="$(normalize_subpath "${POSITIONAL[0]}")"
        fi
        ;;
    2)
        if hosts_all_machines | grep -qx "${POSITIONAL[0]}" &&
            hosts_all_machines | grep -qx "${POSITIONAL[1]}"; then
            CLI_HOST="${POSITIONAL[0]}"
            CLI_TARGET="${POSITIONAL[1]}"
        else
            echo "❌ --remote with two arguments expects source and target hosts."
            echo "Use --help for usage information"
            exit 1
        fi
        ;;
    3)
        if ! hosts_all_machines | grep -qx "${POSITIONAL[0]}" ||
            ! hosts_all_machines | grep -qx "${POSITIONAL[1]}"; then
            echo "❌ --remote expects source and target hosts before browse-path."
            echo "Use --help for usage information"
            exit 1
        fi
        CLI_HOST="${POSITIONAL[0]}"
        CLI_TARGET="${POSITIONAL[1]}"
        CLI_SUBPATH="$(normalize_subpath "${POSITIONAL[2]}")"
        ;;
    *)
        echo "❌ Too many arguments."
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
}

resolve_remote_hosts() {
    local context

    if [[ -n "$CLI_HOST" ]]; then
        SOURCE_HOST="$CLI_HOST"
    else
        select_host_interactive
    fi

    if ! hosts_all_machines | grep -qx "$SOURCE_HOST"; then
        echo "❌ Error: Unsupported source host '$SOURCE_HOST' (not in $(hosts_toml_path))"
        exit 1
    fi

    if [[ -n "$CLI_TARGET" ]]; then
        TARGET_HOST="$CLI_TARGET"
    else
        select_target_host_interactive
    fi

    if ! hosts_all_machines | grep -qx "$TARGET_HOST"; then
        echo "❌ Error: Unsupported target host '$TARGET_HOST' (not in $(hosts_toml_path))"
        exit 1
    fi
    if [[ "$SOURCE_HOST" == "$TARGET_HOST" ]]; then
        echo "❌ Source and target must be different hosts."
        exit 1
    fi

    resolve_host_context
    context="$(load_sync_context_for_host "$TARGET_HOST")"
    IFS=$'\t' read -r TARGET_FS_KIND TARGET_FS_KEY TARGET_REMOTE_PATH TARGET_LOCAL_PATH TARGET_REMOTE_BASE TARGET_LOCAL_BASE <<<"$context"
}

mount_local_base_for_remote() {
    if [[ -z "${FS_LOCAL_PATH:-}" || -z "${FS_REMOTE_PATH:-}" ]]; then
        return 0
    fi
    if ! command -v findmnt >/dev/null 2>&1; then
        return 0
    fi
    if ! findmnt --mountpoint "$FS_LOCAL_PATH" &>/dev/null; then
        return 0
    fi
    if [[ "$REMOTE_BASE" == "$FS_REMOTE_PATH" ]]; then
        echo "$FS_LOCAL_PATH"
    elif [[ "$REMOTE_BASE" == "$FS_REMOTE_PATH"/* ]]; then
        echo "$FS_LOCAL_PATH/${REMOTE_BASE#"$FS_REMOTE_PATH"/}"
    fi
}

validate_filtered_directories() {
    local base rel abs base_real resolved_base mount_local_base=""

    if [[ "$SYNC_PUSH" == true && "$SYNC_REMOTE" != true ]]; then
        base="$LOCAL_BASE"
        resolved_base="$LOCAL_BASE"
    else
        base="$REMOTE_BASE"
        mount_local_base="$(mount_local_base_for_remote || true)"
        resolved_base="${mount_local_base:-$REMOTE_BASE}"
    fi

    if [[ -d "$resolved_base" ]]; then
        base_real="$(realpath "$resolved_base")"
    else
        base_real="$(realpath -m "$base")"
    fi

    for rel in "${FILTERED_DIRECTORIES[@]}"; do
        if [[ -z "$rel" || "$rel" == /* || "$rel" == *..* ]]; then
            echo "❌ Invalid path: $rel" >&2
            exit 1
        fi

        if [[ -d "$resolved_base" ]]; then
            abs="$(realpath -m "$resolved_base/$rel")"
        else
            abs="$(realpath -m "$base/$rel")"
        fi

        if [[ "$abs" == "$base_real" ]]; then
            echo "❌ Cannot sync sync root itself: $rel" >&2
            exit 1
        fi

        if [[ "$abs" != "$base_real"/* ]]; then
            echo "❌ Path not under sync root: $rel" >&2
            exit 1
        fi

        if [[ -d "$resolved_base" && ! -d "$abs" ]]; then
            echo "❌ Not a directory: $rel" >&2
            exit 1
        fi
    done
}

select_directories() {
    local anchor_rel="${1:-}" choose_script="$SCRIPT_DIR/dotfiles-yazi-choose-dirs.sh"
    local mount_local_base="" remote_cache_file="" remote_cmd="" ssh_status=0

    if [[ "$SYNC_PUSH" == true && "$SYNC_REMOTE" != true ]]; then
        mapfile -t FILTERED_DIRECTORIES < <("$choose_script" "$LOCAL_BASE" "$anchor_rel")
    else
        mount_local_base="$(mount_local_base_for_remote || true)"
        if [[ -n "$mount_local_base" ]]; then
            mapfile -t FILTERED_DIRECTORIES < <("$choose_script" "$mount_local_base" "$anchor_rel")
        else
            ensure_ssh_controlmaster "$SOURCE_HOST"
            remote_cache_file="dotfiles-yazi-choose-$$.paths"

            # Invoke the wrapper already deployed on the remote directly as the ssh
            # command: stdin must remain the local TTY for -t (yazi needs a PTY), so no
            # heredoc/script piping. ssh joins arguments into one remote shell string,
            # so quote values with printf %q (an empty subpath would otherwise vanish).
            # stdout is not captured either; paths go to the remote output file.
            remote_cmd="\"\$HOME/dotfiles/bin/dotfiles-yazi-choose-dirs.sh\""
            remote_cmd+=" --output-file \"\$HOME/.cache/$remote_cache_file\""
            remote_cmd+=" $(printf '%q' "$REMOTE_BASE")"
            if [[ -n "$anchor_rel" ]]; then
                remote_cmd+=" $(printf '%q' "$anchor_rel")"
            fi
            ssh -t "$SOURCE_HOST" "$remote_cmd" || ssh_status=$?
            if [[ $ssh_status -ne 0 ]]; then
                exit "$ssh_status"
            fi

            # Reuse ControlMaster (no extra TCP handshake).
            mapfile -t FILTERED_DIRECTORIES < <(
                ssh "$SOURCE_HOST" "f=\"\$HOME/.cache/$remote_cache_file\"; if [[ -f \"\$f\" ]]; then cat \"\$f\"; rm -f \"\$f\"; fi"
            )
        fi
    fi

    if [[ ${#FILTERED_DIRECTORIES[@]} -eq 0 ]]; then
        echo "❌ No selection made. Exiting."
        exit 0
    fi
}

fetch_directory_sizes() {
    local size_output="" directory dir size

    echo "📊 Fetching sizes for ${#FILTERED_DIRECTORIES[@]} selected directories..."

    if [[ "$SYNC_PUSH" == true && "$SYNC_REMOTE" != true ]]; then
        if ! cd "$LOCAL_BASE" 2>/dev/null; then
            echo "❌ Cannot access local base: $LOCAL_BASE"
            exit 1
        fi
        for directory in "${FILTERED_DIRECTORIES[@]}"; do
            if [[ -d "$directory" ]]; then
                size=$(du -sh -- "$directory" 2>/dev/null | cut -f1)
                DIR_SIZES["$directory"]="${size:-?}"
            fi
        done
        return 0
    fi

    size_output=$(ssh "$SOURCE_HOST" bash -s -- "$REMOTE_BASE" "${FILTERED_DIRECTORIES[@]}" <<'EOF'
set -e
source_dir="$1"
shift
if [ -z "$source_dir" ]; then
	exit 0
fi
if ! cd "$source_dir" 2>/dev/null; then
	exit 0
fi
for dir in "$@"; do
	if [ -d "$dir" ]; then
		size=$(du -sh -- "$dir" 2>/dev/null | cut -f1)
		if [ -z "$size" ]; then
			size="?"
		fi
		printf '%s|%s\n' "$dir" "$size"
	fi
done
EOF
)

    while IFS='|' read -r dir_name dir_size; do
        [[ -n "$dir_name" ]] || continue
        dir_size="${dir_size//$'\n'/}"
        DIR_SIZES["$dir_name"]="${dir_size:-?}"
    done <<<"$size_output"
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --remote)
        SYNC_REMOTE=true
        shift
        ;;
    --push)
        SYNC_PUSH=true
        shift
        ;;
    --no-delete)
        DELETE_FILES=false
        shift
        ;;
    -h | --help)
        echo "Usage: $0 [host] [browse-path] [options]"
        echo "       $0 --remote [source] [target] [browse-path] [options]"
        echo
        echo "Sync directories between remote machines and local ~/Code using hosts.toml sync_root."
        echo "Default: pull from remote to local. Use --push to browse local folders and push to remote."
        echo "Use --remote to copy selected folders from one remote host to another."
        echo "Positional browse-path opens the folder browser at that location (does not sync immediately)."
        echo
        echo "Options:"
        echo "  --push               Browse local sync root and push selected folders to remote"
        echo "  --remote             Browse source host and copy selected folders to target host"
        echo "  --no-delete          Do not delete files in destination missing on source"
        echo "  -h, --help           Show this help message"
        echo
        echo "Examples:"
        echo "  $0"
        echo "  $0 DRL_Sphere"
        echo "  $0 fox DRL_Sphere"
        echo "  $0 fox:DRL_Sphere"
        echo "  $0 --push nam-shub-01"
        echo "  $0 --push fox DRL_Sphere"
        echo "  $0 --remote fox ml3 DRL_Sphere/data"
        echo "  $0 --remote DRL_Sphere"
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

if [[ "$SYNC_REMOTE" == true && "$SYNC_PUSH" == true ]]; then
    echo "❌ --remote and --push cannot be used together."
    exit 1
fi

ensure_cmd gum yazi

FILTERED_DIRECTORIES=()
declare -A DIR_SIZES

if [[ "$SYNC_REMOTE" == true ]]; then
    parse_remote_positionals
    resolve_remote_hosts
else
    parse_positionals

    if [[ -n "$CLI_HOST" ]]; then
        SOURCE_HOST="$CLI_HOST"
    else
        select_host_interactive
    fi

    if ! hosts_all_machines | grep -qx "$SOURCE_HOST"; then
        echo "❌ Error: Unsupported host '$SOURCE_HOST' (not in $(hosts_toml_path))"
        exit 1
    fi

    resolve_host_context
fi
select_directories "$CLI_SUBPATH"
validate_filtered_directories

ensure_ssh_controlmaster "$SOURCE_HOST"
if [[ "$SYNC_REMOTE" == true ]]; then
    ensure_ssh_controlmaster "$TARGET_HOST"
fi
fetch_directory_sizes

echo
echo "📦 Selected directories:"
for directory in "${FILTERED_DIRECTORIES[@]}"; do
    dir_size="${DIR_SIZES[$directory]:-?}"
    echo "   $directory ($dir_size)"
done
echo
if [[ "$SYNC_REMOTE" == true ]]; then
    echo "📍 Source host: $SOURCE_HOST"
    echo "📍 Target host: $TARGET_HOST"
elif [[ "$SYNC_PUSH" == true ]]; then
    echo "📍 Remote host: $SOURCE_HOST"
else
    echo "📍 Source host: $SOURCE_HOST"
fi
if [[ "$SYNC_REMOTE" == true ]]; then
    echo "📍 Source base: $REMOTE_BASE"
    echo "📍 Target base: $TARGET_REMOTE_BASE"
elif [[ "$SYNC_PUSH" == true ]]; then
    echo "📍 Remote base: $REMOTE_BASE"
    echo "📍 Local base: $LOCAL_BASE"
else
    echo "📍 Remote base: $REMOTE_BASE"
    echo "📍 Local base: $LOCAL_BASE"
fi
if [[ "$SYNC_REMOTE" == true ]]; then
    echo "📍 Direction: remote → remote"
elif [[ "$SYNC_PUSH" == true ]]; then
    echo "📍 Direction: push (local → remote)"
else
    echo "📍 Direction: pull (remote → local)"
fi
if [[ "$DELETE_FILES" == false ]]; then
    echo "⚠️  Merge mode: files will not be deleted"
fi
echo

sync_verb="syncing"
if [[ "$SYNC_REMOTE" == true ]]; then
    sync_verb="copying"
elif [[ "$SYNC_PUSH" == true ]]; then
    sync_verb="pushing"
fi
if ! gum confirm "Proceed with $sync_verb these directories?"; then
    echo "❌ Sync cancelled."
    exit 0
fi

if [[ "$DELETE_FILES" == true ]]; then
    echo
    delete_prompt=""
    if [[ "$SYNC_REMOTE" == true ]]; then
        delete_prompt="Delete files on $TARGET_HOST that don't exist on $SOURCE_HOST?"
    elif [[ "$SYNC_PUSH" == true ]]; then
        delete_prompt="Delete files on $SOURCE_HOST that don't exist locally?"
    else
        delete_prompt="Delete files in destination that don't exist on $SOURCE_HOST?"
    fi
    if gum confirm --default=false \
        --affirmative="Yes, delete extra files" \
        --negative="No, keep all existing files (merge mode)" \
        "$delete_prompt"; then
        DELETE_FILES=true
        if [[ "$SYNC_REMOTE" == true ]]; then
            echo "ℹ️  Delete mode: target files will be deleted to match source exactly"
        elif [[ "$SYNC_PUSH" == true ]]; then
            echo "ℹ️  Delete mode: remote files will be deleted to match local exactly"
        else
            echo "ℹ️  Delete mode: local files will be deleted to match remote exactly"
        fi
    else
        DELETE_FILES=false
        echo "ℹ️  Merge mode: files will not be deleted"
    fi
fi

echo
if [[ "$SYNC_REMOTE" == true ]]; then
    echo "🚀 Starting remote copy process..."
elif [[ "$SYNC_PUSH" == true ]]; then
    echo "🚀 Starting push process..."
else
    echo "🚀 Starting sync process..."
fi

directory_count=${#FILTERED_DIRECTORIES[@]}
current_dir=0
staging_root=""
if [[ "$SYNC_REMOTE" == true ]]; then
    staging_root="$(mktemp -d "${TMPDIR:-/tmp}/drs-remote.XXXXXX")"
    trap '[[ -z "${staging_root:-}" ]] || rm -rf "$staging_root"' EXIT
fi

for directory in "${FILTERED_DIRECTORIES[@]}"; do
    current_dir=$((current_dir + 1))
    dir_size="${DIR_SIZES[$directory]:-?}"

    rsync_delete_flag=""
    if [[ "$DELETE_FILES" == true ]]; then
        rsync_delete_flag="--delete"
    fi

    if [[ "$SYNC_REMOTE" == true ]]; then
        staging_dir="$staging_root/$directory"
        rsync_src="${SOURCE_HOST}:${REMOTE_BASE}/${directory}/"
        rsync_dest="${TARGET_HOST}:${TARGET_REMOTE_BASE}/${directory}/"
        echo
        echo "📂 [$current_dir/$directory_count] Copying: $directory ($dir_size)"
        echo "   From: $rsync_src"
        echo "   To: $rsync_dest"
        echo
        mkdir -p "$staging_dir"
        rsync -az --info=progress2 --no-inc-recursive "$rsync_src" "$staging_dir/"
        ssh "$TARGET_HOST" mkdir -p "${TARGET_REMOTE_BASE}/${directory}"
        rsync -az $rsync_delete_flag --info=progress2 --no-inc-recursive "$staging_dir/" "$rsync_dest"
        rm -rf "$staging_dir"
    elif [[ "$SYNC_PUSH" == true ]]; then
        rsync_src="${LOCAL_BASE}/${directory}/"
        rsync_dest="${SOURCE_HOST}:${REMOTE_BASE}/${directory}/"
        echo
        echo "📂 [$current_dir/$directory_count] Pushing: $directory ($dir_size)"
        echo "   From: $rsync_src"
        echo "   To: $rsync_dest"
        echo
        ssh "$SOURCE_HOST" mkdir -p "${REMOTE_BASE}/${directory}"
        rsync -az $rsync_delete_flag --info=progress2 --no-inc-recursive "$rsync_src" "$rsync_dest"
    else
        rsync_src="${SOURCE_HOST}:${REMOTE_BASE}/${directory}/"
        rsync_dest="${LOCAL_BASE}/${directory}/"
        echo
        echo "📂 [$current_dir/$directory_count] Syncing: $directory ($dir_size)"
        echo "   From: $rsync_src"
        echo "   To: $rsync_dest"
        echo
        mkdir -p "$rsync_dest"
        rsync -az $rsync_delete_flag --info=progress2 --no-inc-recursive "$rsync_src" "$rsync_dest"
    fi

    echo "✅ [$current_dir/$directory_count] Completed: $directory"
done

echo
if [[ "$SYNC_REMOTE" == true ]]; then
    echo "🎉 All copies from $SOURCE_HOST to $TARGET_HOST completed successfully!"
    echo "📁 Files copied to: $TARGET_HOST:$TARGET_REMOTE_BASE"
elif [[ "$SYNC_PUSH" == true ]]; then
    echo "🎉 All pushes to $SOURCE_HOST completed successfully!"
    echo "📁 Files pushed to: $SOURCE_HOST:$REMOTE_BASE"
else
    echo "🎉 All syncs from $SOURCE_HOST completed successfully!"
    echo "📁 Files synced to: $LOCAL_BASE"
fi
