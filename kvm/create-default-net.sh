#!/bin/sh
# 如果default 网络不存在，使用这个脚本创建
cat >default-net.xml <<EOF
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.100' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define default-net.xml
virsh net-start default
virsh net-autostart default
