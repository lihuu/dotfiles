#!/bin/bash
# 文件保存为generate-ssl-config.sh

IFS=',' read -ra items <<<"$1"

for item1 in "${items[@]}"; do
  mkdir -p $item1/pki
  cat >$item1/pki/etcd_ssl.cnf <<EOF
[ req ]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[ req_distinguished_name ]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ alt_names ]
EOF
  count=1
  for item in "${items[@]}"; do
    ip=$(sudo virsh domifaddr "$item" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
    echo "IP.$count = $ip" >>$item1/pki/etcd_ssl.cnf
    ((count++))
  done

done
