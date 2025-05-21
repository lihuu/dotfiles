#!/bin/bash
# 文件保存为generate-etcd-conf.sh
generate() {
  local name="$1"
  local ip=$(sudo virsh domifaddr "$name" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
  cat >"$name.etcd.conf" <<EOF
ETCD_NAME=$name
ETCD_DATA_DIR=/etc/etcd/data
ETCD_CERT_FILE=/etc/etcd/pki/etcd_server.crt

ETCD_KEY_FILE=/etc/etcd/pki/etcd_server.key
ETCD_TRUSTED_CA_FILE=/etc/kubernetes/pki/ca.crt
ETCD_CLIENT_CERT_AUTH=true
ETCD_LISTEN_CLIENT_URLS=https://$ip:2379
ETCD_ADVERTISE_CLIENT_URLS=https://$ip:2379

ETCD_PEER_CERT_FILE=/etc/etcd/pki/etcd_server.crt
ETCD_PEER_KEY_FILE=/etc/etcd/pki/etcd_server.key
ETCD_PEER_TRUSTED_CA_FILE=/etc/kubernetes/pki/ca.crt
ETCD_LISTEN_PEER_URLS=https://$ip:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://$ip:2380

ETCD_INITIAL_CLUSTER_TOKEN=etca-cluster
ETCD_INITIAL_CLUSTER_STATE=new
EOF
}

# 拆分参数字符串为数组
IFS=',' read -ra items <<<"$1"

etcdCluesters=""

# 遍历数组并调用函数
for item in "${items[@]}"; do
  generate $item
  ip=$(sudo virsh domifaddr "$item" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
  if [ -z "$etcdCluesters" ]; then
    etcdCluesters="$item=https://$ip:2380"
  else
    etcdCluesters="$etcdCluesters,$item=https://$ip:2380"
  fi
done

for item in "${items[@]}"; do
  echo "ETCD_INITIAL_CLUSTER=\"$etcdCluesters\"" >>"$item.etcd.conf"
done
