# OrbStack Ubuntu + xpra 运行 Linux 微信（macOS 第二微信客户端）

在 macOS 上通过 OrbStack 的 Ubuntu 24.04 arm64 虚拟机运行 Linux 版微信，用 **xpra** 以 rootless（无缝窗口）方式把微信窗口转发到 macOS 桌面，再用 **fcitx5** 解决中文输入。

- **macOS 客户端**：xpra 6.5（Homebrew cask）
- **VM 服务端**：xpra 6.4.3（xpra.org apt 仓库）on OrbStack Ubuntu 24.04 arm64
- **输入法**：fcitx5 5.1.7 + 拼音，运行在 VM 的 xpra 会话内
- **微信**：Linux arm64 deb 4.1.x，运行在 xpra 虚拟显示 `:10`

---

## 1. 为什么是 xpra，而不是 XQuartz 直连

最初用 XQuartz + `ssh -Y` 转发，踩了三个绕不过去的坑：

| 问题 | XQuartz 直连的表现 | xpra 的解法 |
|---|---|---|
| 双显示器居中 | XQuartz 把两块屏合并成一个 `3840x1050` 的 X11 屏幕，微信/Electron 按合并画布算几何，窗口居中错乱 | 协议层正确上报每台显示器真实几何（`monitors.0/1`），微信看到两块独立 1920×1080 |
| 窗口拖动 | 登录窗口是 borderless（`_KDEOVERRIDE`），无原生标题栏，拖不动 | rootless 模式给每个转发窗口套原生窗口装饰，可拖动 |
| 中文输入 | 转发底层 X11，macOS 输入法无法桥接，中文不能上屏 | VM 内 fcitx5 接管合成，候选词窗口也作为 X11 窗口转发 |

额外收益：剪贴板同步、音频转发、光标跟随、会话断线可重连。

---

## 2. 架构

```
macOS (xpra 客户端 6.5)                    OrbStack Ubuntu 24.04 arm64 VM
/Applications/Xpra.app                     xpra 服务端 6.4.3 (xpra.org 仓库)
rootless 窗口转发       ───── ssh ─────▶   ├── wechat  (Linux arm64 4.1.x, XCB)
XPRA_OSX_SHOW_MENU_DEFAULT=0               ├── fcitx5  + 拼音 (输入法)
                                           └── 虚拟显示 :10
```

- 微信**主窗口**文本输入在 `wechat` 进程（XCB），通过 XIM 接 fcitx5 → 中文可用。
- **小程序**由 `WeChatAppEx`（Chromium）渲染，启动时清空环境变量，丢失 fcitx 配置 → 小程序内可能不支持中文输入（已知限制）。

---

## 3. 前置条件

- macOS（Apple Silicon）+ OrbStack + Ubuntu 24.04 arm64 VM（机器名 `ubuntu-24.04`）。
- VM 里已装好 Linux 微信及依赖（`/opt/wechat/wechat` 可启动；CJK 字体 `fonts-noto-cjk` 已装）。
- VM 里已配置好直连 SSH：OrbStack 公钥 `~/.orbstack/ssh/id_ed25519.pub` 已加入 VM 的 `/home/<user>/.ssh/authorized_keys`。
  - OrbStack 默认的 `ssh orb` 代理**不支持 X11 转发**，必须用直连 SSH。
- macOS 已装 Homebrew。

> VM 主机名 `ubuntu-24.04.orb.local` 由 OrbStack 提供，稳定可达（不受 IP 变化影响）。下文命令默认用它。

---

## 4. 安装步骤

### 步骤 1：VM 侧安装 xpra 服务端（必须用 xpra.org 仓库）

> ⚠️ Ubuntu noble 仓库的 xpra 是 **3.1.5**，与 macOS 客户端 6.5 版本差太大，attach 时会报 `client failed to specify any supported encodings`。必须用 xpra.org 仓库装 6.x。

```bash
orb -m ubuntu-24.04 -u root bash -c '
  install -d /usr/share/keyrings
  curl -fsSL https://xpra.org/xpra.gpg -o /usr/share/keyrings/xpra-archive-keyring.gpg
  echo "deb [arch=arm64 signed-by=/usr/share/keyrings/xpra-archive-keyring.gpg] https://xpra.org/ noble main" \
    > /etc/apt/sources.list.d/xpra.list
  apt-get update
  apt-get install -y xpra
  xpra --version   # 期望 6.x
'
```

