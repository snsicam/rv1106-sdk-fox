#!/bin/bash
# 用法: ./serial_hex.sh <设备> [波特率] [发送的十六进制字符串]
# 示例:
#   ./serial_hex.sh /dev/ttyS5 115200 "01 02 03 AB"   # 发送并显示接收
#   ./serial_hex.sh /dev/ttyS5 9600                    # 交互模式（手动输入hex发送）

DEV="$1"
BAUD="${2:-9600}"
SEND_HEX="$3"

if [ -z "$DEV" ]; then
    echo "Usage: $0 <device> [baudrate] [send_hex_string]"
    echo "Example: $0 /dev/ttyS5 115200 \"01 02 AB\""
    exit 1
fi

# 检查设备是否存在
if [ ! -c "$DEV" ]; then
    echo "Error: $DEV is not a character device."
    exit 1
fi

# 设置串口: 原始模式, 忽略控制字符, 8位数据, 1停止位, 无校验
stty -F "$DEV" "$BAUD" raw -echo -icanon -icrnl -isig 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure $DEV at $BAUD baud."
    exit 1
fi

# 打开串口读写文件描述符 (3号)
exec 3<> "$DEV"

# 清理函数: 关闭描述符, 杀死后台进程
CLEANUP() {
    kill "$READER_PID" 2>/dev/null
    exec 3>&-
    echo -e "\nCleanup done."
    exit
}
trap CLEANUP INT TERM EXIT

# 后台进程: 持续读取串口并转换为十六进制显示
reader() {
    while IFS= read -r -u 3 -t 0.5 -n 1 byte; do
        # 将每个字节转换为两位十六进制
        printf "%02X " "'$byte"
    done
    # 如果串口关闭或出错，退出循环
}

# 启动读取进程，并记录PID
reader &
READER_PID=$!

# 函数: 发送十六进制字符串
send_hex() {
    local hexstr="$1"
    # 移除空格，将每个字节转换为 \xHH 格式
    local binary=$(echo "$hexstr" | sed 's/[[:space:]]//g' | sed 's/\([0-9A-Fa-f]\{2\}\)/\\x\1/g')
    if [ -n "$binary" ]; then
        echo -ne "$binary" >&3
        echo -e "\n[Sent] $hexstr"
    fi
}

echo "=== Serial Monitor on $DEV at ${BAUD} baud ==="
echo "Receiving data (hex):"

if [ -n "$SEND_HEX" ]; then
    send_hex "$SEND_HEX"
    echo "--- Press Ctrl+C to exit ---"
    # 进入无限等待，让读取进程持续输出接收数据
    while true; do sleep 1; done
else
    echo "Interactive mode. Enter hex string to send (e.g. '01 02 AB'), or 'quit' to exit."
    while true; do
        echo -n "> "
        read -r input
        if [ "$input" = "quit" ] || [ "$input" = "exit" ]; then
            break
        fi
        if [[ "$input" =~ ^[0-9A-Fa-f\ ]+$ ]]; then
            send_hex "$input"
        else
            echo "Invalid hex string. Use format like '01 02 AB'."
        fi
    done
fi

# 脚本退出时会自动调用 CLEANUP