#!/bin/sh
name="$1"
if [ -z "$name" ]; then
  echo "No vm name provided, Usage: ./create-single-vm.sh <name>"
  exit
fi

disk="$name.img"
seed="$name-seed.iso"

# 创建磁盘（基于 cloud image）
qemu-img create -f qcow2 -b base.img -F qcow2 $disk 20G

# 创建 cloud-init ISO（指定 hostname）
cat >meta-data <<EOF
instance-id: $name
local-hostname: $name
EOF

cloud-localds $seed user-data meta-data

# 创建虚拟机
virt-install \
  --name $name \
  --ram 4096 \
  --vcpus 2 \
  --os-variant ubuntu22.04 \
  --disk path=$disk,format=qcow2 \
  --disk path=$seed,device=cdrom \
  --network network=default,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole
