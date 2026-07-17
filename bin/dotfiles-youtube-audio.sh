#!/usr/bin/env bash
set -Eeuo pipefail

# Download audio from YouTube and share via LocalSend
# Usage: dotfiles-youtube-audio.sh [OPTIONS] YOUTUBE_URL
#
# Options:
#   -f, --format FORMAT    Audio format: mp3|opus|m4a (default: mp3)
#   -q, --quality QUALITY  Audio quality: best|medium|low (default: best)
#   -k, --keep             Keep the downloaded file after sharing
#   -o, --output FILE      Specify output filename (default: auto from video title)
#   -h, --help             Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

show_help() {
    cat <<EOF
Download audio from YouTube and share via LocalSend

Usage: $0 [OPTIONS] YOUTUBE_URL

Arguments:
    YOUTUBE_URL         URL of the YouTube video to download audio from

Options:
    -f, --format FORMAT    Audio format: mp3|opus|m4a (default: mp3)
    -q, --quality QUALITY  Audio quality: best|medium|low (default: best)
                           best: highest available quality
                           medium: 192kbps
                           low: 128kbps
    -k, --keep             Keep the downloaded file after sharing
    -o, --output FILE      Specify output filename (default: auto from video title)
    -h, --help             Show this help message

Examples:
    $0 "https://youtube.com/watch?v=xxx"
    $0 -f opus -q medium "https://youtube.com/watch?v=xxx"
    $0 -k "https://youtube.com/watch?v=xxx"
    $0 -o "my-song.mp3" "https://youtube.com/watch?v=xxx"

Supported formats:
    mp3   - Most compatible, good quality
    opus  - Better compression, smaller files
    m4a   - Apple-compatible format
EOF
}

# Default variables
FORMAT="mp3"
QUALITY="best"
KEEP_FILE=false
OUTPUT_FILE=""
URL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -k|--keep)
            KEEP_FILE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$URL" ]]; then
                URL="$1"
            else
                log_error "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate URL
if [[ -z "$URL" ]]; then
    log_error "YouTube URL required"
    show_help
    exit 1
fi

# Validate format
case "$FORMAT" in
    mp3|opus|m4a)
        ;;
    *)
        log_error "Invalid format: $FORMAT (must be: mp3, opus, m4a)"
        exit 1
        ;;
esac

# Quality mapping
case "$QUALITY" in
    best)
        AUDIO_QUALITY="0"
        ;;
    medium)
        AUDIO_QUALITY="5"
        ;;
    low)
        AUDIO_QUALITY="9"
        ;;
    *)
        log_error "Invalid quality: $QUALITY (must be: best, medium, low)"
        exit 1
        ;;
esac

# Check for required commands
ensure_cmd yt-dlp localsend

# Create temporary download directory
DOWNLOAD_DIR=$(mktemp -d)

# Setup cleanup trap (only if not keeping files)
if [[ "$KEEP_FILE" == false ]]; then
    trap '[[ -d "$DOWNLOAD_DIR" ]] && rm -rf "$DOWNLOAD_DIR"' EXIT
fi

# Build output template
if [[ -n "$OUTPUT_FILE" ]]; then
    OUTPUT_TEMPLATE="$DOWNLOAD_DIR/$OUTPUT_FILE"
else
    OUTPUT_TEMPLATE="$DOWNLOAD_DIR/%(title)s.%(ext)s"
fi

# Show settings
log_info "Downloading audio from YouTube..."
log_info "  URL: $URL"
log_info "  Format: $FORMAT"
log_info "  Quality: $QUALITY"
if [[ -n "$OUTPUT_FILE" ]]; then
    log_info "  Output: $OUTPUT_FILE"
fi
echo

# Download audio using yt-dlp
yt-dlp -x --audio-format "$FORMAT" --audio-quality "$AUDIO_QUALITY" \
    -o "$OUTPUT_TEMPLATE" "$URL"

# Find the downloaded audio file
AUDIO_FILE=$(find "$DOWNLOAD_DIR" -type f \( -name "*.mp3" -o -name "*.opus" -o -name "*.m4a" \) | head -n1)

if [[ -z "$AUDIO_FILE" || ! -f "$AUDIO_FILE" ]]; then
    log_error "Failed to find downloaded audio file"
    exit 1
fi

log_success "Download complete: $(basename "$AUDIO_FILE")"
echo

# Share via LocalSend
log_info "Sharing via LocalSend..."
localsend send "$AUDIO_FILE"

log_success "Audio shared successfully!"

# Handle keeping the file
if [[ "$KEEP_FILE" == true ]]; then
    # Move file to current directory
    FINAL_FILE="$(pwd)/$(basename "$AUDIO_FILE")"
    mv "$AUDIO_FILE" "$FINAL_FILE"
    log_info "File saved: $FINAL_FILE"
fi
