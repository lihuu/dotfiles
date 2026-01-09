#!/bin/bash

# =================================================================
# 🛡️ 系统安全清理助手 (Safe Cleanup Script)
# =================================================================

# 确保以 root 权限运行核心清理部分
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31m❌ 错误: 请使用 sudo 运行此脚本以确保有权限清理系统日志和 Snap\033[0m"
  exit 1
fi

# --- 通用安全删除函数 ---
# 参数1: 描述信息
# 参数2: 要执行的完整命令字符串
# 参数3: 关键路径变量 (用于判空校验)
safe_interactive_rm() {
  local desc=$1
  local cmd=$2
  local check_path=$3

  # 1. 基础安全性校验
  if [[ -z "$check_path" ]] || [[ "$check_path" == "/" ]] || [[ "$check_path" == "/root" ]]; then
    echo -e "⚠️  \033[33m跳过: 路径变量为空或指向系统核心目录，拒绝执行命令: $cmd\033[0m"
    return 1
  fi

  # 2. 交互确认
  echo -e "\n---------------------------------------------------"
  echo -e "💡 任务: $desc"
  echo -e "🚀 即将执行: \033[31;1m$cmd\033[0m"

  # 使用 -r 防止反斜杠转义
  read -rp "❓ 您确认执行此操作吗? (输入 y/n): " confirm

  if [[ "$confirm" =~ ^[yY]$ ]]; then
    eval "$cmd"
    echo -e "✅ \033[32m执行完毕\033[0m"
  else
    echo -e "⏭️  \033[34m已取消操作\033[0m"
  fi
}

echo -e "\033[36;1m开始扫描并清理系统冗余资源...\033[0m"

# --- 1. Docker 资源清理 ---
echo -e "\n🐳 [1/5] Docker 资源检查..."
if command -v docker &>/dev/null; then
  # docker system prune 会自动跳过运行中的容器和使用的网络，相对安全
  docker system prune -f
else
  echo "未检测到 Docker，跳过。"
fi

# --- 2. Homebrew 缓存清理 ---
echo -e "\n🍺 [2/5] Homebrew 资源检查..."
CUR_USER=$(logname)
if command -v brew &>/dev/null; then
  # Homebrew 内部清理
  sudo -u "$CUR_USER" brew cleanup -s

  # 获取缓存路径
  BREW_CACHE=$(sudo -u "$CUR_USER" brew --cache)
  # 安全删除缓存文件
  safe_interactive_rm "清理 Homebrew 源码及二进制缓存" "rm -rf ${BREW_CACHE}/*" "$BREW_CACHE"
fi

# --- 3. Systemd Journal 日志清理 ---
echo -e "\n📜 [3/5] 系统日志检查..."
# 这个命令本身非常安全，不会删除当前正在写入的日志
echo "当前日志占用: $(journalctl --disk-usage)"
journalctl --vacuum-time=2d
journalctl --vacuum-size=500M

# --- 4. Snap 历史版本清理 ---
echo -e "\n⚡ [4/5] Snap 软件包检查..."
if command -v snap &>/dev/null; then
  # 清理缓存
  SNAP_CACHE="/var/lib/snapd/cache"
  if [ -d "$SNAP_CACHE" ]; then
    safe_interactive_rm "清理 Snap 下载包缓存" "rm -rf ${SNAP_CACHE}/*" "$SNAP_CACHE"
  fi

  # 清理已禁用的旧版本 (非 rm 操作，直接通过 snap remove 确保安全)
  echo "正在扫描 Snap 旧版本..."
  snap list --all | awk '/disabled/{print $1, $3}' | while read -r name rev; do
    if [ -n "$name" ]; then
      echo "正在移除旧版本: $name (rev $rev)"
      snap remove "$name" --revision="$rev"
    fi
  done
fi

# --- 5. APT 自动清理 ---
echo -e "\n🏠 [5/5] APT 包管理器清理..."
# 仅删除已不再需要的孤儿包和缓存的旧安装包
apt-get autoremove -y
apt-get autoclean -y

echo -e "\n\033[32;1m✨ 全流程清理结束!\033[0m"
df -h / | awk 'NR==1 || NR==2'
