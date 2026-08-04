#!/bin/sh
# install-zsh-config.sh - 部署 dotfiles 中的 Linux/WSL zsh 配置到当前用户
#
# 用途：在新 Linux / WSL 上部署模块化 zsh 配置(三层隔离结构)。
# 幂等：可重复执行，已存在的隔离层文件(.private/.local)不会被覆盖。
#
# 双向同步模型（保证仓库与环境不冲突）：
#   - 模块文件(~/.zshrc.d/[0-9]*.zsh)是双向同步对象：两边都可能改
#   - 薄入口 .zshrc 是单向(仓库→环境)：环境侧的 .zshrc 会被安装器污染，
#     以仓库版为准，不要手动改环境 .zshrc
#   - .private / .local 永不进仓库(秘密/机器专属)
#
# 用法：
#   sh zsh/linux/install-zsh-config.sh               仓库→环境 部署
#   sh zsh/linux/install-zsh-config.sh --check       只检查，不实际部署
#   sh zsh/linux/install-zsh-config.sh --diff        对比仓库与环境模块差异(只读)
#   sh zsh/linux/install-zsh-config.sh --pull        环境→仓库 反向同步(带确认)
#   sh zsh/linux/install-zsh-config.sh --push        仓库→环境 强制部署(默认行为)
#
# 前提：
#   1. zsh 已安装并设为默认 shell（chsh -s $(which zsh)）
#   2. oh-my-zsh 已安装(配置依赖)
#   3. Homebrew (Linuxbrew) 已安装(配置依赖)
#   4. zoxide/fzf/thefuck/bat/vim 为必需依赖：缺失时脚本会用 brew 自动安装
#
# 部署后还需要手动做的事：
#   1. 从旧机器拷贝 ~/.zshrc.private(API key/token，不能走 git)
#   2. source ~/.zshrc 生效
set -eu

# --- 路径 ---
# 脚本所在目录的上级是仓库根
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
src_linux="$repo_root/zsh/linux"
src_modules="$src_linux/zshrc.d"

dest_home="$HOME"
dest_zshrc="$dest_home/.zshrc"
dest_zshrc_d="$dest_home/.zshrc.d"

# --- 参数 ---
check_only=false
pull_mode=false
diff_mode=false
for arg in "$@"; do
    case "$arg" in
        --check) check_only=true ;;
        --pull) pull_mode=true ;;
        --diff) diff_mode=true ;;
        --push) pull_mode=false ;;
        -h|--help)
            echo "Usage: $0 [--check|--diff|--pull|--push]"
            echo "  --check  只检查环境，不实际部署"
            echo "  --diff   对比仓库与环境模块差异(只读，退出码 1 表示有差异)"
            echo "  --pull   环境→仓库 反向同步(先显示差异，确认后执行)"
            echo "  --push   仓库→环境 部署(默认行为)"
            exit 0
            ;;
        *) echo "未知参数: $arg"; exit 64 ;;
    esac
done

# --- 辅助函数 ---
info()  { printf "\033[34m==>\033[0m %s\n" "$1"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn()  { printf "  \033[33m⚠\033[0m %s\n" "$1"; }
err()   { printf "  \033[31m✗\033[0m %s\n" "$1" >&2; }

# --- 1. 检查环境 ---
info "检查环境..."

# 仓库源文件
if [ ! -f "$src_linux/.zshrc" ]; then
    err "找不到仓库配置: $src_linux/.zshrc"
    err "请确认脚本路径正确，应在 dotfiles 仓库内执行"
    exit 66
fi
ok "仓库配置存在: $src_linux"

# 必需命令(不强制，只警告)
check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1 已安装"
        return 0
    else
        warn "$1 未安装(配置中依赖，建议安装)"
        return 1
    fi
}

echo ""
info "检查依赖工具..."
check_cmd brew || true
check_cmd git || true

# ensure_tool <name>：确保工具存在，缺失时通过 brew 自动安装。
# brew 不可用或安装失败则报错退出（硬性依赖，功能会失效）。
# 注意：--check 模式只检测不安装，见下方调用处。
ensure_tool() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        ok "$name 已安装"
        return 0
    fi
    if $check_only; then
        warn "$name 未安装(部署时会自动安装)"
        return 1
    fi
    if command -v brew >/dev/null 2>&1; then
        warn "$name 未安装，通过 brew 自动安装..."
        brew install "$name" || {
            err "$name 安装失败，请手动安装后重试"
            exit 70
        }
        ok "$name 已安装"
    else
        err "$name 未安装，且 brew 不可用，无法自动安装"
        err "请先安装 Homebrew (Linuxbrew) 或手动安装 $name"
        exit 70
    fi
}

# 必需依赖（缺失时自动安装）
# zoxide: 智能目录跳转(60-tools.zsh)
# fzf:    gitlog 交互浏览、zoxide 的 j -l 交互选择(50/60)
# thefuck: 命令纠错(60-tools.zsh)
# bat:    高亮显示，vim 的替代降级链(50-functions.zsh)
ensure_tool zoxide || true
ensure_tool fzf || true
ensure_tool thefuck || true
ensure_tool bat || true
ensure_tool vim || true

