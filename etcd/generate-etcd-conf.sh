#!/bin/bash
# 文件保存为generate-etcd-conf.sh
#
get_hostname_from_ssh_config() {
  local host="$1"
  awk -v host="$host" '
    $1 == "Host" && $2 == host { in_block = 1; next }
    in_block && $1 == "HostName" { print $2; exit }
    in_block && $1 == "Host" { in_block = 0 }
  ' ~/.ssh/config
}
generate() {
  local name="$1"
  local ip=$(get_hostname_from_ssh_config $name)
  cat >"$name/etcd.conf" <<EOF
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
etcdEnddpoints=""

# 遍历数组并调用函数
for item in "${items[@]}"; do
  mkdir -p $item
  generate $item
  ip=$(get_hostname_from_ssh_config $item)
  if [ -z "$etcdCluesters" ]; then
    etcdCluesters="$item=https://$ip:2380"
    etcdEnddpoints="https://$ip:2379"
  else
    etcdCluesters="$etcdCluesters,$item=https://$ip:2380"
    etcdEnddpoints="$etcdEnddpoints,https://$ip:2379"
  fi
done

for item in "${items[@]}"; do
  echo "ETCD_INITIAL_CLUSTER=\"$etcdCluesters\"" >>"$item/etcd.conf"
  cat >"$item/etcdctl.env" <<EOF

export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS="$etcdEnddpoints"
export ETCDCTL_CACERT="/etc/kubernetes/pki/ca.crt"
export ETCDCTL_CERT="/etc/etcd/pki/etcd_client.crt"
export ETCDCTL_KEY="/etc/etcd/pki/etcd_client.key"

EOF
done
