#!/bin/bash
# 容器入口:启 D-Bus 会话 → xpra 虚拟显示 :10 → fcitx5 + wechat。
# 详见 ../README.md
set -euo pipefail

# HiDPI:由 start 脚本按 Mac backing scale 注入 QT_SCALE_FACTOR(默认 2)。
# QT_FONT_DPI=96 把字体 DPI 从屏幕解耦,避免与 QT_SCALE_FACTOR 叠加过冲。
# QT_AUTO_SCREEN_SCALE_FACTOR=0 关闭不可靠的自动(144 DPI 会被向下取整成 1×)。
QT_SCALE_FACTOR="${QT_SCALE_FACTOR:-2}"
QT_FONT_DPI="${QT_FONT_DPI:-96}"
XPRA_DISPLAY="${XPRA_DISPLAY:-:10}"
TCP_BIND="${TCP_BIND:-0.0.0.0:14500}"

mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# 首次运行(volume 空)时种入 fcitx5 默认配置(拼音 + Ctrl+` + 默认中文)
if [ ! -f "$HOME/.config/fcitx5/profile" ]; then
  mkdir -p "$HOME/.config/fcitx5"
  cp -a /etc/fcitx5-seed/. "$HOME/.config/fcitx5/"
fi

# 启动 D-Bus session bus(固定地址)。
# 关键:xpra 启动 --start 子进程时会【剥离】DBUS_SESSION_BUS_ADDRESS(与注入 QT_SCALE_FACTOR=1 同类问题),
# 导致 fcitx5 与 wechat 无法经 D-Bus 通信 → QT_IM_MODULE=fcitx 失效 → 无中文输入。
# 故用固定地址 + 在 --start 的 env 里显式注入,确保两者共享同一 session bus。
DBUS_ADDR="unix:path=$XDG_RUNTIME_DIR/dbus-session"
rm -f "$XDG_RUNTIME_DIR/dbus-session"
dbus-daemon --session --address="$DBUS_ADDR" --nofork --nopidfile &
sleep 0.3
export DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR"
export XPRA_FRAME_EXTENTS=0

# 用 env -i 启动 fcitx5/wechat,避免 xpra 默认 start-env 注入 MWWM/QT_SCALE_FACTOR=1 等变量。
# XPRA_FRAME_EXTENTS=0 配合镜像里的 frame-extents capability patch,避免 macOS 客户端 frame
# 回写到微信无边框窗口,否则顶部 64px 区域会拦截自绘标题栏拖动。
COMMON_ENV="HOME=$HOME USER=wechat LOGNAME=wechat PATH=/usr/local/bin:/usr/bin:/bin DISPLAY=$XPRA_DISPLAY XAUTHORITY=$HOME/.Xauthority XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx QT4_IM_MODULE=fcitx XMODIFIERS=@im=fcitx CLUTTER_IM_MODULE=fcitx LANG=$LANG LC_ALL=$LC_ALL"

# wechat Qt 缩放三件套 + DBUS_ADDR 一起注入 --start。
# xpra --daemon=no 前台运行作为容器 PID 1;--exit-with-client=no 让会话在客户端断开后仍在。
exec xpra start "$XPRA_DISPLAY" \
  --bind-tcp="$TCP_BIND" \
  --tcp-auth=none \
  --mdns=no \
  --start="env -i $COMMON_ENV fcitx5 -d" \
  --start="env -i $COMMON_ENV QT_SCALE_FACTOR=$QT_SCALE_FACTOR QT_FONT_DPI=$QT_FONT_DPI QT_AUTO_SCREEN_SCALE_FACTOR=0 wechat" \
  --exit-with-client=no \
  --daemon=no
