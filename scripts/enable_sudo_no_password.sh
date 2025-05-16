#!/bin/bash

# 检查是否传入用户名
if [ -z "$1" ]; then
  echo "用法: $0 <用户名>"
  exit 1
fi

USERNAME="$1"
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

# 创建 sudoers.d 文件
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" >/dev/null

# 设置权限为 440
sudo chmod 440 "$SUDOERS_FILE"

echo "已为用户 '$USERNAME' 设置 sudo 免密。"
