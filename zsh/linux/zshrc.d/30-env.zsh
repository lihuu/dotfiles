# 30-env.zsh — 非秘密环境变量 + PATH 项收集 + PATH 统一组装
#
# 这里定义可分享的环境变量（非秘密），紧跟着收集 PATH 项并统一组装 PATH。
# 放在 oh-my-zsh 之后：部分变量依赖 oh-my-zsh 已加载。
# 放在 alias/函数/工具初始化之前：它们可能依赖这些 env。

# --- 网络代理 ---
# WSL mirrored 网络模式下，127.0.0.1 即 Windows 宿主机地址
# 本机代理端口以实际为准；如未运行代理程序会自动回退直连
#export http_proxy="http://127.0.0.1:10808"
#export https_proxy="http://127.0.0.1:10808"
export no_proxy="127.0.0.1,localhost"

# --- 开发语言 / 工具链 ---
# GOROOT 由 mise 管 go 时自动设置，无需手动 export
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
#export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
#export ANDROID_HOME=$HOME/Android/Sdk
#export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/22.1.7171670
#export ROCKETMQ_HOME=$HOME/Applications/rocketmq-all-5.1.0-bin-release

# --- Homebrew (Linuxbrew) ---
export HOMEBREW_NO_AUTO_UPDATE=true
# 国内镜像源（按需启用）
#export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"

# --- 语言环境 ---
export LANG=zh_CN.UTF-8
export LC_CTYPE=zh_CN.UTF-8

# --- 历史遗留（Linux 桌面 / WSLg 输入法，按需启用）---
#export XMODIFIERS=@im=fcitx
#export GTK_IM_MODULE=fcitx
#export QT_IM_MODULE=fcitx

# --- 收集 PATH 项（依赖上面的 env 变量）---
add_to_path "$HOME/.local/bin"
add_to_path "$GOBIN"
add_to_path "$HOME/go/bin"
add_to_path "$JAVA_HOME/bin"
add_to_path "$HOME/.deno/bin"
add_to_path "$HOME/.volta/bin"
add_to_path "$HOME/.config/yarn/global/node_modules/.bin"
add_to_path "$HOME/.docker/cli-plugins"

# === PATH 变量统一组装 ===
# 启用唯一性约束，确保没有重复项
typeset -U path PATH

# 将我们收集的路径项添加到现有 path 数组的最前面
path=(${_path_items[@]} $path)
