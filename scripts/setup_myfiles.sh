#!/bin/bash

# ================= 配置区域 =================
MAIN_DIR="$HOME/MyFiles"
# 请根据实际情况修改你的 OneDrive/GoogleDrive 挂载路径
CLOUD_DRIVE_PATH="$HOME/OneDrive"
BACKUP_DEST="$CLOUD_DRIVE_PATH/backup"
# ===========================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 1. 环境检测：检查 Rsync 是否安装 ---
echo -e "${BLUE}正在检查系统环境...${NC}"
if ! command -v rsync &>/dev/null; then
  echo -e "${RED}错误: 未检测到 rsync 工具。${NC}"
  echo -e "rsync 是 Linux 下最强大的增量备份工具。"
  echo -e "请运行以下命令进行安装，然后重新运行此脚本："
  echo -e "${YELLOW}sudo apt update && sudo apt install rsync -y${NC}"
  exit 1
else
  echo -e "${GREEN}检测到 rsync 已安装。${NC}"
fi

# --- 2. 创建目录结构 ---
echo -e "\n${BLUE}开始构建/检查目录结构...${NC}"

declare -a dirs=(
  "00_Inbox"
  "Workspace/Native-App"
  "Workspace/Backend"
  "Workspace/Scripts"
  "Workspace/Web/Hugo-Site"
  "Workspace/Lab"
  "Workspace/Git"
  "Personal/Identity"
  "Personal/Health/Medical"
  "Personal/Health/Hiking-Stats"
  "Personal/Vehicle"
  "Personal/Finance"
  "Knowledge/Tech-Stack/AI"
  "Knowledge/Tech-Stack/Linux"
  "Knowledge/Anime"
  "Knowledge/Hiking"
  "Creative/Photography"
  "Creative/Writing"
  "Config/Rime"
  "Config/JetBrains"
  "Config/Hammerspoon"
  "Config/Dotfiles"
  "Archives/2024"
  "Archives/Old-PC"
  "Archives/Projects"
)

for dir in "${dirs[@]}"; do
  TARGET="$MAIN_DIR/$dir"
  if [ ! -d "$TARGET" ]; then
    mkdir -p "$TARGET"
    echo -e "已创建: $TARGET"
  fi
done

# 创建 README
if [ ! -f "$MAIN_DIR/README.md" ]; then
  echo "# MyFiles 个人数据中心" >"$MAIN_DIR/README.md"
fi

echo -e "目录检查完成: ${GREEN}$MAIN_DIR${NC}"

# --- 3. 备份功能函数 ---
perform_backup() {
  echo -e "\n${BLUE}--- 开始执行安全备份 ---${NC}"

  # 检查云盘挂载
  if [ ! -d "$CLOUD_DRIVE_PATH" ]; then
    echo -e "${RED}错误: 未找到云盘路径 '$CLOUD_DRIVE_PATH'${NC}"
    echo "请修改脚本中的 CLOUD_DRIVE_PATH 变量。"
    return 1
  fi

  # 确保备份目录存在
  if [ ! -d "$BACKUP_DEST" ]; then
    mkdir -p "$BACKUP_DEST"
  fi

  echo -e "源目录: $MAIN_DIR"
  echo -e "目标目录: $BACKUP_DEST"
  echo -e "${YELLOW}模式: 单向增量备份 (本地删除不会影响备份)${NC}"

  # =======================================================
  # rsync 核心命令解析:
  # -a : 归档模式 (递归 + 保留权限/时间/软链接)
  # -v : 显示详细过程
  # 注意: 这里没有加 --delete，所以是“只增不减”的安全备份
  # =======================================================
  rsync -av "$MAIN_DIR" "$BACKUP_DEST/"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}>>> 备份成功完成！ <<<${NC}"
    echo "当前时间: $(date)"
  else
    echo -e "${RED}>>> 备份失败，请检查错误日志 <<<${NC}"
  fi
}

# --- 4. 交互询问 ---
read -p "是否立即执行一次备份? (y/n): " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
  perform_backup
else
  echo -e "已跳过备份。"
fi
