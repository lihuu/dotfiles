# 25-completion.zsh - 补全交互增强（菜单选择）
#
# 依赖：20-oh-my-zsh.zsh 已 source oh-my-zsh.sh（内含 compinit）。
# 作用：Tab 后进入菜单选择模式，继续输入字符会过滤候选，方向键可选。
#       影响所有命令的补全，不止 systemctl。
#
# 交互行为：
#   systemctl status re<Tab>    -> 弹出所有 re 开头的服务候选菜单
#   继续敲 d                    -> 过滤为 red 开头
#   ↑↓ 选择，Enter 确认
#
# 说明：
#   - auto_menu：连按 Tab 或补全有多个候选时自动进入菜单
#   - menu select：菜单可用方向键选择，继续输入会过滤
#   - list-choices：在菜单下方常驻候选列表，看得更清楚
#   - 此处只配置最关键的两条，其余走 oh-my-zsh 默认

setopt auto_menu 2>/dev/null

zstyle ':completion:*' menu select=1
zstyle ':completion:*' list-choices yes