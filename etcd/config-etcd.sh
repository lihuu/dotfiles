#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 先放在这里，我们后面会安装kubernetes
sudo mkdir -p /etc/kubernetes/pki
sudo mkdir -p /etc/etcd/pki
sudo mkdir -p /etc/etcd/data
sudo cp $SCRIPT_DIR/ca.* /etc/kubernetes/pki
sudo cp $SCRIPT_DIR/$(hostname)/etcd_server.* /etc/etcd/pki
sudo cp $SCRIPT_DIR/$(hostname)/etcd_client.* /etc/etcd/pki
sudo chown -R etcd /etc/etcd/data
sudo chown -R etcd /etc/etcd/pki
sudo chmod +r /etc/etcd/pki/*
sudo mv /etc/default/etcd /etc/default/etcd.bak
sudo cp $SCRIPT_DIR/$(hostname)/etcd.conf /etc/etcd/etcd.conf
sudo ln -s /etc/etcd/etcd.conf /etc/default/etcd