# oh-my-zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "oh-my-zsh 已安装"
else
    warn "oh-my-zsh 未安装(20-oh-my-zsh.zsh 会报错)"
    warn "安装: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

if $check_only; then
    echo ""
    info "检查模式完成，未部署任何文件。去掉 --check 执行实际部署。"
    exit 0
fi

# --- 1.5 diff / pull 模式 ---
# 只比较 zshrc.d 模块(双向同步对象)，薄入口 .zshrc 单向，不参与反向同步
if $diff_mode || $pull_mode; then
    echo ""
    info "对比仓库与环境的 zshrc.d 模块..."
    mkdir -p "$dest_zshrc_d"

    has_diff=false
    # 仓库有、环境缺失 或 内容不同
    for src in "$src_modules"/[0-9]*.zsh; do
        [ -f "$src" ] || continue
        name="$(basename "$src")"
        if [ ! -f "$dest_zshrc_d/$name" ]; then
            warn "环境缺少模块: $name (仓库有)"
            has_diff=true
        elif ! diff -q "$src" "$dest_zshrc_d/$name" >/dev/null 2>&1; then
            warn "模块有差异: $name"
            diff -u "$dest_zshrc_d/$name" "$src" | head -40 || true
            has_diff=true
        fi
    done
    # 环境有、仓库没有(只提示，不自动删)
    for dest in "$dest_zshrc_d"/[0-9]*.zsh; do
        [ -f "$dest" ] || continue
        name="$(basename "$dest")"
        if [ ! -f "$src_modules/$name" ]; then
            warn "环境多出模块: $name (仓库没有，--pull 会带入仓库)"
            has_diff=true
        fi
    done

    if ! $has_diff; then
        ok "仓库与环境模块完全一致"
        if $pull_mode; then
            info "无需反向同步。"
        fi
        exit 0
    fi

    if $diff_mode; then
        echo ""
        info "差异如上。--pull 可将环境改动同步回仓库。"
        exit 1
    fi

    # pull 模式：确认后反向同步
    echo ""
    printf "确认将环境模块同步回仓库 (zsh/linux/zshrc.d/) ? [y/N]: "
    read confirm || true
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        info "已取消反向同步。"
        exit 0
    fi

    echo ""
    info "反向同步 (环境 → 仓库)..."
    for dest in "$dest_zshrc_d"/[0-9]*.zsh; do
        [ -f "$dest" ] || continue
        name="$(basename "$dest")"
        cp "$dest" "$src_modules/$name"
        ok "$name"
    done
    echo ""
    info "反向同步完成。请在仓库内 review 改动后提交: git diff zsh/linux/zshrc.d/"
    exit 0
fi

# --- 2. 备份现有配置 ---
echo ""
info "备份现有配置..."
backup_dir="$dest_home/.zshrc.backup.$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
for f in "$dest_zshrc" "$dest_zshrc_d"; do
    if [ -e "$f" ]; then
        cp -r "$f" "$backup_dir/$(basename "$f")"
        ok "已备份: $(basename "$f") -> $backup_dir/"
    fi
done

# --- 3. 部署可分享配置(从仓库覆盖)---
echo ""
info "部署可分享配置(从仓库到 $dest_home)..."

# .zshrc 薄入口
cp "$src_linux/.zshrc" "$dest_zshrc"
ok ".zshrc"

# ~/.zshrc.d/ 模块（只拷数字前缀的模块文件）
mkdir -p "$dest_zshrc_d"
cp "$src_linux"/zshrc.d/[0-9]*.zsh "$dest_zshrc_d/"
ok "~/.zshrc.d/ ($(( $(ls "$dest_zshrc_d"/*.zsh | wc -l) )) 个模块)"

# --- 4. 隔离层文件：不覆盖 ---
echo ""
info "隔离层文件检查(不覆盖已有内容)..."

if [ -f "$dest_home/.zshrc.private" ]; then
    ok "~/.zshrc.private 已存在，保留不动"
else
    warn "~/.zshrc.private 不存在(秘密层：API key/token)"
    warn "  需从旧机器手动拷贝，不要走 git"
fi

if [ -f "$dest_home/.zshrc.local" ]; then
    ok "~/.zshrc.local 已存在，保留不动"
else
    warn "~/.zshrc.local 不存在(安装器隔离层)"
    warn "  暂不需要创建，装工具时安装器会写入，再手动整理"
fi

# --- 5. 完成 ---
echo ""
info "部署完成"
echo ""
echo "下一步："
echo "  1. 拷贝 ~/.zshrc.private(从旧机器，含 API key/token)"
echo "  2. 生效配置:  source ~/.zshrc"
echo ""
echo "备份在: $backup_dir"
echo "如需回滚: cp $backup_dir/.zshrc ~/.zshrc && rm -rf ~/.zshrc.d"
