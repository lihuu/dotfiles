#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f $SCRIPT_DIR/ca.key ]; then
  echo "✅ 已存在 ca.key，跳过 CA 生成。"
else
  echo "🔧 生成新的 CA 证书..."
  openssl genrsa -out ca.key 2048
  openssl req -x509 -new -nodes -key $SCRIPT_DIR/ca.key -subj "/CN=etcd-peer" -days 36500 -out $SCRIPT_DIR/ca.crt
fi

# 拆分参数字符串为数组
if [ -z "$1" ]; then
  echo "没有指定服务器，将在当前目录生成证书"
  openssl genrsa -out $SCRIPT_DIR/etcd_server.key 2048
  openssl req -new -key $SCRIPT_DIR/etcd_server.key -config $SCRIPT_DIR/etcd_ssl.cnf -subj "/CN=etcd-server" -out $SCRIPT_DIR/etcd_server.csr
  openssl x509 -req -in $SCRIPT_DIR/etcd_server.csr -CA $SCRIPT_DIR/ca.crt -CAkey $SCRIPT_DIR/ca.key -CAcreateserial -days 36500 -extensions v3_req -extfile $SCRIPT_DIR/etcd_ssl.cnf -out $SCRIPT_DIR/etcd_server.crt

  openssl genrsa -out $SCRIPT_DIR/etcd_client.key 2048
  openssl req -new -key $SCRIPT_DIR/etcd_client.key -config $SCRIPT_DIR/etcd_ssl.cnf -subj "/CN=etcd-client" -out $SCRIPT_DIR/etcd_client.csr
  openssl x509 -req -in $SCRIPT_DIR/etcd_client.csr -CA $SCRIPT_DIR/ca.crt -CAkey $SCRIPT_DIR/ca.key -CAcreateserial -days 36500 -extensions v3_req -extfile $SCRIPT_DIR/etcd_ssl.cnf -out $SCRIPT_DIR/etcd_client.crt
else
  IFS=',' read -ra items <<<"$1"

  for item in "${items[@]}"; do
    targetDir=$SCRIPT_DIR/$item/pki
    mkdir -p $targetDir
    openssl genrsa -out $targetDir/etcd_server.key 2048
    openssl req -new -key $targetDir/etcd_server.key -config $targetDir/etcd_ssl.cnf -subj "/CN=etcd-server" -out $targetDir/etcd_server.csr
    openssl x509 -req -in $targetDir/etcd_server.csr -CA $SCRIPT_DIR/ca.crt -CAkey $SCRIPT_DIR/ca.key -CAcreateserial -days 36500 -extensions v3_req -extfile $targetDir/etcd_ssl.cnf -out $targetDir/etcd_server.crt

    openssl genrsa -out $targetDir/etcd_client.key 2048
    openssl req -new -key $targetDir/etcd_client.key -config $targetDir/etcd_ssl.cnf -subj "/CN=etcd-client" -out $targetDir/etcd_client.csr
    openssl x509 -req -in $targetDir/etcd_client.csr -CA $SCRIPT_DIR/ca.crt -CAkey $SCRIPT_DIR/ca.key -CAcreateserial -days 36500 -extensions v3_req -extfile $targetDir/etcd_ssl.cnf -out $targetDir/etcd_client.crt
  done
fi
