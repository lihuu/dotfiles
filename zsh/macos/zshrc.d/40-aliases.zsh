# 40-aliases.zsh — alias 集合
#
# 个人 alias，覆盖 oh-my-zsh 默认值。

#alias gvim='/Applications/MacVim.app/Contents/MacOS/Vim -g'
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias gnvim='nvim-qt'
alias cl=clear
alias gst="git status"
alias gcm="git commit"
alias gpl="git pull"
alias gplr="git pull --rebase"
alias gbr="git branch"
alias clear_docker_image="docker image prune -a"
alias apt=brew
alias mcp-get="npx @michaellatman/mcp-get"
alias antigravity="agy"
alias claudex="claude --dangerously-skip-permissions"
#alias grep=rg
#alias cat=bat
#alias python=/opt/homebrew/bin/python3
#alias pip=/opt/homebrew/bin/pip3
#alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"

#code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}