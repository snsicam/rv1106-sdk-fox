#!/bin/sh
#
# Start camera stream after boot (manually trigger the mdev event)
#

# 检查是否有 swap
free -m
# 创建 256MB swap 文件（如果 /root 有空间）
dd if=/dev/zero of=/root/swapfile bs=1M count=512
chmod 600 /root/swapfile
mkswap /root/swapfile
swapon /root/swapfile
# 添加到 /etc/fstab 以持久化
echo "/root/swapfile none swap sw 0 0" >> /etc/fstab