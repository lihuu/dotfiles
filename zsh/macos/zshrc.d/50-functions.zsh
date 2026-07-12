# 50-functions.zsh — 个人函数
#
# 通用工具函数。vibe-update 已在 20-oh-my-zsh.zsh（与插件管理相关）。

function random_secret(){
  openssl rand -hex 32
}

listening() {
    if [ $# -eq 0 ]; then
        sudo lsof -iTCP -sTCP:LISTEN -n -P
    elif [ $# -eq 1 ]; then
        sudo lsof -iTCP -sTCP:LISTEN -n -P | grep -i --color $1
    else
        echo "Usage: listening [pattern]"
    fi
}


# === Move to MyFiles (mvm) ===
# 用法:
# 1. mvm filename          -> 移动到 00_Inbox (默认)
# 2. mvm filename finance  -> 移动到 Personal/Finance (智能匹配)
# 3. mvm filename app      -> 移动到 Workspace/Native-App

function mvm() {
    local file="$1"
    local keyword="$2"
    local root_dir="$HOME/MyFiles"

    # 检查是否有文件输入
    if [ -z "$file" ]; then
        echo "用法: mvm <文件名> [目标关键词]"
        echo "示例: mvm report.pdf finance"
        return 1
    fi

    # 检查文件是否存在
    if [ ! -e "$file" ]; then
        echo "错误: 文件 '$file' 不存在"
        return 1
    fi

    local target_dir=""

    # 如果没有提供关键词，默认移动到 Inbox
    if [ -z "$keyword" ]; then
        target_dir="$root_dir/00_Inbox"
    else
        # 使用 find 命令在 MyFiles 中模糊查找匹配的目录名
        # 排除 .git 目录，只查找目录类型
        # head -n 1 取第一个匹配项
        local match=$(find "$root_dir" -type d -not -path '*/.*' -name "*${keyword}*" | head -n 1)

        if [ -n "$match" ]; then
            target_dir="$match"
        else
            echo "未找到包含 '$keyword' 的目录，将移动到 00_Inbox"
            target_dir="$root_dir/00_Inbox"
        fi
    fi

    echo "正在移动 '$file' -> '$target_dir' ..."
    mv "$file" "$target_dir/" && echo "✅ 完成！"
}