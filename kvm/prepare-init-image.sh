#!/bin/sh
wget -P ~/Downloads https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# 创建基础目录
mkdir -p ~/kvm/ubuntu-vms
cd ~/kvm/ubuntu-vms

# 使用的 cloud image
cp ~/Downloads/jammy-server-cloudimg-amd64.img base.img

# 用户名、公钥等自定义内容（示例）
cat >user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - ssh-rsa <你的系统的的公钥，使用ssh-keygen -t rsa 命令创建>
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "ubuntu"

ssh_pwauth: true

runcmd:
  - systemctl enable serial-getty@ttyS0.service
  - systemctl start serial-getty@ttyS0.service
  - sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0 /' /etc/default/grub
  - update-grub
EOF
