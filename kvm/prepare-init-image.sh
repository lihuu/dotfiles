#!/bin/sh

if [ -f ~/Downloads/noble-server-cloudimg-amd64.img ]; then
  echo "file Exist, will not download."
else
  wget -P ~/Downloads https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
fi

# 创建基础目录
mkdir -p ~/kvm/ubuntu-vms
cp ./create-vm.sh ~/kvm/ubuntu-vms
cp ./create-single-vm.sh ~/kvm/ubuntu-vms
cp ./add-vm-ssh-config.sh ~/kvm/ubuntu-vms
cp ./add-all-vm-ssh-config.sh ~/kvm/ubuntu-vms
cd ~/kvm/ubuntu-vms

# 使用的 cloud image
cp ~/Downloads/jammy-server-cloudimg-amd64.img base.img

authorized_key="ssh-rsa <你的系统的的公钥，使用ssh-keygen -t rsa 命令创建>"

if [ -f ~/.ssh/id_rsa.pub ]; then
  authorized_key=$(cat ~/.ssh/id_rsa.pub)
fi

# 用户名、公钥等自定义内容（示例）
cat >user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - ${authorized_key}
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
