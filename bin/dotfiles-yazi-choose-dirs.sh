#!/usr/bin/env bash

# Choose directories under a sync root with yazi (chooser mode).
# Usage: dotfiles-yazi-choose-dirs.sh [--output-file PATH] SYNC_ROOT [subpath]
# stdout (or --output-file): one validated relative path per line (empty if cancelled)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

OUTPUT_FILE=""

normalize_subpath() {
    local path="$1"
    path="${path#./}"
    path="${path%/}"
    if [[ "$path" == *..* ]]; then
        log_error "Invalid path (.. not allowed): $1"
        exit 1
    fi
    echo "$path"
}

usage() {
    cat <<EOF
Usage: $0 [--output-file PATH] SYNC_ROOT [subpath]

Open yazi at SYNC_ROOT or SYNC_ROOT/subpath and return selected directories
as paths relative to SYNC_ROOT (stdout or --output-file, one per line).

The sync root itself cannot be selected; only strict subdirectories are allowed.
Empty output with exit 0 means the user cancelled without selecting.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --output-file)
        [[ $# -ge 2 ]] || {
            log_error "--output-file requires a path argument"
            exit 1
        }
        OUTPUT_FILE="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        log_error "Unknown option: $1"
        exit 1
        ;;
    *)
        break
        ;;
    esac
done

if [[ $# -lt 1 ]]; then
    log_error "Missing SYNC_ROOT argument"
    exit 1
fi

SYNC_ROOT="$1"
subpath="$(normalize_subpath "${2:-}")"

ensure_cmd yazi

if [[ ! -t 0 && ! -t 1 ]]; then
    log_error "Interactive terminal required"
    exit 1
fi

if [[ ! -d "$SYNC_ROOT" ]]; then
    log_error "Sync root not found: $SYNC_ROOT"
    exit 1
fi

base="$(realpath "$SYNC_ROOT")"

if [[ -n "$subpath" ]]; then
    start="$base/$subpath"
else
    start="$base"
fi

if [[ ! -d "$start" ]]; then
    log_error "Browse path not found: $start"
    exit 1
fi

start="$(realpath "$start")"

if [[ "$start" != "$base" && "$start" != "$base"/* ]]; then
    log_error "Browse path not under sync root: $start"
    exit 1
fi

chooser_file="$(mktemp)"
trap 'rm -f "$chooser_file"' EXIT

# Hint on stderr only (stdout must stay clean for callers that capture paths).
echo "Select directories in yazi (Enter to confirm; Space for multi-select)" >&2

yazi "$start" --chooser-file "$chooser_file"

declare -a rel_paths=()
declare -A seen=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    if [[ ! -e "$line" ]]; then
        log_error "Selected path does not exist: $line"
        exit 1
    fi

    if [[ ! -d "$line" ]]; then
        log_error "Only directories can be selected: $line"
        exit 1
    fi

    abs="$(realpath "$line")"

    if [[ "$abs" != "$base"/* ]]; then
        log_error "Path not under sync root: $line"
        exit 1
    fi

    rel="${abs#"$base"/}"
    if [[ -z "$rel" || "$rel" == *..* ]]; then
        log_error "Invalid selection (sync root itself not allowed): $line"
        exit 1
    fi

    if [[ -n "${seen[$rel]:-}" ]]; then
        continue
    fi
    seen[$rel]=1
    rel_paths+=("$rel")
done < "$chooser_file"

if [[ -n "$OUTPUT_FILE" ]]; then
    : >"$OUTPUT_FILE"
    for rel in "${rel_paths[@]}"; do
        printf '%s\n' "$rel" >>"$OUTPUT_FILE"
    done
else
    for rel in "${rel_paths[@]}"; do
        printf '%s\n' "$rel"
    done
fi

exit 0
