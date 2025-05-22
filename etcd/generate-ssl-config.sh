#!/bin/bash
# 文件保存为generate-ssl-config.sh
#
get_hostname_from_ssh_config() {
  local host="$1"
  awk -v host="$host" '
    $1 == "Host" && $2 == host { in_block = 1; next }
    in_block && $1 == "HostName" { print $2; exit }
    in_block && $1 == "Host" { in_block = 0 }
  ' ~/.ssh/config
}

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
    ip=$(get_hostname_from_ssh_config $item)
    echo "IP.$count = $ip" >>$item1/pki/etcd_ssl.cnf
    ((count++))
  done

done
