# 50-functions.zsh — 个人函数
#
# 通用工具函数 + KVM 虚拟机管理辅助（virsh 封装）。

# git 日志 + fzf 交互浏览
gitlog() {
  git log --graph --color=always \
    --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
    fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
    --bind "ctrl-m:execute:
  (grep -o '[a-f0-9]\{7\}' | head -1 |
    xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
  {}
  FZF-EOF"
}

# === KVM 虚拟机管理 ===
# 仅当 virsh 存在时定义相关函数（非 KVM 环境自动跳过）
if command -v virsh >/dev/null 2>&1; then

# 获取虚拟机 IP（通过 virsh domifaddr）
vmip() {
  local name="$1"
  sudo virsh domifaddr "$name" | awk '/ipv4/ {print $4}' | cut -d'/' -f1
}

# 连接虚拟机：vmssh <name> 或 vmssh <user>@<name> 或 vmssh <user>@<ip>
vmssh() {
  local input="$1"
  local user host ip

  if [[ "$input" == *"@"* ]]; then
    user="${input%@*}"
    host="${input#*@}"
  else
    user="ubuntu"
    host="$input"
  fi

  # 如果 host 是 IP 地址（纯数字加点）
  if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip="$host"
  else
    ip=$(sudo virsh domifaddr "$host" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
    if [[ -z "$ip" ]]; then
      echo "❌ 无法获取虚拟机 $host 的 IP 地址" >&2
      return 1
    fi
  fi

  echo "🔗 正在连接 $user@$ip ..."
  ssh "$user@$ip"
}

# 删除虚拟机及其磁盘
vmrm() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "⚠️ 请输入要删除的虚拟机名称，例如：vmrm ubuntu-01"
    return 1
  fi

  echo "⚠️ 即将删除虚拟机：$name"
  read "confirm?确认删除该虚拟机及其磁盘？[y/N]: "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "取消删除。"
    return 0
  fi

  # 获取磁盘路径
  local disk
  disk=$(sudo virsh domblklist "$name" | awk '/^vda/ {print $2}')

  echo "🔻 销毁虚拟机..."
  sudo virsh destroy "$name" 2>/dev/null

  echo "🧹 删除虚拟机定义..."
  sudo virsh undefine "$name" --remove-all-storage 2>/dev/null

  # 若磁盘未自动删除，尝试手动删除
  if [[ -n "$disk" && -f "$disk" ]]; then
    echo "🗑️ 删除磁盘文件 $disk"
    sudo rm -f "$disk"
  fi

  echo "✅ 虚拟机 $name 删除完成。"
}

# scp 到虚拟机（支持虚拟机名自动转 IP）
vmscp() {
  if [[ $# -lt 2 ]]; then
    echo "用法: vmscp <源> <目标>（支持虚拟机名自动转 IP）"
    return 1
  fi

  local args=("$@")
  local updated_args=()
  local ip

  for arg in "${args[@]}"; do
    if [[ "$arg" =~ ^([^@]+@)?([^:]+):(.+)$ ]]; then
      local user_part="${match[1]}"
      if [ -z "$user_part" ]; then
        user_part="ubuntu"
      fi
      local host="${match[2]}"
      local target_path="${match[3]}"

      # 如果 host 是 IP，直接使用
      if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        updated_args+=("$arg")
      else
        # 解析虚拟机名为 IP
        ip=$(sudo virsh domifaddr "$host" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
        if [[ -z "$ip" ]]; then
          echo "❌ 无法获取虚拟机 $host 的 IP 地址" >&2
          return 1
        fi
        updated_args+=("${user_part}@${ip}:$target_path")
      fi
    else
      updated_args+=("$arg")
    fi
  done

  echo "📤 执行: scp ${updated_args[*]}"
  scp "${updated_args[@]}"
}

# 更新 ~/.ssh/config 中某 Host 块的 IP/User/Port
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
' "$config" >"$temp.tmp" && mv "$temp.tmp" "$temp"
}

# 把虚拟机加入 ~/.ssh/config（支持更新已有块）
vm_add_ssh_config() {
  vmname="$1"
  user="${2:-ubuntu}"
  port="${3:-22}"

  ip=$(sudo virsh domifaddr "$vmname" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
  [[ -z "$ip" ]] && echo "❌ 无法获取 $vmname 的 IP 地址" && exit 1

  config="$HOME/.ssh/config"
  temp="$(mktemp)"
  if grep -q "^\s*Host\s\+$vmname\s*$" "$config" 2>/dev/null; then
    update_host_block "$vmname" "$user" "$ip" "$port" "$temp" "$temp"
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
}

# 从 ~/.ssh/config 提取某 Host 的 HostName
get_hostname_from_ssh_config() {
  local host="$1"
  awk -v host="$host" '
    $1 == "Host" && $2 == host { in_block = 1; next }
    in_block && $1 == "HostName" { print $2; exit }
    in_block && $1 == "Host" { in_block = 0 }
  ' ~/.ssh/config
}

fi  # command -v virsh
