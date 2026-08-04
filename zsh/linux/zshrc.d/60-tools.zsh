# 60-tools.zsh — 工具初始化
#
# 第三方工具的 shell 集成，放在最后加载：
# PATH/env/alias/函数都已就绪，工具可以放心引用。

# Homebrew (Linuxbrew) — 环境变量由 brew shellenv 管理
# 必须最先加载：zoxide/fzf 等工具装在 brew 目录，需先入 PATH 才能被后续检测到。
# Linuxbrew 为系统级安装，官方固定前缀 /home/linuxbrew/.linuxbrew
# （类似 macOS 的 /opt/homebrew），不随用户目录变化，不能用 $HOME 替代。
# 优先使用 PATH 中已有的 brew，找不到再回退官方安装位置。
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# thefuck
if command -v thefuck >/dev/null 2>&1; then
    eval $(thefuck --alias)
fi
setopt nonomatch

# 智能目录跳转：j <query> 直接跳转，ji <query> 使用 fzf 交互选择。
# 使用 zoxide 自带的命令重命名能力，不覆盖原生 cd。
# 收录策略（my_zoxide_add）：
#   - 白名单前缀目录（~/git/ ~/MyFiles/）下才检查 .git
#   - 在 git 仓库内：只收录 repo 根目录，不收录子目录
#   - 不在白名单内或非 git 目录：正常收录当前目录
#   - 用 --hook none 关掉 zoxide 默认收录，由自定义 chpwd 钩子接管
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd j --hook none)"

    my_zoxide_add() {
        case "$PWD" in
            "$HOME"/git|"$HOME"/git/*|"$HOME"/MyFiles/*) ;;
            *) zoxide add "$PWD"; return ;;
        esac

        # 白名单内：从 $PWD 往上找 .git，只收录 repo 根
        local dir="$PWD"
        while [[ "$dir" != "/" ]]; do
            if [[ -d "$dir/.git" ]]; then
                [[ "$PWD" == "$dir" ]] && zoxide add "$PWD"
                return
            fi
            dir="${dir:h}"
        done
        # 白名单内但非 git 目录：正常收录
        zoxide add "$PWD"
    }

    chpwd_functions+=(my_zoxide_add)
fi

# fzf（按安装方式加载：Linux 通常走 apt/brew，无 ~/.fzf.zsh 则跳过）
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# mise — 多语言版本管理（替代 nvm/volta/asdf/pyenv 等）
# 仅当 mise 已安装时才激活，避免在新机器或最小安装环境下报错。
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

# kubectl completion（按需启用）
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# 历史遗留：nvm（mise 接管 node 后可不启用）
#export NVM_DIR="$HOME/.nvm"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
#[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
