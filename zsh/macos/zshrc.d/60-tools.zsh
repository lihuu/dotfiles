# 60-tools.zsh — 工具初始化
#
# 第三方工具的 shell 集成，放在最后加载：
# PATH/env/alias/函数都已就绪，工具可以放心引用。

# thefuck
eval $(thefuck --alias)
setopt nonomatch

# Created by `pipx` on 2025-01-16 06:53:03
eval "$(fzf --zsh)"

# 智能目录跳转：j <query> 直接跳转，ji <query> 使用 fzf 交互选择。
# 使用 zoxide 自带的命令重命名能力，不覆盖原生 cd。
#
# 收录策略（my_zoxide_add）：
#   - 白名单前缀目录（~/git/ ~/MyFiles/ ~/ZCodeProject/）下才检查 .git
#   - 在 git 仓库内：只收录 repo 根目录，不收录子目录
#     （避免 j hermes 命中 ~/Code/Hermes/src 等子目录）
#   - 不在白名单内或非 git 目录：正常收录当前目录
#   - 用 --hook none 关掉 zoxide 默认收录，由自定义 chpwd 钩子接管
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd j --hook none)"

    # 白名单：只在这些前缀下检查 .git（按你的仓库分布配置）
    # 新增仓库区时，往 case 里加一行即可
    my_zoxide_add() {
        case "$PWD" in
            "$HOME"/git|"$HOME"/git/*|"$HOME"/MyFiles/*|"$HOME"/ZCodeProject/*) ;;
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

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# zsh-ai 插件（当前保持注释，未启用）
#source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh