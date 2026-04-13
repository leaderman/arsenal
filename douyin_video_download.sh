#!/bin/bash

# 加载 .env 文件
if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
fi

usage() {
    echo "Usage: douyin_video_download.sh <URL> [-d DEVICE]"
    echo ""
    echo "Arguments:"
    echo "  URL        Douyin share text or link (required)"
    echo "  -d DEVICE  Whisper device: gpu or cpu (optional, default: gpu)"
    echo ""
    echo "Examples:"
    echo "  ./douyin_video_download.sh \"https://v.douyin.com/wWSb0XLJXYQ/\""
    echo "  ./douyin_video_download.sh \"2.33 07/01 PXm:/ 视频标题 https://v.douyin.com/wWSb0XLJXYQ/ 复制此链接...\" -d cpu
  ./douyin_video_download.sh \"2.33 07/01 PXm:/ 视频标题 https://v.douyin.com/wWSb0XLJXYQ/ 复制此链接...\" -d gpu"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "Error: URL is required"
    echo ""
    usage
    exit 1
fi

INPUT="$1"
shift

DEVICE="gpu"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d) DEVICE="$2"; shift 2 ;;
        *) echo "Error: Unknown option '$1'"; echo ""; usage; exit 1 ;;
    esac
done

if [[ "$DEVICE" == "gpu" ]]; then
    WHISPER_DEVICE="mps"
elif [[ "$DEVICE" == "cpu" ]]; then
    WHISPER_DEVICE="cpu"
else
    echo "Error: DEVICE must be gpu or cpu"
    exit 1
fi

# 获取下载链接信息
echo "Fetching download link..."
OUTPUT=$(cdpx douyin video get-download-link "$INPUT")

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get download link"
    exit 1
fi

TOKEN=$(echo "$OUTPUT" | grep "  token:" | sed "s/.*token: '\(.*\)'.*/\1/")
LINK=$(echo "$OUTPUT"  | grep "  link:"  | sed "s/.*link: '\(.*\)'.*/\1/")

if [[ -z "$TOKEN" || -z "$LINK" ]]; then
    echo "Error: Failed to parse token or link from output"
    echo "$OUTPUT"
    exit 1
fi

FILE="${TOKEN}.mp4"

echo "Token: $TOKEN"
echo "File:  $FILE"
echo "Downloading..."

curl -L -o "$DOWNLOAD_DIR/$FILE" "$LINK"

# 转换语音为文本
echo "Transcribing (device: $DEVICE)..."
whisper "$DOWNLOAD_DIR/$FILE" --language Chinese --model large --device "$WHISPER_DEVICE" --output_format txt --output_dir "$DOWNLOAD_DIR"

echo ""
echo "Video: $DOWNLOAD_DIR/$FILE"
echo "Text:  $DOWNLOAD_DIR/${TOKEN}.txt"
