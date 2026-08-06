#!/bin/bash
# 用法: ./serial_send_recv_diff_baud.sh <设备> <发送波特率> <接收波特率> <发送的十六进制字符串>
# 示例: ./serial_send_recv_diff_baud.sh /dev/ttyS5 115200 9600 "01 02 AB"
# 功能: 以发送波特率发送hex数据 -> 切换波特率 -> 接收5包hex数据（每包超时2秒）-> 显示 -> 退出

if [ $# -ne 4 ]; then
    echo "Usage: $0 <device> <tx_baudrate> <rx_baudrate> <send_hex_string>"
    echo "Example: $0 /dev/ttyS5 115200 9600 \"01 02 AB\""
    exit 1
fi

DEV="$1"
TX_BAUD="$2"
RX_BAUD="$3"
SEND_HEX="$4"

# 检查设备是否存在
if [ ! -c "$DEV" ]; then
    echo "Error: $DEV is not a character device."
    exit 1
fi

# 保存原始串口设置
ORIG_STTY=$(stty -g -F "$DEV" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Warning: Could not get original stty settings."
fi

# 退出时恢复串口设置并关闭文件描述符
cleanup() {
    if [ -n "$ORIG_STTY" ]; then
        stty -F "$DEV" "$ORIG_STTY" 2>/dev/null
    fi
    exec 3<&- 3>&- 2>/dev/null
    echo -e "\nCleanup done."
    exit
}
trap cleanup INT TERM EXIT

# 通用串口配置函数: 设置波特率并启用原始模式
configure_serial() {
    local baud=$1
    stty -F "$DEV" "$baud" raw -echo -icanon -icrnl -isig 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure $DEV at $baud baud."
        exit 1
    fi
}

# 打开串口文件描述符（读写）
exec 3<> "$DEV"

# 步骤1: 以发送波特率配置串口
configure_serial "$TX_BAUD"
echo "Configured $DEV at $TX_BAUD baud for sending."

# 发送前清空输入缓冲区（丢弃残留数据）
dd if="$DEV" bs=1024 count=1 2>/dev/null | cat > /dev/null

# 发送十六进制数据
# 将 "01 02 AB" 格式转换为二进制字节
BINARY=$(echo "$SEND_HEX" | sed 's/[[:space:]]//g' | sed 's/\([0-9A-Fa-f]\{2\}\)/\\x\1/g')
if [ -z "$BINARY" ]; then
    echo "Error: Invalid hex string."
    exit 1
fi
echo -ne "$BINARY" >&3
echo "[Sent] $SEND_HEX (at ${TX_BAUD} baud)"

# 短暂延时，确保数据发送完成
sleep 0.1

# 步骤2: 切换为接收波特率
configure_serial "$RX_BAUD"
echo "Switched to $RX_BAUD baud for receiving."

# 再次清空输入缓冲区，避免旧数据干扰
dd if="$DEV" bs=1024 count=1 2>/dev/null | cat > /dev/null

echo "Waiting to receive 5 packets (timeout 2s each)..."

# 接收函数: 使用 timeout 和 dd 读取，每包最多1024字节
receive_packet() {
    local pkt_num=$1
    local data=$(timeout 2 dd if="$DEV" bs=1024 count=1 2>/dev/null)
    if [ -z "$data" ]; then
        echo "Packet $pkt_num: (timeout, no data)"
    else
        # 将二进制数据转换为十六进制字符串（空格分隔，大写）
        hex_data=$(echo -n "$data" | xxd -p -c 0 | sed 's/\(..\)/\1 /g' | tr 'a-f' 'A-F')
        echo "Packet $pkt_num: $hex_data"
    fi
}

# 循环接收 5 个数据包
for i in $(seq 1 5); do
    receive_packet "$i"
done

echo "Done. Exiting."