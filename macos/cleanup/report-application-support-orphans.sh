#!/usr/bin/env bash

set -euo pipefail

APP_SUPPORT_DIR="$HOME/Library/Application Support"
AGE_THRESHOLD_DAYS="${AGE_THRESHOLD_DAYS:-180}"
SIZE_THRESHOLD_MB="${SIZE_THRESHOLD_MB:-20}"
HIGH_SIZE_THRESHOLD_MB="${HIGH_SIZE_THRESHOLD_MB:-50}"
REPORT_LIMIT="${REPORT_LIMIT:-60}"

INSTALLED_NAMES_FILE=""

normalize_name() {
  tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

du_kb() {
  local value
  value="$(du -sk "$1" 2>/dev/null | awk 'NR == 1 {print $1}')"
  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo 0
  fi
}

age_days() {
  local path="$1"
  local mtime now
  mtime="$(stat -f %m "$path" 2>/dev/null || true)"
  if [[ -z "$mtime" ]]; then
    echo -1
    return 0
  fi
  now="$(date +%s)"
  echo $(( (now - mtime) / 86400 ))
}

collect_installed_apps() {
  local roots=(
    "/Applications"
    "/System/Applications"
    "$HOME/Applications"
  )

  local root app_bundle app_base norm plist value
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' app_bundle; do
      app_base="$(basename "$app_bundle")"
      norm="$(printf '%s' "${app_base%.app}" | normalize_name)"
      [[ -n "$norm" ]] || continue
      printf '%s\n' "$norm" >>"$INSTALLED_NAMES_FILE"

      plist="$app_bundle/Contents/Info.plist"
      if [[ -f "$plist" ]]; then
        for key in CFBundleDisplayName CFBundleName CFBundleIdentifier; do
          value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true)"
          if [[ -n "$value" ]]; then
            printf '%s\n' "$(printf '%s' "$value" | normalize_name)" >>"$INSTALLED_NAMES_FILE"
          fi
        done
      fi
    done < <(find "$root" -maxdepth 2 -type d -name '*.app' -print0 2>/dev/null)
  done
}

looks_supported_by_installed_apps() {
  local name="$1"
  local norm
  norm="$(printf '%s' "$name" | normalize_name)"
  if grep -Fxq "$norm" "$INSTALLED_NAMES_FILE"; then
    return 0
  fi

  while IFS= read -r installed; do
    [[ -n "$installed" ]] || continue
    if [[ "$installed" == *"$norm"* || "$norm" == *"$installed"* ]]; then
      return 0
    fi
  done <"$INSTALLED_NAMES_FILE"

  return 1
}

severity_for() {
  local size_kb="$1"
  local age="$2"

  if (( size_kb >= HIGH_SIZE_THRESHOLD_MB * 1024 || age >= AGE_THRESHOLD_DAYS )); then
    echo "HIGH"
  elif (( size_kb >= SIZE_THRESHOLD_MB * 1024 || age >= 90 )); then
    echo "MEDIUM"
  else
    echo "LOW"
  fi
}

if [[ ! -d "$APP_SUPPORT_DIR" ]]; then
  echo "未找到目录: $APP_SUPPORT_DIR"
  exit 1
fi

tmp_report=""
INSTALLED_NAMES_FILE="$(mktemp)"
trap 'rm -f "$tmp_report" "$INSTALLED_NAMES_FILE"' EXIT

collect_installed_apps
sort -u -o "$INSTALLED_NAMES_FILE" "$INSTALLED_NAMES_FILE"

tmp_report="$(mktemp)"

total_dirs=0
matched_dirs=0
suspect_dirs=0

while IFS= read -r -d '' item; do
  [[ -d "$item" ]] || continue
  ((total_dirs++))

  base_name="$(basename "$item")"
  case "$base_name" in
    com.apple.*|Apple|Caches)
      continue
      ;;
  esac
  if looks_supported_by_installed_apps "$base_name"; then
    ((matched_dirs++))
    continue
  fi

  size_kb="$(du_kb "$item")"
  size_mb="$(awk "BEGIN {printf \"%.1f\", ${size_kb}/1024}")"
  item_age_days="$(age_days "$item")"
  if (( item_age_days < 0 )); then
    printf '跳过不可访问目录: %s\n' "$item"
    continue
  fi
  severity="$(severity_for "$size_kb" "$item_age_days")"

  if [[ "$severity" == "LOW" ]]; then
    continue
  fi

  reason_parts=()
  if (( size_kb >= SIZE_THRESHOLD_MB * 1024 )); then
    reason_parts+=("size>=${SIZE_THRESHOLD_MB}MB")
  fi
  if (( item_age_days >= AGE_THRESHOLD_DAYS )); then
    reason_parts+=("age>=${AGE_THRESHOLD_DAYS}d")
  fi
  if (( ${#reason_parts[@]} == 0 )); then
    reason_parts+=("name-not-matched")
  fi

  ((suspect_dirs++))
  printf '%s\t%09d\t%s\t%s\t%s\t%s\n' \
    "$severity" \
    "$size_kb" \
    "$size_mb MB" \
    "${item_age_days}d" \
    "$item" \
    "${reason_parts[*]}" >>"$tmp_report"
done < <(find "$APP_SUPPORT_DIR" -mindepth 1 -maxdepth 1 -print0)

echo "Application Support 残留检测报告"
echo "扫描目录: $APP_SUPPORT_DIR"
echo "已安装 App 参考数: $(wc -l <"$INSTALLED_NAMES_FILE" | tr -d ' ')"
echo "扫描到的顶层目录数: $total_dirs"
echo "命中已安装 App 名称的目录数: $matched_dirs"
echo "疑似残留候选数: $suspect_dirs"
echo

if [[ ! -s "$tmp_report" ]]; then
  echo "没有发现满足当前阈值的疑似残留项。"
  exit 0
fi

echo "按严重度和体积排序的候选项:"
{
  echo -e "SEVERITY\tSIZE_KB\tSIZE\tAGE\tPATH\tREASONS"
  sort -t $'\t' -k1,1 -k2,2nr "$tmp_report"
} | awk -F'\t' -v limit="$REPORT_LIMIT" '
  NR == 1 { print; next }
  count < limit {
    printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6
    count++
  }
'

echo
echo "说明:"
echo "- HIGH: 更像卸载残留，通常满足大体积或长期未修改"
echo "- MEDIUM: 需要人工确认，不建议直接删"
echo "- 该报告只检查 Application Support 顶层目录，未做自动删除"
echo "- 不可访问的受保护目录会被跳过"
