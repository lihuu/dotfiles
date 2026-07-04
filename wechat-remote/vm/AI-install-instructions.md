# AI Install Instructions: VM Scheme

本文面向接手执行的 AI agent。目标是在 macOS 上通过 OrbStack Ubuntu VM 运行
Linux 微信,再用 xpra rootless 模式把窗口转发到 macOS 桌面。

优先使用本方案。它是当前体验基线:窗口拖动、中文输入、Retina 清晰度和断线重连都已
验证较好。

## 1. 目标状态

完成后应满足:

- macOS 已安装 `/Applications/Xpra.app/Contents/MacOS/Xpra`。
- OrbStack Ubuntu 24.04 arm64 VM 可用,默认机器名为 `ubuntu-24.04`。
- VM 内已安装 Linux 微信、xpra 6.x、fcitx5、CJK 字体和运行依赖。
- macOS 可以通过 OrbStack SSH key 直连 `ubuntu-24.04.orb.local`。
- 运行 `./wechat-remote/vm/start.sh` 可以启动或复用 VM 内 xpra 会话,并在 macOS 上显示微信窗口。
- 可选:运行 `./wechat-remote/vm/install-app.sh` 生成项目内 applet。

## 2. AI 执行约束

- 不要提交微信 deb 安装包、微信数据目录、app bundle 或任何账号数据。
- 不要修改用户无关文件。当前方案文件只应位于 `wechat-remote/vm/`。
- 涉及重装、删除 VM、删除用户数据前必须停下来确认。
- 如果当前机器没有 OrbStack VM,先让用户确认创建哪台 Ubuntu 机器;不要猜测删除或替换已有机器。
- 如果命令需要安装软件或启动 GUI,在 Codex 环境中按工具要求申请权限。

## 3. 变量约定

以下命令默认从仓库根目录执行。如果已经在仓库内,可用 Git 解析根目录:

```bash
cd "$(git rev-parse --show-toplevel)"
```

可按实际环境覆盖:

```bash
export ORBSTACK_WECHAT_MACHINE="${ORBSTACK_WECHAT_MACHINE:-ubuntu-24.04}"
export ORBSTACK_WECHAT_HOST="${ORBSTACK_WECHAT_HOST:-${ORBSTACK_WECHAT_MACHINE}.orb.local}"
export ORBSTACK_WECHAT_USER="${ORBSTACK_WECHAT_USER:-$USER}"
export ORBSTACK_WECHAT_SSH_KEY="${ORBSTACK_WECHAT_SSH_KEY:-$HOME/.orbstack/ssh/id_ed25519}"
export ORBSTACK_WECHAT_DISPLAY="${ORBSTACK_WECHAT_DISPLAY:-:10}"
export WECHAT_DEB="${WECHAT_DEB:-$HOME/Downloads/WeChatLinux_arm64.deb}"
```

## 4. macOS 前置检查

```bash
command -v orb
command -v brew
test -f "$WECHAT_DEB"
test -f "$ORBSTACK_WECHAT_SSH_KEY"
test -f "$ORBSTACK_WECHAT_SSH_KEY.pub"
```

安装或修复 macOS xpra 客户端:

```bash
brew install --cask xpra
xattr -dr com.apple.quarantine /Applications/Xpra.app
test -x /Applications/Xpra.app/Contents/MacOS/Xpra
```

说明:

- 必须用 `/Applications/Xpra.app/Contents/MacOS/Xpra`。
- 不要用 `/opt/homebrew/bin/xpra`,它可能找不到 app bundle 的 `Contents/`。

## 5. VM 前置检查

确认 VM 可运行命令:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" uname -a
orb -m "$ORBSTACK_WECHAT_MACHINE" uname -m
```

期望架构是 `aarch64` 或 `arm64`。如果 VM 不存在,需要先通过 OrbStack 创建 Ubuntu
24.04 arm64 机器,并让 `ORBSTACK_WECHAT_MACHINE` 指向实际机器名。

## 6. 安装 Linux 微信

把本机 deb 通过 stdin 写入 VM,再安装:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" -u root bash -lc 'cat > /tmp/wechat.deb' < "$WECHAT_DEB"

orb -m "$ORBSTACK_WECHAT_MACHINE" -u root bash -lc '
  set -e
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates curl fonts-noto-cjk locales \
    libatomic1 libpulse0 libxcb-image0 libxcb-render-util0 \
    libnss3 libnspr4 libasound2t64
  locale-gen zh_CN.UTF-8 || true
  dpkg -i /tmp/wechat.deb || apt-get install -y -f --no-install-recommends
  rm -f /tmp/wechat.deb
  test -x /opt/wechat/wechat
  ! ldd /opt/wechat/wechat | grep -i "not found"
'
```

