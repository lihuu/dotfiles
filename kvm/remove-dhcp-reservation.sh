#!/bin/bash

VM_NAME="$1"
NETWORK_NAME="default"

if [[ -z "$VM_NAME" ]]; then
  echo "用法: $0 <虚拟机名称>"
  exit 1
fi

MAC=$(sudo virsh dumpxml "$VM_NAME" | grep "mac address" | head -n1 | cut -d"'" -f2)
if [[ -z "$MAC" ]]; then
  echo "无法找到虚拟机 $VM_NAME 的 MAC 地址"
  exit 2
fi

# 仅在已存在时尝试删除
EXISTS=$(sudo virsh net-dumpxml "$NETWORK_NAME" | grep -i "$MAC" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print}')
if [[ -z "$EXISTS" ]]; then
  echo "未找到对应租约，跳过删除"
  exit 0
fi

echo "正在删除静态租约: $MAC"

sudo virsh net-update "$NETWORK_NAME" delete ip-dhcp-host "$EXISTS" --live --config

if [[ $? -eq 0 ]]; then
  echo "✅ 成功删除租约"
else
  echo "❌ 删除失败（可能是 IP 不一致，可手动处理）"
fi
