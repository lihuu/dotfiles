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


# === macOS Keychain 密钥管理 ===
# 通过 security 命令操作 macOS 钥匙串，避免在配置文件里明文存密钥。
# 用法:
#   add_secret <service> <secret>   存密钥
#   get_secret <service>            取密钥（可配合 $(get_secret xxx) 注入环境变量）
# 非 macOS 系统（无 security 命令）不创建函数，避免误用。
if command -v security >/dev/null 2>&1; then
    add_secret() {
        local service="$1"
        local secret="$2"
        if [[ -z "$service" || -z "$secret" ]]; then
            echo "用法: add_secret <service> <secret>" >&2
            return 1
        fi
        security add-generic-password -a "$USER" -s "$service" -w "$secret"
    }

    get_secret() {
        local service="$1"
        if [[ -z "$service" ]]; then
            echo "用法: get_secret <service>" >&2
            return 1
        fi
        security find-generic-password -a "$USER" -s "$service" -w
    }
else
    # 非 macOS（无 security 命令）：定义占位函数，调用时打印 warning
    add_secret() {
        print -u2 -- "⚠️  add_secret: macOS Keychain 不可用（无 security 命令），请手动管理密钥"
        return 1
    }
    get_secret() {
        print -u2 -- "⚠️  get_secret: macOS Keychain 不可用（无 security 命令），请手动管理密钥"
        return 1
    }
fi