验证:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" bash -lc 'test -x /opt/wechat/wechat && ! ldd /opt/wechat/wechat | grep -i "not found"'
```

关键验证点是 `/opt/wechat/wechat` 存在且 `ldd` 没有缺失库。

## 7. 安装 VM 侧 xpra 6.x

Ubuntu noble 默认仓库里的 xpra 版本过旧,必须使用 xpra.org 仓库:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" -u root bash -lc '
  set -e
  install -d /usr/share/keyrings
  curl -fsSL https://xpra.org/xpra.gpg -o /usr/share/keyrings/xpra-archive-keyring.gpg
  echo "deb [arch=arm64 signed-by=/usr/share/keyrings/xpra-archive-keyring.gpg] https://xpra.org/ noble main" \
    > /etc/apt/sources.list.d/xpra.list
  apt-get update
  apt-get install -y xpra
  xpra --version
'
```

验证版本应为 6.x:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" xpra --version
```

## 8. 安装和配置 fcitx5

安装输入法:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" -u root apt-get install -y \
  fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 \
  fcitx5-config-qt im-config
```

配置当前 VM 用户的 fcitx5 profile 和快捷键:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" bash -lc '
  set -e
  mkdir -p ~/.config/fcitx5
  printf "%s\n" \
    "[Groups/0]" "Name=Default" "Default Layout=us" "DefaultIM=pinyin" "" \
    "[Groups/0/Items/0]" "Name=keyboard-us" "Layout=" "" \
    "[Groups/0/Items/1]" "Name=pinyin" "Layout=" "" \
    "[GroupOrder]" "0=Default" > ~/.config/fcitx5/profile

  printf "%s\n" \
    "[Hotkey]" "TriggerKeys=Control+grave" "" \
    "[Behavior]" "ActiveByDefault=True" > ~/.config/fcitx5/config

  im-config -n fcitx5 || true
'
```

说明:

- 使用 `Control+grave` 避开 macOS 对 `Ctrl+Space` 的拦截。
- `DefaultIM=pinyin` 和 `ActiveByDefault=True` 让微信输入框默认中文。

## 9. 配置直连 SSH

OrbStack 的 `orb` 代理不等价于普通 SSH。xpra attach 要走直连 SSH:

```bash
cat "$ORBSTACK_WECHAT_SSH_KEY.pub" | orb -m "$ORBSTACK_WECHAT_MACHINE" bash -lc '
  set -e
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  key="$(cat)"
  grep -qxF "$key" ~/.ssh/authorized_keys || printf "%s\n" "$key" >> ~/.ssh/authorized_keys
'
```

验证:

```bash
ssh -i "$ORBSTACK_WECHAT_SSH_KEY" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  "$ORBSTACK_WECHAT_USER@$ORBSTACK_WECHAT_HOST" true
```

如果这里失败,先修 SSH,不要继续排查 xpra。

## 10. 启动与验证

从仓库根目录启动:

```bash
./wechat-remote/vm/start.sh
```

期望结果:

- VM 内存在 `LIVE session at :10`。
- macOS 出现一个可拖动的微信窗口。
- 微信输入框可用拼音输入中文。
- Retina 屏上字体和界面清晰,不是 1x 放大后的模糊效果。

命令行验证:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" bash -lc 'xpra list'
orb -m "$ORBSTACK_WECHAT_MACHINE" bash -lc 'pgrep -af "wechat|fcitx5|xpra"'
```

生成项目内 applet:

```bash
./wechat-remote/vm/install-app.sh
```

生成位置:

```text
wechat-remote/vm/apps/OrbStack WeChat.app
```

这个 app bundle 是本地生成物,不要提交。

## 11. 常见失败点

| 现象 | 优先检查 |
|---|---|
| `client failed to specify any supported encodings` | VM 是否装了 xpra.org 的 6.x,而不是 Ubuntu 默认 3.x |
| macOS Xpra 崩溃或菜单线程异常 | attach 是否带 `XPRA_OSX_SHOW_MENU_DEFAULT=0` |
| `/opt/homebrew/bin/xpra` 找不到 `Contents/` | 是否使用了 `/Applications/Xpra.app/Contents/MacOS/Xpra` |
| 中文不能输入 | `fcitx5` 是否在同一 xpra 会话内启动;微信环境变量是否是 `QT_IM_MODULE=fcitx` |
| 窗口模糊 | attach 是否使用 `--opengl=yes --desktop-scaling=1/S --encoding=rgb` |
| 窗口尺寸过大或过小 | `QT_SCALE_FACTOR=S` 与 `QT_FONT_DPI=96` 是否同时生效 |
| SSH attach 失败 | 先用第 9 节的 `ssh ... true` 单独验证 |

## 12. 停止与重连

只断开 macOS 客户端:

```bash
pkill -f "MacOS/Xpra attach"
```

停止 VM 内 xpra 会话:

```bash
orb -m "$ORBSTACK_WECHAT_MACHINE" xpra stop "$ORBSTACK_WECHAT_DISPLAY"
```

重连:

```bash
./wechat-remote/vm/start.sh
```
