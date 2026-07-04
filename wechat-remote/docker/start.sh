#!/bin/bash
# 通过 Docker 容器(xpra + fcitx5 + Linux 微信)运行微信,rootless 转发到 macOS 桌面。
# 与 ../vm/start.sh(OrbStack VM 方案)并行,互不影响。
# 详见 README.md
#
# 环境变量(均可选):
#   WECHAT_DOCKER_IMAGE     镜像名          (默认 wechat-xpra)
#   WECHAT_DOCKER_CONTAINER 容器名          (默认 wechat-xpra)
#   WECHAT_DOCKER_PORT      xpra TCP 端口   (默认 14501,避开 OrbStack VM 的 14500)
#   WECHAT_DOCKER_DATA      微信数据 volume  (默认 wechat-xpra-data)
#   显示(自动适配 Retina/1x;换显示器重跑即可):
#     WECHAT_SCALE         显示器 backing scale(2=Retina 2x,1=1x 屏)。默认自动探测
#     WECHAT_OPENGL        客户端 GL 合成(默认 yes,Retina 1:1 设备像素必需)
#     WECHAT_ENCODING      传输编码(默认 rgb=无损原始像素)
#     WECHAT_QT_FONT_DPI   wechat 字体 DPI(默认 96,配合 QT_SCALE_FACTOR)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$SCRIPT_DIR/image"
IMAGE="${WECHAT_DOCKER_IMAGE:-wechat-xpra}"
CONTAINER="${WECHAT_DOCKER_CONTAINER:-wechat-xpra}"
PORT="${WECHAT_DOCKER_PORT:-14501}"
DATA_VOLUME="${WECHAT_DOCKER_DATA:-wechat-xpra-data}"
XPRA_APP="/Applications/Xpra.app/Contents/MacOS/Xpra"

# 探测 macOS 主显示器 backing scale = 物理宽 / 逻辑宽。
# 原理与 ../vm/start.sh 相同:xpra macOS 客户端只报逻辑分辨率,
# 2x backing 不传,必须在 Mac 侧自己算喂给 xpra(--desktop-scaling)和 wechat(QT_SCALE_FACTOR)。
detect_backing_scale() {
  local sp phys logical
  sp=$(system_profiler SPDisplaysDataType 2>/dev/null) || { echo 2; return; }
  phys=$(printf '%s\n' "$sp" | awk '/Resolution:/{print $2; exit}')
  logical=$(printf '%s\n' "$sp" | awk '/UI Looks like:/{print $4; exit}')
  [ -n "$logical" ] || logical="$phys"   # 1x 屏无 "UI Looks like" 行 → 逻辑=物理 → scale 1
  if [ -n "$phys" ] && [ -n "$logical" ] && [ "$logical" -gt 0 ] 2>/dev/null; then
    awk -v p="$phys" -v l="$logical" 'BEGIN{r=p/l; printf "%d\n",(r-int(r)>=0.5?int(r)+1:int(r))}'
  else
    echo 2
  fi
}

SCALE="${WECHAT_SCALE:-$(detect_backing_scale)}"
SCALING=$(awk -v s="$SCALE" 'BEGIN{printf "%g",1/s}')   # --desktop-scaling = 1/S
QT_FONT_DPI="${WECHAT_QT_FONT_DPI:-96}"
ENCODING="${WECHAT_ENCODING:-rgb}"
OPENGL="${WECHAT_OPENGL:-yes}"

# 前置检查
command -v docker >/dev/null 2>&1 || { echo "错误:未找到 docker" >&2; exit 1; }
[ -x "$XPRA_APP" ] || { echo "错误:未找到 xpra 客户端 $XPRA_APP(先 brew install --cask xpra)" >&2; exit 1; }

echo "==> 显示器 backing scale=${SCALE} → desktop-scaling=${SCALING}, wechat QT_SCALE_FACTOR=${SCALE}"

# 1) 构建镜像(若不存在)
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> 镜像 ${IMAGE} 不存在,开始构建(需先放好 ${IMAGE_DIR}/wechat.deb)..."
  docker build -t "$IMAGE" "$IMAGE_DIR"
fi

# 2) 启动容器(若未运行)
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "==> 启动容器 ${CONTAINER}(本机端口 127.0.0.1:${PORT},数据 volume ${DATA_VOLUME},shm 256m)..."
  docker run -d --name "$CONTAINER" \
    --restart unless-stopped \
    --shm-size 256m \
    -p "127.0.0.1:${PORT}:14500" \
    -v "${DATA_VOLUME}:/home/wechat" \
    -e "QT_SCALE_FACTOR=${SCALE}" \
    -e "QT_FONT_DPI=${QT_FONT_DPI}" \
    "$IMAGE"
  # 等 xpra 会话起来
  for _ in $(seq 1 30); do
    docker exec "$CONTAINER" bash -lc "xpra list 2>/dev/null | grep -q 'LIVE session at :10'" && break
    sleep 0.5
  done
else
  echo "==> 容器已在运行(注:wechat QT_SCALE_FACTOR 在容器创建时固定;换屏要改 scale 需 docker rm -f 后重跑)"
fi

# 3) macOS 侧 attach(TCP,无需 SSH/密钥;desktop-scaling 客户端侧,每次 attach 都按当前 scale 生效)
echo "==> 从 macOS 附加 tcp:localhost:${PORT}(scaling=${SCALING} opengl=${OPENGL} encoding=${ENCODING})..."
exec env XPRA_OSX_SHOW_MENU_DEFAULT=0 "$XPRA_APP" attach \
  --opengl="${OPENGL}" \
  --desktop-scaling="${SCALING}" \
  --encoding="${ENCODING}" \
  "tcp:localhost:${PORT}"
