#!/bin/sh
# 用法: ./monitor_proc.sh <进程名> [扫描间隔(秒)]
# 示例: ./monitor_proc.sh test 0.1

if [ $# -lt 1 ]; then
    echo "Usage: $0 <process_name> [interval_seconds]"
    exit 1
fi

PROC_NAME="$1"
INTERVAL="${2:-0.1}"               # 扫描间隔，默认0.1秒
TRACKED_FILE="/tmp/monitor_proc_tracked.$$"

> "$TRACKED_FILE"
trap 'rm -f "$TRACKED_FILE"; exit' INT TERM EXIT

echo "=== Monitoring process(es) named '$PROC_NAME' (scan every ${INTERVAL}s) ==="
echo "Press Ctrl+C to stop."

is_tracked() { grep -qx "$1" "$TRACKED_FILE" 2>/dev/null; }
mark_tracked() { echo "$1" >> "$TRACKED_FILE"; }
remove_tracked() {
    # 从 tracked 文件中删除指定 PID
    grep -v "^$1$" "$TRACKED_FILE" > "$TRACKED_FILE.tmp"
    mv "$TRACKED_FILE.tmp" "$TRACKED_FILE"
}

# 清理失效的跟踪记录（进程已退出或名称改变）
cleanup_tracked() {
    local pid_to_remove=""
    for pid in $(cat "$TRACKED_FILE" 2>/dev/null); do
        # 检查进程是否存在且进程名是否匹配
        if [ ! -d "/proc/$pid" ] || [ "$(cat /proc/$pid/comm 2>/dev/null)" != "$PROC_NAME" ]; then
            pid_to_remove="$pid_to_remove $pid"
        fi
    done
    for pid in $pid_to_remove; do
        remove_tracked "$pid"
    done
}

# 监控单个 PID：启动 strace 并输出格式化数据
monitor_pid() {
    pid=$1
    echo "Started monitoring PID $pid"
    # strace: -f 跟踪子进程, -e trace=read,write, -s 1024 显示完整数据, -xx 输出十六进制
    strace -f -p "$pid" -e trace=read,write -s 1024 -xx 2>&1 | \
    awk -v pid="$pid" '
    {
        # 提取实际的线程/进程 ID (形如 [pid 12345])
        if (match($0, /^\[pid ([0-9]+)\]/)) {
            actual_pid = substr($0, RSTART+5, RLENGTH-6);
        } else {
            actual_pid = pid;
        }

        # 判断是 read 还是 write
        if (index($0, "read(")) {
            op = "RECV";
        } else if (index($0, "write(")) {
            op = "SEND";
        } else {
            next;
        }

        # 提取文件描述符 (例如 read(3, ...) -> 3)
        if (match($0, /[a-z]+\(([0-9]+),/)) {
            fd = substr($0, RSTART+RLENGTH-2, 1);
        } else {
            fd = "?";
        }

        # 提取双引号内的十六进制转义数据 (由 strace -xx 产生)
        if (match($0, /"([^"]*)"/)) {
            hexdata = substr($0, RSTART+1, RLENGTH-2);
            gsub(/\\x/, "", hexdata);
            # 每两个字符一组，用空格分隔
            gsub(/../, "& ", hexdata);
            sub(/ $/, "", hexdata);
            printf "[%s][PID %s] fd=%s: %s\n", op, actual_pid, fd, hexdata;
            fflush();
        }
    }' &
}

while true; do
    # 清理失效的跟踪记录（防止 PID 复用导致漏跟踪）
    cleanup_tracked

    # 扫描 /proc 下所有进程的 comm 文件，获取匹配进程名的 PID
    for pid in $(ls /proc | grep -E '^[0-9]+$'); do
        comm_file="/proc/$pid/comm"
        if [ -f "$comm_file" ] && [ "$(cat "$comm_file" 2>/dev/null)" = "$PROC_NAME" ]; then
            if ! is_tracked "$pid"; then
                mark_tracked "$pid"
                monitor_pid "$pid"
            fi
        fi
    done

    sleep "$INTERVAL"
done