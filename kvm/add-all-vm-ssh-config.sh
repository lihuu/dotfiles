#!/bin/bash

vm_list=$(sudo virsh list --state-running | awk 'NR > 2 { print $2 }')

echo $vm_list

for vm in $vm_list; do
  ./add-vm-ssh-config.sh $vm
done
