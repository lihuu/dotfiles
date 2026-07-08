# Linux 微信 + xpra + fcitx5,跑在 Docker 容器里,经 xpra TCP 转发到 macOS 桌面。
# 与 OrbStack VM 方案(../vm/start.sh)并行,互不影响。
# 详见 ../README.md
#
# 构建(Apple Silicon 原生 arm64,无模拟):
#   # 1. 先下载微信 arm64 deb,放到 wechat-remote/docker/image/wechat.deb
#   #    官方下载页:https://linux.weixin.qq.com/(选 arm64 deb)
#   docker build -t wechat-xpra wechat-remote/docker/image
#
# 关键点:
#   - xpra 必须用 xpra.org 仓库的 6.x(Ubuntu 自带 3.1.5 与 Mac 客户端 6.5 不兼容)
#   - wechat 是静态链接 Qt 的自研应用,HiDPI 由 QT_SCALE_FACTOR 三件套控制
#   - fcitx5/wechat 需要 D-Bus session bus → entrypoint 启动固定地址 dbus-daemon
#   - 不需要 --privileged:xpra 自带 Xvfb 虚拟显示,不碰宿主 X/GPU

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai

# 1) xpra.org 仓库 + xpra 6.x(关键:不能用 Ubuntu 仓库的 3.1.5)
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates gnupg && \
    install -d /usr/share/keyrings && \
    curl -fsSL https://xpra.org/xpra.gpg -o /usr/share/keyrings/xpra-archive-keyring.gpg && \
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/xpra-archive-keyring.gpg] https://xpra.org/ noble main" \
      > /etc/apt/sources.list.d/xpra.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends xpra xpra-x11 xvfb && \
    xpra --version

# xpra 6.x 会向客户端宣告 window.frame-extents capability。macOS 客户端随后把
# 原生窗口顶部 frame 回传给服务端,微信这类 decorations=0 的自绘标题栏窗口会因此多出
# 64px 顶部命中区域。关闭 frame-extents 后,微信仍然是无原生标题栏窗口,其自绘标题栏
# 在 Docker/xpra 组合下不能发起移动。Docker 版对 WM_CLASS=wechat 的窗口强制上报
# decorations=1,让 macOS 外层标题栏负责拖动。
RUN python3 - <<'PY'
from pathlib import Path

path = Path("/usr/lib/python3/dist-packages/xpra/x11/server/seamless.py")
text = path.read_text()
old = '"frame-extents": True,'
new = '"frame-extents": False,'
if old not in text:
    raise SystemExit(f"xpra frame-extents patch target not found in {path}")
path.write_text(text.replace(old, new, 1))

path = Path("/usr/lib/python3/dist-packages/xpra/server/window/metadata.py")
text = path.read_text()
old = '''    if propname in DEFAULT_VALUES:
        v = raw()
        if skip_defaults and v in (DEFAULT_VALUES[propname], None):
            return {}
        return {propname: v}
'''
new = '''    if propname in DEFAULT_VALUES:
        v = raw()
        if propname == "decorations":
            class_instance = window.get_property("class-instance") or ("", "")
            if tuple(str(x).lower() for x in class_instance) == ("wechat", "wechat"):
                v = 1
        if skip_defaults and v in (DEFAULT_VALUES[propname], None):
            return {}
        return {propname: v}
'''
if old not in text:
    raise SystemExit(f"xpra decorations patch target not found in {path}")
path.write_text(text.replace(old, new, 1))
PY

# 2) fcitx5 + 中文输入 + CJK 字体 + locale + dbus(dbus-x11 提供 dbus-daemon)
#    附带 wechat 运行时依赖(deb 声明不全,ldd 查出的缺失 .so 对应的包)
RUN apt-get install -y --no-install-recommends \
      fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 \
      fonts-noto-cjk locales dbus-x11 python3-dbus im-config x11-utils xdotool \
      libatomic1 libpulse0 libxcb-image0 libxcb-render-util0 \
      libnss3 libnspr4 libasound2t64 && \
    locale-gen zh_CN.UTF-8

# 3) Linux 微信 arm64 deb(构建前需放入 wechat-remote/docker/image/wechat.deb)
#    dpkg -i 装上,缺依赖用 apt-get install -f 自动补齐;末尾 ldd 自检无缺失 .so。
#    包列表在这里清(rm -rf /var/lib/apt/lists/*),前面步骤共用步骤1的 update。
ARG WECHAT_DEB=wechat.deb
COPY ${WECHAT_DEB} /tmp/wechat.deb
RUN dpkg -i /tmp/wechat.deb || apt-get install -y -f --no-install-recommends && \
    rm -f /tmp/wechat.deb && rm -rf /var/lib/apt/lists/* && \
    test -x /opt/wechat/wechat && \
    ! ldd /opt/wechat/wechat | grep -i 'not found'

# 4) 非 root 用户(微信数据持久化用);fcitx5 种子配置(root 只读,entrypoint 拷到 $HOME)
RUN useradd -m -s /bin/bash wechat
COPY fcitx5/ /etc/fcitx5-seed/

# 5) entrypoint + wechat popup watcher
COPY wechat-popup-watcher.sh /usr/local/bin/wechat-popup-watcher
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/wechat-popup-watcher

USER wechat
ENV HOME=/home/wechat \
    XDG_RUNTIME_DIR=/tmp/runtime-wechat
RUN mkdir -p /tmp/runtime-wechat && chmod 700 /tmp/runtime-wechat

EXPOSE 14500
ENTRYPOINT ["/entrypoint.sh"]
