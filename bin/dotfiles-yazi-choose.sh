#!/usr/bin/env bash

# Choose files and directories, or one destination directory, with yazi.
# Usage: dotfiles-yazi-choose.sh --mode paths|dir [--output-file PATH] [start]
# stdout (or --output-file): one absolute path per line (empty if cancelled)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

OUTPUT_FILE=""
MODE=""

usage() {
    cat <<EOF
Usage: $0 --mode paths|dir [--output-file PATH] [start]

Open yazi at start (default: \$HOME).

  paths   One or more files, directories, or symlinks.
  dir     Exactly one directory. In yazi, a creates a file or directory;
          a name ending in / creates a directory.

Enter confirms the selection. Space toggles multi-select.
Paths are absolute, one per line, on stdout or in --output-file.
Empty output with exit 0 means the user cancelled without selecting.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --mode)
        [[ $# -ge 2 ]] || {
            log_error "--mode requires paths or dir"
            exit 1
        }
        MODE="$2"
        shift 2
        ;;
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

case "$MODE" in
paths | dir) ;;
*)
    log_error "Missing or unknown --mode (expected paths or dir)"
    exit 1
    ;;
esac

dotfiles_prepend_user_path
ensure_cmd yazi

if [[ ! -t 0 && ! -t 1 ]]; then
    log_error "Interactive terminal required"
    exit 1
fi

start="${1:-$HOME}"
if [[ ! -d "$start" ]]; then
    log_error "Start directory not found: $start"
    exit 1
fi
start="$(realpath "$start")"

chooser_file="$(mktemp)"
trap 'rm -f "$chooser_file"' EXIT

# Hint on stderr only (stdout must stay clean for callers that capture paths).
if [[ "$MODE" == "dir" ]]; then
    echo "Select one destination directory (Enter to confirm)." >&2
    echo "Create a folder with a; end the name with /." >&2
else
    echo "Select files and directories (Enter to confirm; Space for multi-select)." >&2
fi

# On many-core shared hosts (e.g. 256-core HPC login nodes) yazi's async runtime
# spawns threads proportional to visible cores, which can blow past a per-user
# nproc ulimit and crash/hang with EAGAIN. Cap visible cores for this TUI.
yazi_cmd=(yazi "$start" --chooser-file "$chooser_file")
if command -v taskset >/dev/null 2>&1 && command -v nproc >/dev/null 2>&1 && [[ "$(nproc)" -gt 16 ]]; then
    yazi_cmd=(taskset -c 0-7 "${yazi_cmd[@]}")
fi
"${yazi_cmd[@]}"

declare -a chosen=()
declare -A seen=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    if [[ ! -e "$line" && ! -L "$line" ]]; then
        log_error "Selected path does not exist: $line"
        exit 1
    fi

    if [[ "$MODE" == "paths" ]]; then
        if [[ ! -f "$line" && ! -d "$line" && ! -L "$line" ]]; then
            log_error "Not a file or directory: $line"
            exit 1
        fi
    elif [[ ! -d "$line" ]]; then
        log_error "Not a directory: $line"
        exit 1
    fi

    abs="$(realpath -s "$line")"
    if [[ -n "${seen[$abs]:-}" ]]; then
        continue
    fi
    seen[$abs]=1
    chosen+=("$abs")
done <"$chooser_file"

if [[ "$MODE" == "dir" && ${#chosen[@]} -gt 1 ]]; then
    log_error "Select one directory, not ${#chosen[@]}"
    exit 1
fi

write_paths() {
    local path
    if [[ -n "$OUTPUT_FILE" ]]; then
        mkdir -p "$(dirname "$OUTPUT_FILE")"
        : >"$OUTPUT_FILE"
        for path in "${chosen[@]}"; do
            printf '%s\n' "$path" >>"$OUTPUT_FILE"
        done
    else
        for path in "${chosen[@]}"; do
            printf '%s\n' "$path"
        done
    fi
}

write_paths
exit 0
