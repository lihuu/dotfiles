#!/bin/sh
for i in 04 05 06; do
  name="ubuntu-$i"
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
    --ram 2048 \
    --vcpus 2 \
    --os-type linux \
    --os-variant ubuntu22.04 \
    --disk path=$disk,format=qcow2 \
    --disk path=$seed,device=cdrom \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole
done
