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
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd j)"
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# zsh-ai 插件（当前保持注释，未启用）
#source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh