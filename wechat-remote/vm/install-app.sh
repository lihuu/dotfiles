#!/bin/bash
# Compile the OrbStack VM WeChat AppleScript launcher into a repo-local macOS app.
set -euo pipefail

APP_NAME="${ORBSTACK_WECHAT_APP_NAME:-OrbStack WeChat.app}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${ORBSTACK_WECHAT_APP_DIR:-$SCRIPT_DIR/apps}"
SOURCE="$SCRIPT_DIR/start.applescript"
APP_PATH="$APP_DIR/$APP_NAME"

command -v osacompile >/dev/null 2>&1 || {
  echo "错误:未找到 osacompile" >&2
  exit 1
}

mkdir -p "$APP_DIR"
rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "$SOURCE"

for icon in \
  "/Applications/WeChat.app/Contents/Resources/AppIcon.icns" \
  "/Applications/WeChat.app/Contents/Resources/app.icns"; do
  if [ -f "$icon" ]; then
    cp "$icon" "$APP_PATH/Contents/Resources/applet.icns"
    touch "$APP_PATH"
    break
  fi
done

echo "已生成: $APP_PATH"
echo "之后可以直接双击项目内的这个 app 启动 OrbStack VM 微信。"
