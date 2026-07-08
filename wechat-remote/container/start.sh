#!/bin/bash
# 通过 Apple container(xpra + fcitx5 + Linux 微信)运行微信,rootless 转发到 macOS 桌面。
# 复用 ../docker/image 里的镜像构建上下文,但运行时使用 macOS 自带 container CLI。
# 详见 README.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_DIR="$REMOTE_DIR/docker/image"

IMAGE="${WECHAT_CONTAINER_IMAGE:-wechat-xpra}"
CONTAINER_NAME="${WECHAT_CONTAINER_NAME:-wechat-container-xpra}"
PORT="${WECHAT_CONTAINER_PORT:-14503}"
DATA_VOLUME="${WECHAT_CONTAINER_DATA:-wechat-container-data}"
QT_FONT_DPI="${WECHAT_QT_FONT_DPI:-96}"
ENCODING="${WECHAT_ENCODING:-rgb}"
OPENGL="${WECHAT_OPENGL:-yes}"
CURSORS="${WECHAT_CURSORS:-no}"
XPRA_APP="/Applications/Xpra.app/Contents/MacOS/Xpra"

find_container_bin() {
  if [ -n "${CONTAINER_BIN:-}" ]; then
    printf '%s\n' "$CONTAINER_BIN"
    return
  fi

  if [ -x /opt/homebrew/bin/container ]; then
    printf '%s\n' /opt/homebrew/bin/container
    return
  fi

  local cellar_bin
  cellar_bin="$(ls -1d /opt/homebrew/Cellar/container/*/bin/container 2>/dev/null | tail -n 1 || true)"
  if [ -n "$cellar_bin" ] && [ -x "$cellar_bin" ]; then
    printf '%s\n' "$cellar_bin"
    return
  fi

  command -v container 2>/dev/null || true
}

detect_backing_scale() {
  local sp phys logical
  sp=$(system_profiler SPDisplaysDataType 2>/dev/null) || { echo 2; return; }
  phys=$(printf '%s\n' "$sp" | awk '/Resolution:/{print $2; exit}')
  logical=$(printf '%s\n' "$sp" | awk '/UI Looks like:/{print $4; exit}')
  [ -n "$logical" ] || logical="$phys"
  if [ -n "$phys" ] && [ -n "$logical" ] && [ "$logical" -gt 0 ] 2>/dev/null; then
    awk -v p="$phys" -v l="$logical" 'BEGIN{r=p/l; printf "%d\n",(r-int(r)>=0.5?int(r)+1:int(r))}'
  else
    echo 2
  fi
}

CONTAINER_BIN_RESOLVED="$(find_container_bin)"
[ -n "$CONTAINER_BIN_RESOLVED" ] || { echo "错误:未找到 Apple container CLI" >&2; exit 1; }
[ -x "$XPRA_APP" ] || { echo "错误:未找到 xpra 客户端 $XPRA_APP(先 brew install --cask xpra)" >&2; exit 1; }

CONTAINER_VERSION="$("$CONTAINER_BIN_RESOLVED" --version 2>/dev/null || true)"
case "$CONTAINER_VERSION" in
  *" 1."*|*" version 1."*) ;;
  *)
    echo "错误:container CLI 版本过旧或无法识别: ${CONTAINER_VERSION:-unknown}" >&2
    echo "当前 Apple container 服务端需要 1.x CLI。可通过 CONTAINER_BIN 指定 /opt/homebrew/Cellar/container/*/bin/container。" >&2
    exit 1
    ;;
esac

SCALE="${WECHAT_SCALE:-$(detect_backing_scale)}"
SCALING=$(awk -v s="$SCALE" 'BEGIN{printf "%g",1/s}')

echo "==> 使用 container CLI: $CONTAINER_BIN_RESOLVED ($CONTAINER_VERSION)"
echo "==> 显示器 backing scale=${SCALE} -> desktop-scaling=${SCALING}, wechat QT_SCALE_FACTOR=${SCALE}"

if ! "$CONTAINER_BIN_RESOLVED" system status >/dev/null 2>&1; then
  echo "==> 启动 Apple container system ..."
  "$CONTAINER_BIN_RESOLVED" system start
fi

if ! "$CONTAINER_BIN_RESOLVED" image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> 镜像 ${IMAGE} 不存在,开始构建(需先放好 ${IMAGE_DIR}/wechat.deb)..."
  "$CONTAINER_BIN_RESOLVED" builder start >/dev/null 2>&1 || true
  "$CONTAINER_BIN_RESOLVED" build --platform linux/arm64 -t "$IMAGE" "$IMAGE_DIR"
fi

if ! "$CONTAINER_BIN_RESOLVED" volume list | awk 'NR>1{print $1}' | grep -qx "$DATA_VOLUME"; then
  echo "==> 创建 Apple container volume: ${DATA_VOLUME}"
  "$CONTAINER_BIN_RESOLVED" volume create "$DATA_VOLUME" >/dev/null
fi

if ! "$CONTAINER_BIN_RESOLVED" run --rm \
  -v "${DATA_VOLUME}:/home/wechat" \
  --entrypoint /bin/bash \
  "$IMAGE" -lc 'test -w /home/wechat' >/dev/null 2>&1; then
  echo "==> 修正 volume ${DATA_VOLUME} 的 /home/wechat 权限(Apple container 首次需要)..."
  "$CONTAINER_BIN_RESOLVED" run --rm \
    --user root \
    --entrypoint /bin/bash \
    -v "${DATA_VOLUME}:/home/wechat" \
    "$IMAGE" -lc 'chown -R wechat:wechat /home/wechat && chmod 700 /home/wechat'
fi

STATE="$("$CONTAINER_BIN_RESOLVED" list --all | awk -v name="$CONTAINER_NAME" '$1==name{print $5; found=1} END{if(!found) print ""}')"
if [ "$STATE" = "running" ]; then
  echo "==> 容器已在运行: ${CONTAINER_NAME}"
elif [ -n "$STATE" ]; then
  echo "==> 启动已存在容器 ${CONTAINER_NAME}(state=${STATE}) ..."
  "$CONTAINER_BIN_RESOLVED" start "$CONTAINER_NAME"
else
  echo "==> 创建并启动容器 ${CONTAINER_NAME}(127.0.0.1:${PORT}->14500, volume ${DATA_VOLUME}) ..."
  "$CONTAINER_BIN_RESOLVED" run -d --name "$CONTAINER_NAME" \
    -p "127.0.0.1:${PORT}:14500" \
    -v "${DATA_VOLUME}:/home/wechat" \
    -e "QT_SCALE_FACTOR=${SCALE}" \
    -e "QT_FONT_DPI=${QT_FONT_DPI}" \
    "$IMAGE"
fi

for _ in $(seq 1 30); do
  "$CONTAINER_BIN_RESOLVED" exec "$CONTAINER_NAME" xpra list 2>/dev/null | grep -q 'LIVE session at :10' && break
  sleep 0.5
done

echo "==> 从 macOS 附加 tcp:localhost:${PORT}(scaling=${SCALING} opengl=${OPENGL} encoding=${ENCODING} cursors=${CURSORS})..."
exec env XPRA_OSX_SHOW_MENU_DEFAULT=0 "$XPRA_APP" attach \
  --opengl="${OPENGL}" \
  --desktop-scaling="${SCALING}" \
  --encoding="${ENCODING}" \
  --cursors="${CURSORS}" \
  "tcp:localhost:${PORT}"
