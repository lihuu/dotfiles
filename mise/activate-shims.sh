#!/usr/bin/env sh
# mise/activate-shims.sh — 自动化场景下激活 mise 的 shims 模式
#
# 适用场景：
#   - cron / launchd / ssh 远程单命令 / CI 等非交互 shell
#   - bash/sh 脚本（不会加载 ~/.zshrc，PATH 模式钩子无法生效）
#   - Makefile、git hooks、IDE 任务等子进程
#
# 与交互式 .zshrc 里的 PATH 模式（mise activate zsh）互不冲突：
#   PATH 模式靠 chpwd 钩子动态注入；shims 模式靠固定 shims 目录在 PATH 里兜底。
#   交互终端用 PATH 模式（已在 60-tools.zsh 启用），自动化场景 source 本文件即可。
#
# 用法（在自动化脚本里）：
#   . "$HOME/git/dotfiles/mise/activate-shims.sh"
#   # 或用绝对路径 source：
#   source /path/to/dotfiles/mise/activate-shims.sh
#
# 之后该进程及其子进程都能直接调用 mise 管理的 node/python/... 等工具。
# 设计为 POSIX sh 兼容，bash/zsh/dash/ksh 均可 source。

# 仅当 mise 已安装时才把 shims 目录加到 PATH，避免新机器/最小环境报错。
# shims 目录定位（按 mise 优先级）：
#   1. $MISE_DATA_DIR/shims   —— 用户显式覆盖
#   2. $XDG_DATA_HOME/mise/shims —— XDG 标准位置
#   3. $HOME/.local/share/mise/shims —— 默认位置
# 不依赖 `mise data-dir` 子命令（部分版本不提供，会被当任务名解析）。
if command -v mise >/dev/null 2>&1; then
    if [ -n "$MISE_DATA_DIR" ]; then
        _mise_shims_dir="$MISE_DATA_DIR/shims"
    elif [ -n "$XDG_DATA_HOME" ]; then
        _mise_shims_dir="$XDG_DATA_HOME/mise/shims"
    else
        _mise_shims_dir="$HOME/.local/share/mise/shims"
    fi

    if [ -d "$_mise_shims_dir" ]; then
        # 已在 PATH 里就不重复加（用 case 做 POSIX 兼容判断）
        case ":$PATH:" in
            *":$_mise_shims_dir:"*) ;;
            *) PATH="$_mise_shims_dir:$PATH"; export PATH ;;
        esac
    fi
    unset _mise_shims_dir
fi