> 说明：xpra.org 的 GPG key 有 `.asc`（文本）和 `.gpg`（二进制）两种。VM 里没装 `gnupg` 时直接用二进制 `xpra.gpg` 落到 keyrings 目录即可，无需 `gpg --dearmor`。

### 步骤 2：VM 侧安装 fcitx5 + 中文输入

```bash
orb -m ubuntu-24.04 -u root apt-get install -y \
  fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-config-qt im-config

# 设默认输入法为 fcitx5（写入 ~/.xinputrc）
orb -m ubuntu-24.04 im-config -n fcitx5
```

配置 fcitx5 profile（启用 keyboard-us + 拼音）：

```bash
orb -m ubuntu-24.04 bash -lc '
  mkdir -p ~/.config/fcitx5
  printf "%s\n" \
    "[Groups/0]" "Name=Default" "Default Layout=us" "DefaultIM=keyboard-us" "" \
    "[Groups/0/Items/0]" "Name=keyboard-us" "Layout=" "" \
    "[Groups/0/Items/1]" "Name=pinyin" "Layout=" "" \
    "[GroupOrder]" "0=Default" > ~/.config/fcitx5/profile
'
```

配置切换键（避开 macOS 的 `Ctrl+Space` 冲突）+ 默认激活中文：

```bash
orb -m ubuntu-24.04 bash -lc '
  printf "%s\n" "[Hotkey]" "TriggerKeys=Control+grave" "" "[Behavior]" "ActiveByDefault=True" \
    > ~/.config/fcitx5/config
'
```

> `Ctrl+Space` 与 macOS 输入源切换快捷键冲突，会被系统截走，到不了 fcitx5。改成 `Ctrl+``（Control+grave，键盘左上角 `~` 键）。`ActiveByDefault=True` 让新输入上下文默认中文，多数时候无需手动切换。

### 步骤 3：macOS 侧安装 xpra 客户端

```bash
brew install --cask xpra
# cask 未过 Gatekeeper（未公证），去隔离属性：
xattr -dr com.apple.quarantine /Applications/Xpra.app
```

> ⚠️ **必须用全路径** `/Applications/Xpra.app/Contents/MacOS/Xpra`，不能用 brew 装的 `/opt/homebrew/bin/xpra` 符号链接——后者会报 `launcher: cannot locate Contents/ above /opt/homebrew/bin/xpra`。
>
> 该 cask 因未过 Gatekeeper 已被 Homebrew 标记 deprecated，2026-09-01 后可能下架；届时改从 https://xpra.org/ 直接下载或源码编译。

### 步骤 4：启动 xpra 会话（VM 侧）

```bash
# 以 2x Retina 屏为例（S=2）；1x 屏把 QT_SCALE_FACTOR 改成 1。脚本会自动探测，无需手算。
orb -m ubuntu-24.04 bash -lc '
  export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx
  xpra start :10 \
    --start="fcitx5 -d" \
    --start="env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx QT4_IM_MODULE=fcitx XMODIFIERS=@im=fcitx CLUTTER_IM_MODULE=fcitx QT_SCALE_FACTOR=2 QT_FONT_DPI=96 QT_AUTO_SCREEN_SCALE_FACTOR=0 wechat" \
    --exit-with-client=no
'
```

> ⚠️ **`env` 包装的两个作用**（xpra 给 `--start` 命令注入环境，必须显式覆盖）：
> 1. 注入 `*_IM_MODULE=ibus` → 用 `env` 强制 fcitx（WeChatAppEx 作为 wechat 子进程会继承）。
> 2. 注入 `QT_SCALE_FACTOR=1` → 禁用 wechat 自带 HiDPI，窗口会变小；用 `env` 覆盖成 `S`。
>
> wechat 是**静态链接 Qt** 的自研应用（`ldd` 无 Qt，但 `strings` 里有 `AA_EnableHighDpiScaling`/`HighDpiScaleFactorRoundingPolicy`）。Qt 缩放三件套：`QT_SCALE_FACTOR=S` 放大 UI；`QT_FONT_DPI=96` 把字体 DPI 从屏幕 144 解耦（否则叠加过冲）；`QT_AUTO_SCREEN_SCALE_FACTOR=0` 关闭不可靠的自动（144 DPI 会被向下取整成 1×）。详见第 5 节。

### 步骤 5：从 macOS 附加（attach）

```bash
# 2x Retina 屏示例（--desktop-scaling=0.5）；1x 屏用 1。脚本会自动探测。
XPRA_OSX_SHOW_MENU_DEFAULT=0 \
  /Applications/Xpra.app/Contents/MacOS/Xpra attach \
  --opengl=yes --desktop-scaling=0.5 --encoding=rgb \
  --ssh="ssh -i $HOME/.orbstack/ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  ssh://${USER}@ubuntu-24.04.orb.local/10
