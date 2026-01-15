#!/bin/bash

# 设置目标字体目录 (用户级安装，无需 root 权限)
FONT_DIR="$HOME/.local/share/fonts"
TARGET_SUBDIR="FontBlexMonoNerd"
INSTALL_PATH="$FONT_DIR/$TARGET_SUBDIR"

echo "🚀 开始寻找并安装字体..."

# 1. 创建字体目录
if [ ! -d "$INSTALL_PATH" ]; then
  mkdir -p "$INSTALL_PATH"
  echo "📁 创建目录: $INSTALL_PATH"
fi

# 2. 查找并复制字体文件 (支持 ttf 和 otf)
# -iname 忽略大小写
find . -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.otf" \) | while read -r font; do
  echo "📄 正在安装: $font"
  cp "$font" "$INSTALL_PATH/"
done

# 3. 刷新系统字体缓存
echo "🔄 正在刷新字体缓存..."
fc-cache -fv >/dev/null

echo "✅ 安装完成！你现在可以在系统设置或 IDE 中选择新字体了。"
