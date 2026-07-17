# 30-env.zsh — 非秘密环境变量 + PATH 项收集 + PATH 统一组装
#
# 这里定义可分享的环境变量（非秘密），紧跟着收集 PATH 项并统一组装 PATH。
# 放在 oh-my-zsh 之后：部分变量依赖 oh-my-zsh 已加载。
# 放在 alias/函数/工具初始化之前：它们可能依赖这些 env。

# --- 开发工具 ---
export VOLTA_FEATURE_PNPM=1
export GOROOT_BOOTSTRAP=/opt/homebrew/Cellar/go/1.24.4/libexec
export DOOM_EMACS_HOME=$HOME/.config/emacs
export EMACS_HOME=/Applications/Emacs.app/Contents/MacOS

# sccache 配置
export RUSTC_WRAPPER=sccache
# 可选：限制缓存大小为 20GB（默认 10GB）
export SCCACHE_CACHE_SIZE="20G"

#export MYSQL_HOME=/usr/local/mysql-8.0.18-macos10.14-x86_64

#export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.0.3.1.jdk/Contents/Home

#export JAVA_HOME=/Library/Java/JavaVirtualMachines/graalvm-17.jdk/Contents/Home
export JAVA_HOME=$HOME/Library/Java/JavaVirtualMachines/openjdk-25/Contents/Home

#export http_proxy="127.0.0.1:1080"
#export https_proxy="127.0.0.1:1080"
export no_proxy="127.0.0.1,localhost,*.marketup.local"
#export http_proxy="http://127.0.0.1:7890"
#export https_proxy="http://127.0.0.1:7890"
#export http_proxy=socks5://127.0.0.1:8001
#export https_proxy=socks5://127.0.0.1:8001
#export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export IDEA_HOME="/Applications/IntelliJ IDEA.app/Contents/MacOS"
export HOMEBREW_NO_AUTO_UPDATE=true
export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"
export BUN_INSTALL="$HOME/.bun"
export LANG=zh_CN.UTF-8
export NODE_OPTIONS='--no-deprecation'
#export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
#export http_proxy=http://127.0.0.1:8001
#export https_proxy=http://127.0.0.1:8001
#export NPM_CONFIG_REGISTRY=https://registry.npm.taobao.org

# zsh-ai 配置（当前保持注释，未启用）
export ZSH_AI_PROVIDER="ollama"
export ZSH_AI_OLLAMA_MODEL="qwen3:1.7b"

# codewhale: 允许 HTTP 协议的 OpenAI 兼容端点（本地网关）
export DEEPSEEK_ALLOW_INSECURE_HTTP=true

# af-magic 主题的 afmagic_dashes() 引用 ${VIRTUAL_ENV:-$CONDA_DEFAULT_ENV}，
# 若 CONDA_DEFAULT_ENV 未定义会报 "parameter not set"。
# conda 已卸载，这里预定义为空字符串避免报错；将来重装 conda 会自动覆盖。
export CONDA_DEFAULT_ENV=""

# --- 收集 PATH 项（依赖上面的 env 变量）---
add_to_path "$HOME/.local/bin"
add_to_path "$BUN_INSTALL/bin"
add_to_path "$MYSQL_HOME/bin"
add_to_path "$GOBIN"
add_to_path "$GOROOT/bin"
add_to_path "$DOOM_EMACS_HOME/bin"
add_to_path "$EMACS_HOME"
add_to_path "$IDEA_HOME"
add_to_path "$HOME/.m2"
add_to_path "/usr/local/opt/openssl/bin"
add_to_path "$HOME/.volta/bin"
add_to_path "/opt/homebrew/bin"
add_to_path "/opt/homebrew/sbin"
add_to_path "$HOME/.lmstudio/bin"
add_to_path "$HOME/Documents/scripts"
add_to_path "$HOME/.antigravity/antigravity/bin"
add_to_path "$HOME/Library/Android/sdk/platform-tools"
add_to_path "$HOME/.opencode/bin"
add_to_path "/opt/homebrew/Cellar/node/25.8.2/bin"

# === PATH 变量统一组装 ===
# 启用唯一性约束，确保没有重复项
typeset -U path PATH

# 将我们收集的路径项添加到现有 path 数组的最前面
# zsh 会自动处理 path 数组与 PATH 字符串之间的同步
path=(${_path_items[@]} $path)

# 打印结果（可选，用于验证，正式版可注释掉）
# echo "PATH 组装完成"

#export NODE_OPTIONS="--use-system-ca"