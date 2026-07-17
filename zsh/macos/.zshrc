# ~/.zshrc — 薄入口
#
# 三层隔离结构：
#   1. ~/.zshrc.d/*.zsh   — 可分享的主配置（PATH/env/alias/函数/工具），按编号顺序加载
#   2. ~/.zshrc.private   — 秘密层（API key / token），绝不进仓库
#   3. ~/.zshrc.local     — 安装器注入 + 机器专属 PATH 治理，不进仓库
#
# 本文件只负责按顺序拼起来，不承载具体配置。
# 安装器若再次往本文件塞内容，定期把它们剪到 ~/.zshrc.local 即可。

# --- 1. 主配置模块（按编号顺序加载）---
# 只匹配以数字前缀开头的 .zsh 文件（如 10-path.zsh、60-tools.zsh），
# 排除 zshrc.d/ 里的独立脚本（tidy-zshrc、import-zoxide-history.zsh 等），
# 它们带 set -euo pipefail，被 source 会污染整个交互式 shell。
# glob 限定符 (N) 开启 nullglob，匹配为空时不报错
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
