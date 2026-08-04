# 25-completion.zsh - 补全交互增强（菜单选择）
#
# 依赖：20-oh-my-zsh.zsh 已 source oh-my-zsh.sh（内含 compinit）。
# 作用：Tab 后进入菜单选择模式，继续输入字符会过滤候选，方向键可选。

setopt auto_menu 2>/dev/null

zstyle ':completion:*' menu select=1
zstyle ':completion:*' list-choices yes
