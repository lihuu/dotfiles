#!/bin/bash

vmname="$1"
user="${2:-ubuntu}"
port="${3:-22}"

ip=$(sudo virsh domifaddr "$vmname" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
[[ -z "$ip" ]] && echo "❌ 无法获取 $vmname 的 IP 地址" && exit 1

echo "Host $vmname"
echo "HostName $ip"
echo "User $user"
echo "Port $port"

config="$HOME/.ssh/config"
temp="$(mktemp)"
echo "Use tmp file: $temp"

# 函数：更新已有的 Host 配置块（支持最后一项）
update_host_block() {
  local host="$1" user="$2" ip="$3" port="$4" config="$5" temp="$6"

  awk -v host="$host" -v user="$user" -v ip="$ip" -v port="$port" '
    BEGIN { inhost = 0 }
    $1 == "Host" && $2 == host {
      print; inhost = 1; next
    }
    $1 == "Host" && inhost == 1 {
      print "  HostName " ip
      print "  User " user
      print "  Port " port
      inhost = 0
    }
    inhost == 1 && ($1 == "HostName" || $1 == "User" || $1 == "Port") {
      next
    }
    { print }
    END {
      if (inhost == 1) {
        print "  HostName " ip
        print "  User " user
        print "  Port " port
      }
    }
  ' "$config" >"$temp.tmp" && mv "$temp.tmp" "$config"
}

if grep -q "^\s*Host\s\+$vmname\s*$" "$config" 2>/dev/null; then
  update_host_block "$vmname" "$user" "$ip" "$port" "$config" "$temp"
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
