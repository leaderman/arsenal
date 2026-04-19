#!/bin/bash

if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
fi

export HF_ENDPOINT=https://hf-mirror.com

STABLE_SECONDS=3
TRANSCRIBE_DIR=$DOWNLOAD_DIR/text

while true; do
    found=0

    for file in "$DOWNLOAD_DIR"/page_clipper_douyin_*; do
        [[ -f "$file" ]] || continue

        filename=$(basename "$file")
        [[ "$filename" == *"("* ]] && continue

        mtime=$(stat -f "%m" "$file")
        now=$(date +%s)
        (( now - mtime <= STABLE_SECONDS )) && continue

        video_id="${filename#page_clipper_douyin_}"
        video_id="${video_id%.*}"

        [[ -f "$TRANSCRIBE_DIR/$video_id.txt" ]] && continue

        found=1

        echo "视频文件: $filename"
        echo "视频ID:   $video_id"

        mlx_whisper "$file" \
            --model mlx-community/whisper-large-v3-mlx \
            --language zh \
            --output-dir "$TRANSCRIBE_DIR" \
            --output-name "$video_id" \
            --output-format txt \
            --verbose False

        echo "视频文本: $video_id.txt"
    done

    (( found == 0 )) && sleep $STABLE_SECONDS
done
