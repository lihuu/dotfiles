#!/bin/bash
# 通过 xpra 在 OrbStack Ubuntu VM 运行 Linux 微信，rootless 转发到 macOS 桌面。
# 详见 README.md
#
# 环境变量（均可选）：
#   ORBSTACK_WECHAT_MACHINE  OrbStack 机器名        (默认 ubuntu-24.04)
#   ORBSTACK_WECHAT_HOST     VM 主机名/IP           (默认 <machine>.orb.local)
#   ORBSTACK_WECHAT_USER     VM 用户                (默认 ${USER})
#   ORBSTACK_WECHAT_SSH_KEY  SSH 私钥               (默认 ~/.orbstack/ssh/id_ed25519)
#   ORBSTACK_WECHAT_DISPLAY  xpra 虚拟显示号         (默认 :10)
#   显示（自动适配 Retina/1x；换显示器重跑即可，一般无需手动设）：
#     ORBSTACK_WECHAT_SCALE        显示器 backing scale（2=Retina 2x，1=1x 屏）。默认自动探测
#     ORBSTACK_WECHAT_OPENGL       客户端 GL 合成，yes（默认，Retina 1:1 设备像素必需）
#     ORBSTACK_WECHAT_ENCODING     传输编码，rgb=无损原始像素（默认，本地带宽足够）
#     ORBSTACK_WECHAT_QT_FONT_DPI  wechat 字体 DPI（默认 96，配合 QT_SCALE_FACTOR，一般不改）

set -euo pipefail

VM_MACHINE="${ORBSTACK_WECHAT_MACHINE:-ubuntu-24.04}"
VM_USER="${ORBSTACK_WECHAT_USER:-${USER}}"
VM_HOST="${ORBSTACK_WECHAT_HOST:-${VM_MACHINE}.orb.local}"
SSH_KEY="${ORBSTACK_WECHAT_SSH_KEY:-$HOME/.orbstack/ssh/id_ed25519}"
XPRA_DISPLAY="${ORBSTACK_WECHAT_DISPLAY:-:10}"
XPRA_APP="/Applications/Xpra.app/Contents/MacOS/Xpra"
DISPLAY_NUM="${XPRA_DISPLAY#:}"   # 去掉冒号，用于 ssh URL path

# 探测 macOS 主显示器 backing scale = 物理宽 / 逻辑宽。
#   Retina 2x（4K@1080p 缩放）→ 2，1x 外接屏 → 1。
# 原理：xpra 的 macOS 客户端只把【逻辑分辨率】报给服务端，2x backing scale 不传 ——
#       所以 Linux 侧不知道是 HiDPI，必须我们在 Mac 侧自己算出来喂给 xpra + wechat。
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

# S = backing scale。xpra desktop-scaling = 1/S（让服务端按 S×物理像素渲染）；
# wechat 是静态链接 Qt 的自研应用，QT_SCALE_FACTOR = S（让窗口也放大 S×，否则固定像素窗口会变小）。
WECHAT_SCALE="${ORBSTACK_WECHAT_SCALE:-$(detect_backing_scale)}"
WECHAT_SCALING=$(awk -v s="$WECHAT_SCALE" 'BEGIN{printf "%g",1/s}')   # --desktop-scaling = 1/S
WECHAT_QT_SCALE="$WECHAT_SCALE"                                       # wechat QT_SCALE_FACTOR = S
WECHAT_QT_FONT_DPI="${ORBSTACK_WECHAT_QT_FONT_DPI:-96}"
WECHAT_ENCODING="${ORBSTACK_WECHAT_ENCODING:-rgb}"
WECHAT_OPENGL="${ORBSTACK_WECHAT_OPENGL:-yes}"

# 前置检查
command -v orb >/dev/null 2>&1 || { echo "错误：未找到 orb（OrbStack CLI）" >&2; exit 1; }
[ -x "$XPRA_APP" ] || { echo "错误：未找到 xpra 客户端 $XPRA_APP（先 brew install --cask xpra）" >&2; exit 1; }
[ -f "$SSH_KEY" ] || { echo "错误：未找到 SSH 私钥 $SSH_KEY" >&2; exit 1; }

