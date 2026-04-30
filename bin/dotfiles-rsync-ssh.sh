#!/bin/bash

# General script to sync directories from remote machines to local machine
# Usage: ./dotfiles-rsync-ssh.sh [--source-dir DIR] [--target-dir DIR]
# Allows interactive selection of machine and multiple directories using gum

set -e # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
source "$SCRIPT_DIR/lib-hosts.sh"

# Default values
SOURCE_HOST=""
SOURCE_DIR="~/Code/DRL_RDE/data/studies"
TARGET_DIR="" # Will default to SOURCE_DIR if not specified
DELETE_FILES=true # Use --delete by default to mirror source exactly

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	-s | --source-dir)
		SOURCE_DIR="$2"
		shift 2
		;;
	-t | --target-dir)
		TARGET_DIR="$2"
		shift 2
		;;
	--no-delete)
		DELETE_FILES=false
		shift
		;;
	-h | --help)
		echo "Usage: $0 [--source-dir DIR] [--target-dir DIR]"
		echo
		echo "General script to sync directories from remote machines to local machine"
		echo
		echo "Options:"
		echo "  -s, --source-dir DIR   Remote source directory (default: ~/Code/DRL_RDE/data/studies)"
		echo "  -t, --target-dir DIR   Local target directory (default: same as source directory)"
		echo "                     Path is relative to home directory"
		echo "  --no-delete          Do not delete files in destination that don't exist in source"
		echo "                     Use this when merging files from multiple machines"
		echo "  -h, --help         Show this help message"
		echo
		echo "Examples:"
		echo "  $0                                                    # Interactive machine selection, sync studies"
		echo "  $0 --source-dir ~/Documents --target-dir ~/Backup   # Sync Documents to ~/Backup"
		echo "  $0 --no-delete                                      # Merge files without deleting"
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		echo "Use --help for usage information"
		exit 1
		;;
	esac
done

# Set default target directory to source directory if not specified
if [ -z "$TARGET_DIR" ]; then
	TARGET_DIR="$SOURCE_DIR"
fi

# Check if gum is installed
ensure_cmd gum

# Build first-level options (groups + standalone machines), sorted.
FIRST_LEVEL_OPTIONS=()
while IFS= read -r group; do
	[[ -z "$group" ]] && continue
	FIRST_LEVEL_OPTIONS+=("$group (group)")
done < <(hosts_groups)
while IFS= read -r machine; do
	[[ -z "$machine" ]] && continue
	FIRST_LEVEL_OPTIONS+=("$machine")
done < <(hosts_standalone_machines)

IFS=$'\n' FIRST_LEVEL_OPTIONS=($(printf '%s\n' "${FIRST_LEVEL_OPTIONS[@]}" | sort))

# First level menu: select group or standalone machine with fuzzy finding
SELECTED_FIRST=$(printf '%s\n' "${FIRST_LEVEL_OPTIONS[@]}" | gum filter \
	--header "🔍 Choose a group or machine:" \
	--placeholder "Type to search..." \
	--prompt "❯ ")

if [ -z "$SELECTED_FIRST" ]; then
	echo "❌ No selection made. Exiting."
	exit 0
fi

