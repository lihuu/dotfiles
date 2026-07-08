#!/bin/sh
# 客户端附着后,把微信【主窗口】拉到屏幕左上角 (0,0),只动一次然后退出。
# 之后用户可自行拖动。这样无论微信记成什么离屏位置,启动都被拉回左上角。
#
# 只动"面积最大的微信窗口"(主窗口),自动排除 44x44 的托盘窗口,
# 避免触发 6.5.1 客户端的 ClientTray.move_resize 签名 bug。
#
# 用法: wechat-topleft.sh [:10]
set -u
DISPLAY_ARG="${1:-:10}"
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# 最多等 60 秒(等客户端附着 + 微信窗口出现)
for i in $(seq 1 60); do
    info=$(xpra info "$DISPLAY_ARG" 2>/dev/null) || info=""
    [ -z "$info" ] && { sleep 1; continue; }
    # 必须等客户端附着(有 client.0)再动,否则 move 是空操作还会提前退出
    echo "$info" | grep -aq "^client\.0\." || { sleep 1; continue; }

    best_wid=""; best_area=0
    # 枚举所有 class-instance 含 wechat 的窗口,挑面积最大的(= 主窗口)
    for wid in $(printf '%s\n' "$info" | grep -aE "windows\.[0-9]+\.class-instance" | grep -ai wechat | grep -oE "windows\.[0-9]+" | cut -d. -f2); do
        size=$(printf '%s\n' "$info" | grep -aE "^windows\.${wid}\.size=" | grep -oE "[0-9]+, [0-9]+")
        w=$(printf '%s\n' "$size" | cut -d, -f1 | tr -d " ")
        h=$(printf '%s\n' "$size" | cut -d, -f2 | tr -d " ")
        [ -z "$w" ] && continue
        area=$((w * h))
        if [ "$area" -gt "$best_area" ]; then
            best_area=$area
            best_wid=$wid
        fi
    done

    # 主窗口面积远大于托盘(44x44=1936);用 100000 阈值排除托盘
    if [ -n "$best_wid" ] && [ "$best_area" -gt 100000 ]; then
        xpra control "$DISPLAY_ARG" move "$best_wid" 0 0 >/dev/null 2>&1 && break
    fi
    sleep 1
done
