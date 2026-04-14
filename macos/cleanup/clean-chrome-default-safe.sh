#!/usr/bin/env bash

set -euo pipefail

CHROME_DEFAULT_DIR="$HOME/Library/Application Support/Google/Chrome/Default"
INDEXEDDB_DIR="$CHROME_DEFAULT_DIR/IndexedDB"
INDEXEDDB_THRESHOLD_MB=100
INDEXEDDB_THRESHOLD_KB=$((INDEXEDDB_THRESHOLD_MB * 1024))

APPLY=0

usage() {
  cat <<'EOF'
Usage: clean-chrome-default-safe.sh [--apply]

默认只做预览，不会删除任何文件。
加上 --apply 后才会真正执行删除，并在执行前再次确认。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$CHROME_DEFAULT_DIR" ]]; then
  echo "未找到 Chrome Default 目录: $CHROME_DEFAULT_DIR"
  exit 0
fi

is_chrome_running() {
  pgrep -x "Google Chrome" >/dev/null 2>&1 || pgrep -f "Google Chrome" >/dev/null 2>&1
}

safe_delete_path() {
  local path="$1"
  local label="$2"
  local size_kb="$3"

  printf '  - %s [%s] (%s KB)\n' "$label" "$path" "$size_kb"
}

du_kb() {
  du -sk "$1" | awk '{print $1}'
}

echo "Chrome Default 目录: $CHROME_DEFAULT_DIR"
echo "IndexedDB 删除阈值: ${INDEXEDDB_THRESHOLD_MB}MB"

if is_chrome_running; then
  echo "警告: 检测到 Google Chrome 可能正在运行。建议先退出 Chrome 再执行删除。"
fi

echo
echo "[1/2] 计划清理的绝对安全缓存目录"

safe_cache_dirs=(
  "Cache"
  "Code Cache"
  "GPUCache"
  "DawnCache"
  "ShaderCache"
  "GrShaderCache"
  "Media Cache"
)

reclaimable_kb=0
candidate_paths=()
candidate_labels=()
candidate_sizes=()

for dir in "${safe_cache_dirs[@]}"; do
  path="$CHROME_DEFAULT_DIR/$dir"
  if [[ -e "$path" ]]; then
    size_kb="$(du_kb "$path")"
    reclaimable_kb=$((reclaimable_kb + size_kb))
    safe_delete_path "$path" "缓存目录" "$size_kb"
    candidate_paths+=("$path")
    candidate_labels+=("缓存目录")
    candidate_sizes+=("$size_kb")
  fi
done

echo
echo "[2/2] IndexedDB 体积检查（仅删除单个目录 >= ${INDEXEDDB_THRESHOLD_MB}MB）"

indexeddb_deleted=0
if [[ -d "$INDEXEDDB_DIR" ]]; then
  while IFS= read -r -d '' item; do
    [[ -e "$item" ]] || continue

    size_kb="$(du_kb "$item")"
    if [[ "$size_kb" -ge "$INDEXEDDB_THRESHOLD_KB" ]]; then
      safe_delete_path "$item" "IndexedDB 大目录" "$size_kb"
      reclaimable_kb=$((reclaimable_kb + size_kb))
      indexeddb_deleted=$((indexeddb_deleted + 1))
      candidate_paths+=("$item")
      candidate_labels+=("IndexedDB 大目录")
      candidate_sizes+=("$size_kb")
    else
      printf '  - 跳过 %s (%s KB, 小于阈值)\n' "$item" "$size_kb"
    fi
  done < <(find "$INDEXEDDB_DIR" -mindepth 1 -maxdepth 1 -print0)
else
  echo "未找到 IndexedDB 目录，跳过。"
fi

echo
printf '预计可回收空间: %.2f MB\n' "$(awk "BEGIN {print ${reclaimable_kb} / 1024}")"
echo "IndexedDB 目标数量: $indexeddb_deleted"

if [[ "$APPLY" -eq 0 ]]; then
  echo
  echo "当前为预览模式，未执行删除。"
  echo "如确认无误，可使用 --apply 执行实际删除。"
  exit 0
fi

if [[ "${#candidate_paths[@]}" -eq 0 ]]; then
  echo
  echo "没有可删除的候选项。"
  exit 0
fi

echo
read -r -p "确认删除以上目录吗？(y/N): " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
  echo "已取消。"
  exit 0
fi

for i in "${!candidate_paths[@]}"; do
  rm -rf -- "${candidate_paths[$i]}"
done

echo "删除完成。"
