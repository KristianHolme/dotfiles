#!/usr/bin/env bash
set -Eeuo pipefail

# Compress video for web use
# Optimizes screen recordings and other videos for web playback
# Usage: dotfiles-compress-video.sh [OPTIONS] INPUT_VIDEO [OUTPUT_VIDEO]
#
# Options:
#   -q, --quality QUALITY    Quality preset: high|medium|low (default: medium)
#                            high: CRF 18 (larger file, best quality)
#                            medium: CRF 23 (balanced, recommended)
#                            low: CRF 28 (smaller file, lower quality)
#   -s, --scale WIDTH        Scale to width (maintains aspect ratio)
#                            Common: 1920, 1280, 854
#   -a, --audio-bitrate RATE Audio bitrate in kbps (default: 128)
#   -h, --help              Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"

show_help() {
    cat <<EOF
Compress video for web use

Usage: $0 [OPTIONS] INPUT_VIDEO [OUTPUT_VIDEO]

Arguments:
    INPUT_VIDEO         Path to input video file
    OUTPUT_VIDEO        Optional output path (default: adds .web.mp4 suffix)

Options:
    -q, --quality QUALITY    Quality preset: high|medium|low (default: medium)
                            high: CRF 18 (larger file, best quality)
                            medium: CRF 23 (balanced, recommended)
                            low: CRF 28 (smaller file, lower quality)
    -s, --scale WIDTH       Scale to width (maintains aspect ratio)
                            Common: 1920, 1280, 854
    -a, --audio-bitrate     Audio bitrate in kbps (default: 128)
    -h, --help              Show this help message

Examples:
    $0 recording.mp4
    $0 -q high recording.mp4 output.mp4
    $0 -q medium -s 1280 recording.mp4
    $0 -q low -a 96 recording.mp4 small.mp4

The script uses H.264 video codec and AAC audio codec for maximum web compatibility.
EOF
}

QUALITY="medium"
SCALE=""
AUDIO_BITRATE="128"
INPUT_FILE=""
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -s|--scale)
            SCALE="$2"
            shift 2
            ;;
        -a|--audio-bitrate)
            AUDIO_BITRATE="$2"
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
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            elif [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            else
                log_error "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate input file
if [[ -z "$INPUT_FILE" ]]; then
    log_error "Input video file required"
    show_help
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 1
fi

# Set output file
if [[ -z "$OUTPUT_FILE" ]]; then
    # Remove extension and add .web.mp4
    OUTPUT_FILE="${INPUT_FILE%.*}.web.mp4"
fi

# Validate quality preset
case "$QUALITY" in
    high)
        CRF="18"
        ;;
    medium)
        CRF="23"
        ;;
    low)
        CRF="28"
        ;;
    *)
        log_error "Invalid quality: $QUALITY (must be: high, medium, low)"
        exit 1
        ;;
esac

# Check for ffmpeg
ensure_cmd ffmpeg

# Build ffmpeg command
FFMPEG_CMD=(
    ffmpeg
    -i "$INPUT_FILE"
    -c:v libx264
    -preset slow
    -crf "$CRF"
    -c:a aac
    -b:a "${AUDIO_BITRATE}k"
    -movflags +faststart
)

# Add scale filter if requested
if [[ -n "$SCALE" ]]; then
    FFMPEG_CMD+=(-vf "scale=$SCALE:-2")
fi

# Add output file
FFMPEG_CMD+=("$OUTPUT_FILE")

# Show settings
log_info "Compressing video for web..."
log_info "  Input:  $INPUT_FILE"
log_info "  Output: $OUTPUT_FILE"
log_info "  Quality: $QUALITY (CRF $CRF)"
if [[ -n "$SCALE" ]]; then
    log_info "  Scale:  ${SCALE}px width (maintains aspect ratio)"
fi
log_info "  Audio:  ${AUDIO_BITRATE}kbps AAC"
echo

# Run ffmpeg
"${FFMPEG_CMD[@]}"

# Check if output was created
if [[ -f "$OUTPUT_FILE" ]]; then
    INPUT_SIZE=$(du -h "$INPUT_FILE" | cut -f1)
    OUTPUT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    log_success "Compression complete!"
    log_info "  Original size: $INPUT_SIZE"
    log_info "  Compressed size: $OUTPUT_SIZE"
    log_info "  Output: $OUTPUT_FILE"
else
    log_error "Output file was not created"
    exit 1
fi
