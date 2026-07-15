#!/bin/sh
# install-zsh-config.sh - 部署 dotfiles 中的 zsh 配置到当前用户
#
# 用途：在新 Mac 上部署模块化 zsh 配置（三层隔离结构）。
# 幂等：可重复执行，已存在的隔离层文件（.private/.local）不会被覆盖。
#
# 用法：
#   sh zsh/macos/install-zsh-config.sh          从仓库部署
#   sh zsh/macos/install-zsh-config.sh --check   只检查，不实际部署
#
# 前提：
#   1. Homebrew 已安装
#   2. oh-my-zsh 已安装（配置依赖）
#   3. brew install zoxide fzf thefuck bat vim（配置依赖的工具）
#
# 部署后还需要手动做的事：
#   1. 从旧机器拷贝 ~/.zshrc.private（API key/token，不能走 git）
#   2. source ~/.zshrc 生效
#   3. zsh zsh/import-zoxide-history.zsh 导入 zoxide 历史
set -eu

# --- 路径 ---
# 脚本所在目录的上级是仓库根
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
src_macos="$repo_root/zsh/macos"
src_tests="$repo_root/zsh/tests"
src_zsh="$repo_root/zsh"

dest_home="$HOME"
dest_zshrc="$dest_home/.zshrc"
dest_zshrc_d="$dest_home/.zshrc.d"
dest_zshrc_tests="$dest_home/.zshrc.tests"

# --- 参数 ---
check_only=false
for arg in "$@"; do
    case "$arg" in
        --check) check_only=true ;;
        -h|--help)
            echo "Usage: $0 [--check]"
            echo "  --check  只检查环境，不实际部署"
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
if [ ! -f "$src_macos/.zshrc" ]; then
    err "找不到仓库配置: $src_macos/.zshrc"
    err "请确认脚本路径正确，应在 dotfiles 仓库内执行"
    exit 66
fi
ok "仓库配置存在: $src_macos"

# 必需命令（不强制，只警告）
check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1 已安装"
        return 0
    else
        warn "$1 未安装（配置中依赖，建议安装）"
        return 1
    fi
}

echo ""
info "检查依赖工具（缺失不影响部署，但影响功能）"
check_cmd brew
check_cmd zoxide
check_cmd fzf
check_cmd thefuck
check_cmd bat
check_cmd vim
check_cmd git

# oh-my-zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "oh-my-zsh 已安装"
else
    warn "oh-my-zsh 未安装（20-oh-my-zsh.zsh 会报错）"
    warn "安装: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

if $check_only; then
    echo ""
    info "检查模式完成，未部署任何文件。去掉 --check 执行实际部署。"
    exit 0
fi

# --- 2. 备份现有配置 ---
echo ""
info "备份现有配置..."
backup_dir="$dest_home/.zshrc.backup.$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
for f in "$dest_zshrc" "$dest_zshrc_d" "$dest_zshrc_tests"; do
    if [ -e "$f" ]; then
        cp -r "$f" "$backup_dir/$(basename "$f")"
        ok "已备份: $(basename "$f") -> $backup_dir/"
    fi
done

# --- 3. 部署可分享配置（从仓库覆盖）---
echo ""
info "部署可分享配置（从仓库到 $dest_home）..."

# .zshrc 薄入口
cp "$src_macos/.zshrc" "$dest_zshrc"
ok ".zshrc"

# ~/.zshrc.d/ 模块 + tidy-zshrc
mkdir -p "$dest_zshrc_d"
cp "$src_macos"/zshrc.d/*.zsh "$dest_zshrc_d/"
cp "$src_macos/tidy-zshrc" "$dest_zshrc_d/"
chmod +x "$dest_zshrc_d/tidy-zshrc"
ok "~/.zshrc.d/ ($(( $(ls "$dest_zshrc_d"/*.zsh "$dest_zshrc_d"/tidy-zshrc | wc -l) )) 个文件)"

# ~/.zshrc.tests/
mkdir -p "$dest_zshrc_tests"
cp "$src_tests"/test-*.zsh "$dest_zshrc_tests/"
ok "~/.zshrc.tests/"

# import-zoxide-history.zsh（放在 ~/.zshrc.d/ 旁，和现有结构一致）
cp "$src_zsh/import-zoxide-history.zsh" "$dest_zshrc_d/"
chmod +x "$dest_zshrc_d/import-zoxide-history.zsh"
ok "import-zoxide-history.zsh"

# --- 4. 隔离层文件：不覆盖 ---
echo ""
info "隔离层文件检查（不覆盖已有内容）..."

if [ -f "$dest_home/.zshrc.private" ]; then
    ok "~/.zshrc.private 已存在，保留不动"
else
    warn "~/.zshrc.private 不存在（秘密层：API key/token）"
    warn "  需从旧机器手动拷贝，不要走 git"
fi

if [ -f "$dest_home/.zshrc.local" ]; then
    ok "~/.zshrc.local 已存在，保留不动"
else
    warn "~/.zshrc.local 不存在（安装器隔离层）"
    warn "  暂不需要创建，装工具时安装器会写入，再跑 tidy-zshrc 整理"
fi

# --- 5. 完成 ---
echo ""
info "\033[32m部署完成\033[0m"
echo ""
echo "下一步："
echo "  1. 拷贝 ~/.zshrc.private（从旧机器，含 API key/token）"
echo "  2. 生效配置:  source ~/.zshrc"
echo "  3. 导入 zoxide 历史（冷启动）:"
echo "       zsh ~/.zshrc.d/import-zoxide-history.zsh --dry-run   # 先预览"
echo "       zsh ~/.zshrc.d/import-zoxide-history.zsh             # 确认后执行"
echo "  4. 后续安装器往 .zshrc 塞内容时，整理:"
echo "       ~/.zshrc.d/tidy-zshrc --apply"
echo ""
echo "备份在: $backup_dir"
echo "如需回滚: cp $backup_dir/.zshrc ~/.zshrc && rm -rf ~/.zshrc.d ~/.zshrc.tests"