echo "==> 显示器 backing scale=${WECHAT_SCALE} → desktop-scaling=${WECHAT_SCALING}, wechat QT_SCALE_FACTOR=${WECHAT_QT_SCALE}"

# 1. 确保 VM 上 xpra 会话已启动（幂等）
echo "==> 检查 VM xpra 会话 ${XPRA_DISPLAY} ..."
if orb -m "$VM_MACHINE" bash -lc "xpra list 2>/dev/null | grep -q 'LIVE session at ${XPRA_DISPLAY}'"; then
  echo "==> 会话已在运行，跳过启动"
else
  echo "==> 启动新会话（fcitx5 + wechat，强制 fcitx 输入法 + Qt HiDPI 缩放）..."
  # env 包装的两个原因（xpra 给 --start 命令注入环境，必须显式覆盖）：
  #   1) 注入 *_IM_MODULE=ibus → 用 env 强制 fcitx
  #   2) 注入 QT_SCALE_FACTOR=1 → 禁用 wechat 自带 HiDPI，导致窗口变小；用 env 覆盖成 S
  # wechat Qt 缩放三件套：
  #   QT_SCALE_FACTOR=S            UI 放大 S×（窗口/布局按设备像素开）
  #   QT_FONT_DPI=96               字体 DPI 从屏幕 144 解耦，否则与 QT_SCALE_FACTOR 叠加过冲
  #   QT_AUTO_SCREEN_SCALE_FACTOR=0 关闭不可靠的自动（依赖 DPI 阈值，144 会被向下取整成 1×）
  orb -m "$VM_MACHINE" bash -lc '
    export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx
    xpra start '"${XPRA_DISPLAY}"' \
      --start="fcitx5 -d" \
      --start="env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx QT4_IM_MODULE=fcitx XMODIFIERS=@im=fcitx CLUTTER_IM_MODULE=fcitx QT_SCALE_FACTOR='"${WECHAT_QT_SCALE}"' QT_FONT_DPI='"${WECHAT_QT_FONT_DPI}"' QT_AUTO_SCREEN_SCALE_FACTOR=0 wechat" \
      --exit-with-client=no
  ' >&2
  # 等待会话与 wechat 起来
  for _ in $(seq 1 20); do
    orb -m "$VM_MACHINE" bash -lc "xpra list 2>/dev/null | grep -q 'LIVE session at ${XPRA_DISPLAY}'" && break
    sleep 0.5
  done
fi

# 2. macOS 侧 attach
# XPRA_OSX_SHOW_MENU_DEFAULT=0：禁用 macOS 全局菜单，避免 gtkmacintegration 非主线程崩溃。
# 显示三件套（原理：服务端按 Retina 物理像素渲染，客户端 1:1 合成，全程无损）：
#   --desktop-scaling=1/S   客户端报 S×物理分辨率给服务端（2x→7680x2160），wechat 按设备像素渲染
#   --opengl=yes            客户端 GL 按设备像素 1:1 合成，不走 CoreGraphics 线性放大
#   --encoding=rgb          本地无损传输，杜绝有损编码模糊
echo "==> 从 macOS 附加 ${VM_USER}@${VM_HOST}/${DISPLAY_NUM}（菜单已禁用，scaling=${WECHAT_SCALING} opengl=${WECHAT_OPENGL} encoding=${WECHAT_ENCODING}）..."
exec env XPRA_OSX_SHOW_MENU_DEFAULT=0 "$XPRA_APP" attach \
  --opengl="${WECHAT_OPENGL}" \
  --desktop-scaling="${WECHAT_SCALING}" \
  --encoding="${WECHAT_ENCODING}" \
  --ssh="ssh -i ${SSH_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  "ssh://${VM_USER}@${VM_HOST}/${DISPLAY_NUM}"
