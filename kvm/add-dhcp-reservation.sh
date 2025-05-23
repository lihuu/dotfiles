#!/bin/bash

# 示例用法: ./add-dhcp-reservation.sh my-vm

VM_NAME="$1"
NETWORK_NAME="default"

if [[ -z "$VM_NAME" ]]; then
  echo "用法: $0 <虚拟机名称>"
  exit 1
fi

# 获取虚拟机的 MAC 地址
MAC=$(sudo virsh domiflist "$VM_NAME" | awk '/network/ {print $5}')
STATIC_IP=$(sudo virsh domifaddr "$VM_NAME" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)

if [[ -z "$MAC" ]]; then
  echo "未能获取虚拟机 $VM_NAME 的 MAC 地址"
  exit 2
fi

# 检查是否已存在该 MAC 的静态租约
EXISTS=$(sudo virsh net-dumpxml "$NETWORK_NAME" | grep -i "$MAC")
if [[ -n "$EXISTS" ]]; then
  echo "已存在租约，跳过添加。MAC: $MAC"
  exit 0
fi

echo "添加静态租约: $VM_NAME ($MAC -> $STATIC_IP)"

# 打印信息
echo "虚拟机: $VM_NAME"
echo "MAC地址: $MAC"
echo "分配静态IP: $STATIC_IP"

# 注入静态租约
sudo virsh net-update "$NETWORK_NAME" add-last ip-dhcp-host "<host mac='$MAC' name='$VM_NAME' ip='$STATIC_IP'/>" --live --config

if [[ $? -eq 0 ]]; then
  echo "成功添加静态租约。"
else
  echo "添加失败。"
  exit 3
fi