```

> ⚠️ 三个 flag 缺一不可（详见第 5 节）：
> - `XPRA_OSX_SHOW_MENU_DEFAULT=0`：否则客户端构建全局菜单时崩溃（踩坑 3）。
> - `--opengl=yes`：默认 `no`，非 GL 路径不按 Retina 设备像素合成 → 模糊。
> - `--desktop-scaling=0.5`：让服务端按 2x 物理像素渲染；`--encoding=rgb` 本地无损传输。

微信窗口会作为原生 macOS 窗口出现。点输入框直接打拼音即可上屏（fcitx5 默认激活中文）；切英文按 `Ctrl+``。

---

## 5. 显示清晰度与 Retina 自动适配（原理）

默认转发出来是**模糊**的;开了 2x 渲染又会**变小**。两者根因不同,必须分层解决。

### 5.1 为什么模糊:服务端按 1x 渲染

xpra 的 macOS 客户端只把**逻辑分辨率**报给服务端,**不传 Retina 2x backing scale**。4K 屏开 1080p 缩放时:

```
物理 3840×2160  →  macOS 客户端只报逻辑 1920×1080(@~82DPI)给服务端
                 →  服务端按 1x 渲染像素
                 →  客户端塞进 2x backing,macOS 线性放大 → 模糊
```

可用 `xpra info :10` 验证:`client.screen.0.size=(3840,1080)`(逻辑)、`display.dpi.value=72`、`client.opengl.info=disabled by configuration`。

### 5.2 三层修复(清晰)

| 旋钮 | 值(2x 屏) | 作用 |
|---|---|---|
| `--desktop-scaling` | `1/S` = `0.5` | 客户端报 S×物理分辨率(7680×2160@144DPI)给服务端,应用按设备像素渲染。**方向反直觉:S 越大服务端渲染越少越糊,要 S<1** |
| `--opengl` | `yes` | 默认 `no`。GL 才按 Retina 设备像素 1:1 合成,非 GL 路径仍线性放大 |
| `--encoding` | `rgb` | 本地带宽足够,用无损原始像素,杜绝 h264/jpeg 有损编码模糊 |

> 本地 VM 网络(~GB/s、亚毫秒延迟)是无损 rgb 的前提;跨公网才需要换 png/webp。

### 5.3 为什么变小:wechat 是静态 Qt,xpra 禁了它的 HiDPI

开了 5.2 后清晰了,但窗口变小。排查发现:

- wechat `ldd` 无 Qt/GTK,但 `strings /opt/wechat/wechat` 里有 `AA_EnableHighDpiScaling`、`HighDpiScaleFactorRoundingPolicy`、`lastScaleFactor` → **静态链接 Qt 的自研应用**。
- xpra 给 `--start` 命令注入 `QT_SCALE_FACTOR=1`,把 wechat 自带 HiDPI 缩放钉死成 1×。
- wechat 用**固定像素**开窗口 → 在 2x 密度屏上物理尺寸减半 → 变小。

直接 `QT_SCALE_FACTOR=2` 会**过冲**(和屏幕 DPI=144 叠加放大字体,Qt 又按字体度量算窗口尺寸)。正确三件套:

| 环境变量 | 值 | 作用 |
|---|---|---|
| `QT_SCALE_FACTOR` | `S` | UI 放大 S×,窗口按设备像素开 |
| `QT_FONT_DPI` | `96` | 字体 DPI 从屏幕 144 解耦,避免与 QT_SCALE_FACTOR 叠加过冲 |
| `QT_AUTO_SCREEN_SCALE_FACTOR` | `0` | 关闭不可靠的自动(144/96=1.5 会被向下取整成 1×) |

验证:主窗口 `size=(560,760)` server 像素 ÷2 = 280×380 点(原始正确尺寸),且 2x 渲染清晰。

