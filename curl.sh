#!/bin/bash

# 加载 .env 文件
if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
fi

usage() {
    echo "Usage: curl.sh <URL> [-f FILE] [-s SERVER]"
    echo ""
    echo "Arguments:"
    echo "  URL       Download URL (required)"
    echo "  -f FILE   Local filename (optional, extracted from URL if omitted)"
    echo "  -s SERVER Server number: 1 or 2 (optional, default: 1)"
    echo ""
    echo "Examples:"
    echo "  ./curl.sh https://example.com/file.zip"
    echo "  ./curl.sh https://example.com/file.zip -f myfile.zip"
    echo "  ./curl.sh https://example.com/file.zip -s 2"
    echo "  ./curl.sh https://example.com/file.zip -f myfile.zip -s 2"
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

URL="$1"
shift

FILE=""
SERVER="1"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f) FILE="$2"; shift 2 ;;
        -s) SERVER="$2"; shift 2 ;;
        *) echo "Error: Unknown option '$1'"; echo ""; usage; exit 1 ;;
    esac
done

FILE="${FILE:-$(basename "$URL")}"

if [[ "$SERVER" == "1" ]]; then
    KEY=$ORACLE_SERVER1_KEY
    LOCAL_PORT=$ORACLE_SERVER1_LOCAL_PORT
    USER=$ORACLE_SERVER1_USER
    IP=$ORACLE_SERVER1_IP
elif [[ "$SERVER" == "2" ]]; then
    KEY=$ORACLE_SERVER2_KEY
    LOCAL_PORT=$ORACLE_SERVER2_LOCAL_PORT
    USER=$ORACLE_SERVER2_USER
    IP=$ORACLE_SERVER2_IP
else
    echo "Error: SERVER must be 1 or 2"
    exit 1
fi

# 退出时自动关闭 SSH 隧道
cleanup() {
    kill $SSH_PID 2>/dev/null
}
trap cleanup EXIT INT TERM

# 启动 SSH 隧道
ssh -i "$KEY" -D "$LOCAL_PORT" -N "$USER@$IP" &
SSH_PID=$!

# 等待隧道端口就绪（最多 15 秒）
echo "Waiting for tunnel..."
for i in $(seq 1 15); do
    if nc -z 127.0.0.1 "$LOCAL_PORT" 2>/dev/null; then
        echo "Tunnel ready"
        break
    fi
    if [[ $i -eq 15 ]]; then
        echo "Error: Tunnel failed to start"
        kill $SSH_PID 2>/dev/null
        exit 1
    fi
    sleep 1
done

# 下载文件
curl -L --proxy "socks5h://127.0.0.1:$LOCAL_PORT" -o "$DOWNLOAD_DIR/$FILE" "$URL"

# 关闭 SSH 隧道
kill $SSH_PID
