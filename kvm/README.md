## 使用说名

| 脚本                       | 说名                                                          | 使用例子                               |
| -------------------------- | ------------------------------------------------------------- | -------------------------------------- |
| add-all-vm-ssh-config.sh   | 把所有的虚拟机ipHostname，User , Port添加到 ~/.ssh/config中   |                                        |
| add-vm-ssh-config.sh       | 把指定的虚拟机的HostName，User，Port添加到~/.ssh/config文件中 | ./add-vm-ssh-config.sh ubuntu-01       |
| add-dhcp-reservation.sh    | 把指定虚拟机的mac地址和ip地址，添加到虚拟网络的静态租约分配中 | ./add-dhcp-reservation.sh ubuntu-01    |
| remove-dhcp-reservation.sh | 移除静态租约                                                  | ./remove-dhcp-reservation.sh ubuntu-01 |
| create-single-vm.sh        | 创建单个虚拟机                                                | ./create-single-vm.sh ubuntu-01        |
| create-vm.sh               | 创建多个虚拟机                                                | ./create-vm.sh                         |
| prepare-init-image.sh      | 准备初始化镜像，自动下载镜像，创建工作目录，初始化配置        | ./prepare-init-image.sh                |
| create-default-net.sh      | 创建默认虚拟网络                                              |                                        |