### 5.4 自动适配:在 Mac 侧算 backing scale

> 能算。Linux/X11 支持 HiDPI(DPI + 各工具链 scale),问题只是 xpra macOS 客户端不传 backing scale,所以我们在 Mac 侧自己算。

`S = 物理宽 / 逻辑宽`,从 `system_profiler SPDisplaysDataType` 解析:

```
Resolution: 3840 x 2160        ← 物理
UI Looks like: 1920 x 1080     ← 逻辑(1x 屏无此行 → 逻辑=物理 → S=1)
```

脚本 `detect_backing_scale()` 自动算 S,推导 `--desktop-scaling=1/S` 和 `QT_SCALE_FACTOR=S`。换显示器(1x/2x/其它)重跑脚本即自动适配,无需改配置;探测不准时用 `ORBSTACK_WECHAT_SCALE` 覆盖。

---

## 6. 踩坑总结

| # | 现象 | 原因 | 解决 |
|---|---|---|---|
| 1 | `/opt/homebrew/bin/xpra` 报 `cannot locate Contents/` | brew 符号链接让 launcher 找不到 app bundle | 用全路径 `/Applications/Xpra.app/Contents/MacOS/Xpra` |
| 2 | attach 报 `client failed to specify any supported encodings` | Ubuntu 仓库 xpra 3.1.5 与 macOS 6.5 版本差太大 | 用 xpra.org 仓库装 6.x 服务端 |
| 3 | attach 后客户端崩溃 `NSInternalInconsistencyException: modification of a menu's items on a non-main thread` | `libgtkmacintegration` 从非主线程改 macOS 全局菜单 | `XPRA_OSX_SHOW_MENU_DEFAULT=0` 禁用菜单 |
| 4 | wechat 环境变量是 `GTK_IM_MODULE=ibus` 而非 fcitx | xpra 给 `--start` 命令注入 ibus，覆盖 export | 用 `env GTK_IM_MODULE=fcitx ... wechat` 包装启动 |
| 5 | `Ctrl+Space` 切不出中文 | 与 macOS 输入源切换冲突，被系统截走 | fcitx5 触发键改 `Control+grave`；`ActiveByDefault=True` 默认中文 |
| 6 | 小程序（WeChatAppEx）打不出中文 | Chromium 启动时清空环境变量，丢失 fcitx 配置 | 主窗口（wechat 进程走 XIM）可用；小程序暂不支持 |
| 7 | OrbStack 默认 `ssh orb` 代理不支持 X11 | orb 代理限制 | 用直连 SSH + `~/.orbstack/ssh/id_ed25519` |
| 8 | VM apt 源 `ports.ubuntu.com` 慢/卡 | 国内访问慢 | 临时换清华镜像 `mirrors.tuna.tsinghua.edu.cn/ubuntu-ports`（不要永久改 sources.list） |
| 9 | WeChatAppEx 的 `ldd` 为空 | 自包含 Chromium，静态链接 | 正常现象，不影响运行 |
| 10 | 音频转发报 ORC `Failed to create write and exec mmap regions` | xpra 未公证，Hardened Runtime 无 `allow-jit` entitlement | 仅影响音频/通话，窗口转发不受影响；可忽略 |
| 11 | 窗口模糊 | xpra macOS 客户端只报逻辑分辨率，服务端按 1x 渲染，被 macOS 线性放大 | `--desktop-scaling=1/S --opengl=yes --encoding=rgb`（见第 5 节） |
| 12 | 开 2x 后窗口变小 | xpra 注入 `QT_SCALE_FACTOR=1` 禁了 wechat(Qt)的 HiDPI；wechat 用固定像素开窗 | `env QT_SCALE_FACTOR=S QT_FONT_DPI=96 QT_AUTO_SCREEN_SCALE_FACTOR=0 wechat` |
| 13 | `QT_SCALE_FACTOR=2` 过冲（窗口超大） | 与屏幕 DPI=144 叠加放大字体，Qt 按字体度量算窗口尺寸 | 加 `QT_FONT_DPI=96` 把字体 DPI 解耦（见 5.3） |

---

## 7. 推荐安装方式

**一键脚本** `wechat-remote/vm/start.sh` 封装了步骤 4、5，处理会话已存在的情况，并自动探测显示器 backing scale 配好 Retina 清晰度（见第 5 节）：

