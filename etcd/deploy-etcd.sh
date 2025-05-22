#!/bin/bash

host="$1"

if [ -z "$host" ]; then
  echo "No host provided, Usage: ./deploy-etcd.sh <host>"
fi

scp ./etcd-config.tar.gz $host:/home/ubuntu
ssh $host "sudo apt update && sudo apt install etcd -y&&tar -xvf etcd-config.tar.gz && sudo etcd/config-etcd.sh"
