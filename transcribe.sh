#!/bin/bash

if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
fi

export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_OFFLINE=1

STABLE_SECONDS=3
INPUT_DIR=""
CHECK_DIR=""
OUTPUT_DIR=""

usage() {
    echo "Usage: transcribe.sh [--input DIR] [--check DIR] [--output DIR]"
    echo ""
    echo "Arguments:"
    echo "  --input DIR   Directory to monitor for new audio files (default: \$DOWNLOAD_DIR)"
    echo "  --check DIR   Directory to check if an audio ID has already been processed (default: \$DOWNLOAD_DIR)"
    echo "  --output DIR  Directory to write transcription files (default: \$DOWNLOAD_DIR)"
    echo ""
    echo "Examples:"
    echo "  ./transcribe.sh"
    echo "  ./transcribe.sh --input ~/audios"
    echo "  ./transcribe.sh --input ~/audios --check ~/done --output ~/text"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)  INPUT_DIR="$2";  shift 2 ;;
        --check)  CHECK_DIR="$2";  shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Error: Unknown option '$1'"; echo ""; usage; exit 1 ;;
    esac
done

INPUT_DIR="${INPUT_DIR:-$DOWNLOAD_DIR}"
CHECK_DIR="${CHECK_DIR:-$DOWNLOAD_DIR}"
OUTPUT_DIR="${OUTPUT_DIR:-$DOWNLOAD_DIR}"

if [[ -z "$INPUT_DIR" ]]; then
    echo "Error: --input is required (or set DOWNLOAD_DIR in .env)"
    echo ""
    usage
    exit 1
fi

while true; do
    found=0

    for file in "$INPUT_DIR"/page_clipper_douyin_*; do
        [[ -f "$file" ]] || continue

        filename=$(basename "$file")
        [[ "$filename" == *"("* ]] && continue

        mtime=$(stat -f "%m" "$file")
        now=$(date +%s)
        (( now - mtime <= STABLE_SECONDS )) && continue

        audio_id="${filename#page_clipper_douyin_}"
        audio_id="${audio_id%.*}"

        [[ -f "$CHECK_DIR/$audio_id.md" ]] && continue

        found=1

        echo "音频文件: $filename"
        echo "音频ID:   $audio_id"

        mlx_whisper "$file" \
            --model mlx-community/whisper-large-v3-mlx \
            --language zh \
            --output-dir "$OUTPUT_DIR" \
            --output-name "$audio_id.md" \
            --output-format txt \
            --verbose False

        echo "音频文本: $audio_id.md"
    done

    (( found == 0 )) && sleep $STABLE_SECONDS
done
