#!/bin/bash
# 用法: ./uart_main_init.sh <串口设备>
# 示例: ./uart_main_init.sh /dev/ttyS3

DEV="$1"
if [ -z "$DEV" ]; then
    echo "Usage: $0 <serial_device>"
    exit 1
fi

if [ ! -c "$DEV" ]; then
    echo "Error: $DEV is not a character device."
    exit 1
fi

# 配置串口函数
config_serial() {
    local baud=$1
    stty -F "$DEV" "$baud" raw -echo -icanon -icrnl -isig 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure $DEV at $baud baud."
        exit 1
    fi
}

# 发送十六进制字符串
send_hex() {
    local hexstr="$1"
    local binary=$(echo "$hexstr" | sed 's/[[:space:]]//g' | sed 's/\([0-9A-Fa-f]\{2\}\)/\\x\1/g')
    if [ -n "$binary" ]; then
        printf "$binary" > "$DEV"
        echo "[Sent] $hexstr"
    else
        echo "Error: Invalid hex string."
        exit 1
    fi
}

# 接收一包数据：利用 stty min/time + dd 实现超时
receive_packet() {
    local timeout_sec=$1
    local timeout_tenths=$((timeout_sec * 10))

    # 设置驱动：至少读 1 字节，超时 timeout_tenths 个 0.1 秒
    stty -F "$DEV" min 1 time "$timeout_tenths"

    # 读取第一个字节（会阻塞直到有数据或超时）
    local first_byte=$(dd if="$DEV" bs=1 count=1 2>/dev/null)
    if [ -z "$first_byte" ]; then
        echo "(timeout, 无数据)"
        return
    fi

    # 读取剩余数据：设置更短超时（0.3 秒）来收集后续字节
    stty -F "$DEV" min 0 time 3
    local rest=$(dd if="$DEV" bs=1024 count=1 2>/dev/null)

    # 恢复原始 min/time（可选，因后续会重新配置波特率，所以不恢复也没问题）
    stty -F "$DEV" min 1 time 0

    local data="$first_byte$rest"
    hex=$(echo -n "$data" | xxd -p -c 0 | sed 's/\(..\)/\1 /g' | tr 'a-f' 'A-F')
    byte_count=$(echo -n "$data" | wc -c)
    echo "$hex (共 $byte_count 字节)"
}

# 步骤1: 配置 9600 并发送数据
config_serial 9600
echo "Configured $DEV at 9600 baud"
send_hex "aa 55 50 00 00 00 00 00 00 00 af"

# 步骤2: 在 9600 下接收 1 包数据（超时 20 秒）
echo "Receiving 1 packet at 9600 baud (timeout 20s)..."
packet1=$(receive_packet 20)
echo "Packet 1: $packet1"

# 步骤3: 切换波特率到 230400
config_serial 230400
echo "Switched to 230400 baud"

# 步骤4: 在 230400 下接收 2 包数据（每包超时 20 秒）
for i in 1 2; do
    echo "Receiving packet $((i+1)) at 230400 baud (timeout 20s)..."
    packet=$(receive_packet 20)
    echo "Packet $((i+1)): $packet"
done

# 显示当前波特率（确认）
stty -F "$DEV" speed
echo "Done. Exiting (serial settings preserved at 230400 baud)."