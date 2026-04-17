#!/usr/bin/env bash
set -euo pipefail

echo ">>> Apply low-IO power profile (AC + Battery)"

# 1. 关闭休眠写磁盘
sudo pmset -a hibernatemode 0

# 2. 禁止进入 standby（避免触发深度休眠）
sudo pmset -a standby 0

# 3. 禁止 autopoweroff（进一步避免深度状态）
sudo pmset -a autopoweroff 0

# 4. 关闭 Power Nap（避免睡眠期间后台 IO / 网络 / 索引）
sudo pmset -a powernap 0

# 5. 插电时不自动睡眠（你长期插电）
sudo pmset -c sleep 0

# 6. 电池模式：保留自动睡眠（防止忘记关机）
sudo pmset -b sleep 30

# 7. 关闭 TCP keepalive（避免睡眠期间网络唤醒）
sudo pmset -a tcpkeepalive 0

# 8. 显示器正常休眠（不影响体验）
sudo pmset -a displaysleep 10

echo ">>> Remove existing sleepimage (if exists)"
sudo rm -f /var/vm/sleepimage || true

echo ">>> Current pmset:"
pmset -g

echo ">>> Done"
