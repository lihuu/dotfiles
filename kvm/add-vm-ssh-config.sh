#!/bin/bash

vmname="$1"
user="${2:-ubuntu}"
port="${3:-22}"

ip=$(sudo virsh domifaddr "$vmname" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
[[ -z "$ip" ]] && echo "❌ 无法获取 $vmname 的 IP 地址" && exit 1

config="$HOME/.ssh/config"
temp="$(mktemp)"

if grep -q "^\s*Host\s\+$vmname\s*$" "$config" 2>/dev/null; then
  awk -v host="$vmname" -v user="$user" -v ip="$ip" -v port="$port" '
    $1 == "Host" && $2 == host { print; inhost=1; next }
    inhost && $1 == "Host" { inhost=0 }
    inhost && $1 == "HostName" { print "  HostName " ip; next }
    inhost && $1 == "User"     { print "  User " user; next }
    inhost && $1 == "Port"     { print "  Port " port; next }
    { print }
    END {
      if (inhost) {
        print "  HostName " ip;
        print "  User " user;
        print "  Port " port;
      }
    }
  ' "$config" >"$temp" && mv "$temp" "$config"
else
  {
    cat "$config" 2>/dev/null
    echo -e "\nHost $vmname"
    echo "  HostName $ip"
    echo "  User $user"
    echo "  Port $port"
  } >"$temp" && mv "$temp" "$config"
fi

echo "✅ SSH 配置已更新：$vmname -> $ip"
