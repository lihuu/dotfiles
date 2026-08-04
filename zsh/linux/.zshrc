# ~/.zshrc — 薄入口（Linux / WSL 版）
#
# 三层隔离结构（与 zsh/macos 同构）：
#   1. ~/.zshrc.d/*.zsh   — 可分享的主配置（PATH/env/alias/函数/工具），按编号顺序加载
#   2. ~/.zshrc.private   — 秘密层（API key / token），绝不进仓库
#   3. ~/.zshrc.local     — 安装器注入 + 机器专属 PATH 治理，不进仓库
#
# 本文件只负责按顺序拼起来，不承载具体配置。

# --- 1. 主配置模块（按编号顺序加载）---
# 只匹配以数字前缀开头的 .zsh 文件（如 10-path.zsh、60-tools.zsh）
for f in "$HOME/.zshrc.d"/[0-9]*.zsh(N); do
    source "$f"
done

# --- 2. 秘密层 ---
if [ -f "$HOME/.zshrc.private" ]; then
    source "$HOME/.zshrc.private"
fi

# --- 3. 安装器隔离层 ---
if [ -f "$HOME/.zshrc.local" ]; then
    source "$HOME/.zshrc.local"
fi
