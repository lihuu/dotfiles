#!/bin/bash

# Gradle 缓存目录
GRADLE_CACHE_DIR="$HOME/.gradle/caches"

echo "🧹 开始清理 Gradle 缓存..."

# 1. 清理老版本 Gradle 缓存（保留最新的两个版本）
echo "🔍 查找并删除旧版本缓存..."
cd "$GRADLE_CACHE_DIR" || exit 1
gradle_versions=$(ls -d [0-9]* | sort -Vr | tail -n +3)
for version in $gradle_versions; do
  echo " - 删除版本缓存: $version"
  rm -rf "$version"
done

# 2. 删除本地构建缓存
echo "🗑️ 删除 build-cache-1..."
rm -rf "$GRADLE_CACHE_DIR/build-cache-1"

# 3. 删除 jars、transforms、journal 索引等
echo "🗑️ 删除 jars-9、transforms-3、journal-1..."
rm -rf "$GRADLE_CACHE_DIR/jars-9"
rm -rf "$GRADLE_CACHE_DIR/transforms-3"
rm -rf "$GRADLE_CACHE_DIR/journal-1"

# 4. 停止守护进程 & 删除 daemon 缓存
echo "⛔ 停止 Gradle 守护进程并清理..."
rm -rf "$HOME/.gradle/daemon"
rm -rf "$HOME/.gradle/native"

# 5. 可选：删除依赖缓存（慎用，会重新下载依赖）
# echo "❗ 删除 modules-2 缓存（所有依赖包）..."
# rm -rf "$GRADLE_CACHE_DIR/modules-2"

echo "✅ Gradle 缓存清理完成。"