# Determine if it's a group or standalone machine
if [[ "$SELECTED_FIRST" == *" (group)" ]]; then
	GROUP_NAME="${SELECTED_FIRST% (group)}"

	readarray -t MACHINES < <(hosts_group_machines "$GROUP_NAME")

	if [[ ${#MACHINES[@]} -eq 0 ]]; then
		echo "❌ Group '$GROUP_NAME' has no machines."
		exit 1
	fi

	SELECTED_HOST=$(printf '%s\n' "${MACHINES[@]}" | gum filter \
		--header "🔍 Choose a machine from $GROUP_NAME:" \
		--placeholder "Type to search machines..." \
		--prompt "❯ ")

	if [ -z "$SELECTED_HOST" ]; then
		echo "❌ No machine selected. Exiting."
		exit 0
	fi
	SOURCE_HOST="$SELECTED_HOST"
else
	SOURCE_HOST="$SELECTED_FIRST"
fi

# Validate against the host inventory; jump-host wiring lives in ~/.ssh/config.
if ! hosts_all_machines | grep -qx "$SOURCE_HOST"; then
	echo "❌ Error: Unsupported host '$SOURCE_HOST' (not in $(hosts_toml_path))"
	exit 1
fi

# Expand tilde in paths
SOURCE_DIR_EXPANDED="${SOURCE_DIR/#\~/$HOME}"
TARGET_DIR_EXPANDED="${TARGET_DIR/#\~/$HOME}"

REMOTE_DIR="${SOURCE_HOST}:${SOURCE_DIR}"

echo "🔍 Fetching available directories from $SOURCE_HOST:$SOURCE_DIR..."

# Get list of directories from remote (fast - no size calculation)
REMOTE_DIR_LIST_SCRIPT=$(
	cat <<'EOF'
set -e
SOURCE_DIR="$1"
if [ -z "$SOURCE_DIR" ]; then
	exit 0
fi
case "$SOURCE_DIR" in
	~*)
		if [ -n "$HOME" ]; then
			SOURCE_DIR="${HOME}${SOURCE_DIR:1}"
		fi
		;;
esac
if ! cd "$SOURCE_DIR" 2>/dev/null; then
	exit 0
fi
shopt -s nullglob dotglob
for dir in */; do
	[ -d "$dir" ] || continue
	printf '%s\n' "${dir%/}"
done
EOF
)

echo "📂 Fetching directory list..."
DIR_LIST=$(ssh "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" <<<"$REMOTE_DIR_LIST_SCRIPT")

if [ -z "$DIR_LIST" ]; then
	echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
	exit 1
fi

# Parse directory list into array
DIR_ENTRY_ARRAY=()
while IFS= read -r dir_name; do
	if [ -n "$dir_name" ]; then
		DIR_ENTRY_ARRAY+=("$dir_name")
	fi
done <<<"$DIR_LIST"

if [ ${#DIR_ENTRY_ARRAY[@]} -eq 0 ]; then
	echo "❌ No directories found or unable to connect to $SOURCE_HOST:$SOURCE_DIR"
	exit 1
fi

# Use gum to let user select multiple directories
SELECTED=$(printf "%s\n" "${DIR_ENTRY_ARRAY[@]}" | gum choose --no-limit --height=15 \
	--header="Select directories to sync (Space to select, Enter to confirm):")

if [ -z "$SELECTED" ]; then
	echo "❌ No directories selected. Exiting."
	exit 0
fi

# Parse selected directories into array
FILTERED_DIRECTORIES=()
while IFS= read -r selected_line; do
	if [ -n "$selected_line" ]; then
		FILTERED_DIRECTORIES+=("$selected_line")
	fi
done <<<"$SELECTED"

# Now fetch sizes for only the selected directories (single SSH call)
echo "📊 Fetching sizes for ${#FILTERED_DIRECTORIES[@]} selected directories..."

# Build the remote script to get sizes for specific directories
REMOTE_SIZE_SCRIPT=$(
	cat <<'EOF'
set -e
SOURCE_DIR="$1"
shift
if [ -z "$SOURCE_DIR" ]; then
	exit 0
fi
case "$SOURCE_DIR" in
	~*)
		if [ -n "$HOME" ]; then
			SOURCE_DIR="${HOME}${SOURCE_DIR:1}"
		fi
		;;
esac
if ! cd "$SOURCE_DIR" 2>/dev/null; then
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

# Pass selected directories as arguments to the remote script
declare -A DIR_SIZES
SIZE_OUTPUT=$(ssh "$SOURCE_HOST" bash -s -- "$SOURCE_DIR" "${FILTERED_DIRECTORIES[@]}" <<<"$REMOTE_SIZE_SCRIPT")

# Parse size output
while IFS='|' read -r dir_name dir_size; do
	if [ -n "$dir_name" ]; then
		dir_size=$(echo "$dir_size" | tr -d '\n')
		if [ -z "$dir_size" ]; then
			dir_size="?"
		fi
		DIR_SIZES["$dir_name"]="$dir_size"
	fi
done <<<"$SIZE_OUTPUT"

echo
echo "📦 Selected directories:"
for directory in "${FILTERED_DIRECTORIES[@]}"; do
	dir_size="${DIR_SIZES["$directory"]}"
	echo "   $directory ($dir_size)"
done
echo
echo "📍 Source: $SOURCE_HOST:$SOURCE_DIR"
echo "📍 Target: $TARGET_DIR_EXPANDED"
if [ "$DELETE_FILES" = false ]; then
	echo "⚠️  Merge mode: files will not be deleted (merging from multiple machines)"
fi
echo

# Confirm before proceeding
if ! gum confirm "Proceed with syncing these directories?"; then
	echo "❌ Sync cancelled."
	exit 0
fi

# Prompt user about deleting files if not explicitly set with --no-delete
if [ "$DELETE_FILES" = true ]; then
	echo
	if gum confirm --default=false \
		--affirmative="Yes, delete files not on server" \
		--negative="No, keep all existing files (merge mode)" \
		"Delete files in destination that don't exist on $SOURCE_HOST?"; then
		DELETE_FILES=true
		echo "ℹ️  Delete mode: files will be deleted to match server exactly"
	else
		DELETE_FILES=false
		echo "ℹ️  Merge mode: files will not be deleted (safe for multiple machines)"
	fi
fi

echo
echo "🚀 Starting sync process..."

DIRECTORY_COUNT=${#FILTERED_DIRECTORIES[@]}
CURRENT_DIR=0

# Sync each selected directory
for directory in "${FILTERED_DIRECTORIES[@]}"; do
	CURRENT_DIR=$((CURRENT_DIR + 1))
	SOURCE="${REMOTE_DIR}/${directory}"
	DEST="${TARGET_DIR_EXPANDED}/${directory}"

	echo
	dir_size="${DIR_SIZES["$directory"]}"
	echo "📂 [$CURRENT_DIR/$DIRECTORY_COUNT] Syncing: $directory ($dir_size)"
	echo "   From: $SOURCE"
	echo "   To: $DEST"
	echo

	# Create local directory if it doesn't exist
	mkdir -p "$DEST"

	# Build rsync command with optional --delete flag
	RSYNC_DELETE_FLAG=""
	if [ "$DELETE_FILES" = true ]; then
		RSYNC_DELETE_FLAG="--delete"
	fi

	rsync -az $RSYNC_DELETE_FLAG --info=progress2 --no-inc-recursive "${SOURCE}/" "${DEST}/"

	echo "✅ [$CURRENT_DIR/$DIRECTORY_COUNT] Completed: $directory"
done

echo
echo "🎉 All syncs from $SOURCE_HOST:$SOURCE_DIR completed successfully!"
echo "📁 Files synced to: $TARGET_DIR_EXPANDED"
