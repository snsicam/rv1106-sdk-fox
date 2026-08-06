#!/bin/bash
# 用法: ./monitor_ready.sh <串口设备> [匹配字符串] [超时秒数]
# 示例: ./monitor_ready.sh /dev/ttyS4 "Ready." 3

DEV="$1"
MATCH="${2:-Ready.}"
TIMEOUT="${3:-3}"           # 每包接收超时（秒）
BAUD1=115200
BAUD2=230400
WAIT_AFTER_SEND=0.2         # 发送后等待时间（秒）

if [ -z "$DEV" ]; then
    echo "Usage: $0 <device> [match_string] [timeout_seconds]"
    exit 1
fi

if [ ! -c "$DEV" ]; then
    echo "Error: $DEV is not a character device."
    exit 1
fi

ORIG_STTY=$(stty -g -F "$DEV" 2>/dev/null)
cleanup() {
    [ -n "$ORIG_STTY" ] && stty -F "$DEV" "$ORIG_STTY" 2>/dev/null
    exec 3<&- 3>&- 2>/dev/null
    echo -e "\nCleanup done."
    exit
}
trap cleanup INT TERM EXIT

# 配置串口
stty -F "$DEV" "$BAUD1" raw -echo -icanon -icrnl -isig
exec 3<> "$DEV"

echo "Listening on $DEV at $BAUD1 for pattern: '$MATCH' (case-insensitive)"
echo "--- Displaying all received data (press Ctrl+C to abort) ---"

# 逐行读取并显示，匹配模式
found=0
while IFS= read -r -u 3 line; do
    hex_line=$(echo -n "$line" | xxd -p | sed 's/\(..\)/\1 /g' | tr 'a-f' 'A-F')
    echo "[RECV] $line"
    echo "       HEX: $hex_line"
    
    if [[ "$line" =~ ${MATCH,,} ]] || [[ "${line,,}" =~ ${MATCH,,} ]]; then
        echo ">>> Pattern matched! Sending 0x41 (ASCII 'A') <<<"
        printf '\x41' >&3
        echo ">>> Sent 0x41, waiting ${WAIT_AFTER_SEND}s for device to respond <<<"
        sleep "$WAIT_AFTER_SEND"
        found=1
        break
    fi
done

if [ $found -eq 0 ]; then
    echo "Pattern not found. Exiting."
    exit 1
fi

# 清空输入缓冲区，丢弃可能残留的数据
dd if="$DEV" bs=1024 count=1 2>/dev/null | cat > /dev/null

# 接收第一包数据（115200）
echo "Receiving packet 1 at $BAUD1 baud (timeout ${TIMEOUT}s)..."
packet1=$(timeout "$TIMEOUT" dd if="$DEV" bs=1024 count=1 2>/dev/null)
if [ -n "$packet1" ]; then
    hex1=$(echo -n "$packet1" | xxd -p -c 0 | sed 's/\(..\)/\1 /g' | tr 'a-f' 'A-F')
    echo "Packet 1: $hex1"
else
    echo "Packet 1: (timeout, no data)"
fi

# 切换波特率
stty -F "$DEV" "$BAUD2" raw -echo -icanon -icrnl -isig
echo "Switched to $BAUD2 baud"

# 再次清空缓冲区
dd if="$DEV" bs=1024 count=1 2>/dev/null | cat > /dev/null

# 接收第二包数据
echo "Receiving packet 2 at $BAUD2 baud (timeout ${TIMEOUT}s)..."
packet2=$(timeout "$TIMEOUT" dd if="$DEV" bs=1024 count=1 2>/dev/null)
if [ -n "$packet2" ]; then
    hex2=$(echo -n "$packet2" | xxd -p -c 0 | sed 's/\(..\)/\1 /g' | tr 'a-f' 'A-F')
    echo "Packet 2: $hex2"
else
    echo "Packet 2: (timeout, no data)"
fi

echo "Done. Exiting."