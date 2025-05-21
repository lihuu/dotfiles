#!/bin/bash

# 先放在这里，我们后面会安装kubernetes
sudo mkdir -p /etc/kubernetes/pki
sudo mkdir -p /etc/etcd/pki
sudo mkdir -p /etc/etcd/data
sudo cp ./ca.* /etc/kubernetes/pki
sudo cp ./etcd_server.* /etc/etcd/pki
sudo cp ./etcd_client.* /etc/etcd/pki
sudo chown -R etcd /etc/etcd/data
sudo chown -R etcd /etc/etcd/pki
sudo mv /etc/default/etcd /etc/default/etcd.bak
sudo ln -s /etc/etcd/etcd.conf /etc/default/etcd