```bash
./wechat-remote/vm/start.sh
```

也可以生成一个项目内的 macOS applet,之后双击启动:

```bash
./wechat-remote/vm/install-app.sh
```

默认生成到:

```text
wechat-remote/vm/apps/OrbStack WeChat.app
```

这个 app 不写死用户名或仓库绝对路径。它会根据自身位置反推出 `wechat-remote/vm`
目录,再调用同目录下的 `start.sh`。因此移动仓库目录后,只要重新运行安装脚本生成
app,双击启动仍然走同一套 VM/xpra 逻辑。启动失败日志写入
`/tmp/orbstack-wechat-launcher.log`。

可覆盖的环境变量：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `ORBSTACK_WECHAT_MACHINE` | `ubuntu-24.04` | OrbStack 机器名（用于 `orb` 命令） |
| `ORBSTACK_WECHAT_HOST` | `ubuntu-24.04.orb.local` | VM 主机名/IP（xpra ssh 传输用） |
| `ORBSTACK_WECHAT_USER` | `${USER}` | VM 用户 |
| `ORBSTACK_WECHAT_SSH_KEY` | `~/.orbstack/ssh/id_ed25519` | SSH 私钥 |
| `ORBSTACK_WECHAT_DISPLAY` | `:10` | xpra 虚拟显示号 |
| `ORBSTACK_WECHAT_SCALE` | 自动探测 | 显示器 backing scale（2=Retina 2x，1=1x 屏）；自动从 `system_profiler` 推导，换屏自动适配 |
| `ORBSTACK_WECHAT_OPENGL` | `yes` | 客户端 GL 合成（Retina 1:1 设备像素必需） |
| `ORBSTACK_WECHAT_ENCODING` | `rgb` | 传输编码，rgb=无损原始像素（本地带宽足够） |
| `ORBSTACK_WECHAT_QT_FONT_DPI` | `96` | wechat 字体 DPI，配合 `QT_SCALE_FACTOR`，一般不改 |

> 在新机器上复现：先完成步骤 1–3（一次性安装），之后日常用脚本即可。

---

## 8. 日常使用

```bash
# 启动（VM 会话 + macOS attach）
./wechat-remote/vm/start.sh

# 只停 VM 会话（保留 macOS 客户端会自动断开）
orb -m ubuntu-24.04 xpra stop :10

# 只停 macOS 客户端
pkill -f "MacOS/Xpra attach"

# 切换中英文
# 默认中文（ActiveByDefault）；按 Ctrl+` 切英文
```

---

## 9. 已知限制 / 后续优化

- **显示清晰度**已解决（第 5 节）：Retina 自动适配 + GL 1:1 合成 + rgb 无损传输。换非标准缩放（如 1.5x）探测不准时，用 `ORBSTACK_WECHAT_SCALE` 覆盖。
- **新消息通知未实现**：WeChat 走 SNI 托盘 attention 闪烁 + `_NET_WM_STATE_DEMANDS_ATTENTION`（不走 D-Bus 通知）；macOS 菜单栏 NSStatusItem 不支持闪烁、只支持角标，且 xpra adhoc 签名致原生通知被拒。可行方向：监控 SNI attention 状态 → osascript 弹原生通知，或做菜单栏角标（待做）。
- **fcitx5 候选窗偏小**：2x 屏上 fcitx5 候选词窗口未随微信一起放大。fcitx5 classic UI 不读 XSETTINGS/核心 DPI/`GDK_SCALE`，显式设 `Font` 字号反而更小——它有自己的 PerScreenDPI/主题缩放逻辑，需深入 fcitx5 内部才能解决（暂搁置）。
- **attach 客户端长跑可能崩溃**：macOS 客户端（adhoc + Hardened Runtime）跑数小时后可能因 `AGX: exceeded compiled variants footprint limit`（GPU 着色器超限）SIGSEGV（exit 139）。VM 会话因 `--exit-with-client=no` 仍在，重连脚本即可恢复。
- **小程序输入**不支持中文（WeChatAppEx 清空环境变量）。
- **音频/通话**因 Hardened Runtime 限制可能不可用。
- **xpra macOS cask** 2026-09-01 后弃用，届时需换分发方式（xpra.org 直下或源码编译）。
- **版本对齐**：服务端 6.4.3 ↔ 客户端 6.5 当前兼容；日后升级注意两端版本不要差太大。
