# Docker 部署 Linux 微信(xpra + fcitx5)探索

把 OrbStack VM 方案(见 [orbstack-wechat-xpra-setup.md](orbstack-wechat-xpra-setup.md))里的"xpra + fcitx5 + Linux 微信"栈装进一个 Docker 容器,经 xpra TCP 转发到 macOS 桌面。**本文档为探索性质,产物未提交**,与 VM 方案并行,互不影响。

- **定位**:VM 方案已验证可行且效果好;Docker 版主要收益是**可复现/可重建**(微信或 xpra 升级一条 `docker build` 重来,不漂移)。
- **传输**:TCP(`--bind-tcp` + `tcp:localhost:PORT`),省去容器内 sshd 和密钥分发。SSH 方案见末尾"替代传输"。
- **显示/HiDPI**:与 VM 方案**完全相同**——backing scale 在 Mac 侧探测,`--desktop-scaling=1/S` + `QT_SCALE_FACTOR=S`。原理见 VM 文档第 5 节,本文不重复。

---

## 1. 架构

```
macOS (xpra 客户端 6.5)                    Docker 容器(ubuntu:24.04 arm64)
/Applications/Xpra.app                     ├── xpra 服务端 6.x (xpra.org 仓库)
rootless 窗口转发       ─── tcp:14501 ──▶  ├── fcitx5 + 拼音
XPRA_OSX_SHOW_MENU_DEFAULT=0               ├── wechat (Linux arm64 4.1.x, XCB)
                                           └── 虚拟显示 :10 (Xvfb)
                                           dbus-run-session 提供 session bus
```

与 VM 方案的差异:宿主从"OrbStack Ubuntu VM"换成"Docker 容器";传输从 SSH 换成 TCP;多了 D-Bus/XDG_RUNTIME_DIR 的 entrypoint 处理。xpra 客户端、显示自适应、fcitx5 配置、wechat Qt 三件套全部不变。

---

## 2. 前置条件

- macOS(Apple Silicon)+ OrbStack(或任意能跑 arm64 容器的 Docker)。
- Docker 镜像构建用 arm64 原生(Apple Silicon 上无模拟,性能与 VM 相当)。
- macOS 已装 xpra 客户端:`brew install --cask xpra` + `xattr -dr com.apple.quarantine /Applications/Xpra.app`(详见 VM 文档步骤 3)。
- **微信 arm64 deb**:从 https://linux.weixin.qq.com/ 下载 arm64 deb,放到 `docker/wechat/wechat.deb`(构建上下文读取;该 deb 不提交,版本随你)。

---

## 3. 文件清单(均未提交,探索阶段)

```
docker/wechat/
├── Dockerfile          # ubuntu:24.04 + xpra.org 6.x + fcitx5 + 字体 + wechat deb
├── entrypoint.sh       # dbus-run-session → xpra start :10 --bind-tcp → fcitx5 + wechat
└── fcitx5/
    ├── profile         # keyboard-us + 拼音
    └── config          # 触发键 Ctrl+`,默认中文
scripts/
└── start-docker-wechat.sh   # 探测 backing scale → 构建镜像 → 启动容器 → TCP attach
```

---

## 4. 构建 + 运行

一键脚本封装了构建、启动、attach:

```bash
# 1. 放好微信 deb
cp ~/Downloads/WeChatLinux_arm64.deb docker/wechat/wechat.deb

# 2. 启动(首次自动构建镜像)
./scripts/start-docker-wechat.sh
```

脚本逻辑:
1. 探测 Mac 主显示器 backing scale `S`(与 VM 脚本同一逻辑)。
2. 镜像 `wechat-xpra` 不存在则 `docker build`。
3. 容器 `wechat-xpra` 未运行则 `docker run -d`:
   - `-p 14501:14500`(xpra TCP;14501 避开 OrbStack VM 的 14500,见 §7)
   - `-v wechat-xpra-data:/home/wechat`(微信登录态/数据持久化)
   - `-e QT_SCALE_FACTOR=S -e QT_FONT_DPI=96`(wechat Qt HiDPI)
   - `--shm-size 256m`(Qt/X 共享内存)
   - `--restart unless-stopped`
4. macOS `Xpra attach tcp:localhost:14501 --desktop-scaling=1/S --opengl=yes --encoding=rgb`。

可覆盖的环境变量:

| 变量 | 默认值 | 说明 |
|---|---|---|
| `WECHAT_DOCKER_IMAGE` | `wechat-xpra` | 镜像名 |
| `WECHAT_DOCKER_CONTAINER` | `wechat-xpra` | 容器名 |
| `WECHAT_DOCKER_PORT` | `14501` | xpra TCP 端口(避开 OrbStack VM 的 14500) |
| `WECHAT_DOCKER_DATA` | `wechat-xpra-data` | 微信数据 volume |
| `WECHAT_SCALE` | 自动探测 | backing scale(2=Retina,1=1x) |
| `WECHAT_OPENGL` | `yes` | 客户端 GL 合成 |
| `WECHAT_ENCODING` | `rgb` | 传输编码 |
| `WECHAT_QT_FONT_DPI` | `96` | wechat 字体 DPI |

---

## 5. 日常使用

```bash
# 启动(构建 + 容器 + attach)
./scripts/start-docker-wechat.sh

# 只停 attach(Mac 客户端)
pkill -f "MacOS/Xpra attach"

# 容器继续后台跑(--restart unless-stopped + --exit-with-client=no),微信登录态保留

# 彻底重建(换微信版本 / 升级 xpra / 改 scale)
docker rm -f wechat-xpra
docker rmi wechat-xpra
./scripts/start-docker-wechat.sh

# 查看容器内 xpra 状态
docker exec wechat-xpra xpra list
```

---

## 6. 与 VM 方案对比

| 维度 | OrbStack VM 方案 | Docker 方案 |
|---|---|---|
| 隔离单元 | 完整 Ubuntu VM | 容器(更轻) |
| 安装 | 手动步骤 1–3(一次性) | `docker build`(声明式、可重建) |
| 传输 | SSH + OrbStack 密钥 | TCP(无密钥) |
| D-Bus | VM 自带 systemd session bus | entrypoint `dbus-run-session` 包一层 |
| 数据持久化 | VM 磁盘(天然) | 显式 named volume |
| 升级 | 手动 apt 升级,可能漂移 | 重建镜像,版本锁定 |
| 显示/HiDPI | Mac 侧探测 backing scale(同) | 同 |
| 稳定性 | 已验证长跑(客户端偶崩,VM 会话在) | 待验证(同机制,预期相当) |

---

## 7. Docker 特有注意点

- **D-Bus session bus**:fcitx5/wechat 需要 session bus,容器无 systemd → entrypoint 用固定地址 `dbus-daemon` + 把 `DBUS_SESSION_BUS_ADDRESS` 显式注入 `--start` env(xpra 会剥离它,见 §8 问题 6)。
- **`XDG_RUNTIME_DIR`**:fcitx5 要可写运行时目录 → 镜像设 `XDG_RUNTIME_DIR=/tmp/runtime-wechat`(`chmod 700`)。
- **数据持久化**:`-v wechat-xpra-data:/home/wechat` 挂载整个家目录,微信登录态/聊天数据 + fcitx5 配置都在 volume 里,重建容器不丢。fcitx5 默认配置在 entrypoint 首次运行时从 `/etc/fcitx5-seed/` 种入(见 Dockerfile)。
- **`--shm-size=256m`**:Qt/X 偶用共享内存,默认 64MB 偏小。
- **不需要 `--privileged`**:xpra 自带 Xvfb 虚拟显示,不碰宿主 X/GPU,普通 `docker run` 即可。
- **xpra 版本**:容器内同样必须从 xpra.org 装 6.x(Ubuntu 仓库的 3.1.5 与 Mac 客户端 6.5 不兼容,会报 `failed to specify any supported encodings`)。
- **xpra-x11 包**:`--no-install-recommends` 会漏装 `xpra-x11`(seamless 模块;`import xpra.x11` 缺失会报 `install xpra-x11 to use 'seamless'`)。Dockerfile 已显式 `apt-get install xpra xpra-x11`。
- **TCP 鉴权 + 端口冲突 + 窗口拖动(必读)**:① 容器 xpra 用 TCP 时必须显式 `--tcp-auth=none`,否则发 auth challenge 触发 Mac 客户端 6.5 的 `get_encryption` bug → `Connection failed`;② OrbStack VM 若在跑 xpra 方案,VM 的 `xpra proxy` 默认占 `14500`(`--tcp-auth=sys`),Mac 的 `localhost:14500` 会被 VM 抢走,故 TCP 方案用 `14501`;③ `--tcp-auth=none` 只适合本机连接,脚本把 Docker 端口绑定到 `127.0.0.1`;④ macOS 客户端会上报原生窗口 frame,必须在镜像里关闭 xpra 的 `window.frame-extents` capability,并在 entrypoint 里设置 `XPRA_FRAME_EXTENTS=0`;⑤ 微信主窗口自身声明 `decorations=0`,Docker 版还需要对 `WM_CLASS=wechat` 强制上报 `decorations=1`,用 macOS 外层标题栏拖动窗口(见 §8 问题 9)。
- **scale 变更**:`--desktop-scaling` 是客户端侧,每次 attach 按当前屏自动生效;但 `QT_SCALE_FACTOR`(wechat UI 缩放)在容器创建时固定,换屏要改 scale 需 `docker rm -f` 后重跑(微信登录态在 volume 里不丢)。

---

## 8. 问题与修复总结

实机实现过程中踩了 9 个问题,均已给出修复。

### 已解决

| # | 问题 | 根因 | 修复 |
|---|---|---|---|
| 1 | `install xpra-x11 to use 'seamless'` | `--no-install-recommends` 漏装 `xpra-x11`(seamless 模块) | Dockerfile 显式 `apt-get install xpra xpra-x11` |
| 2 | `error while loading shared libraries: libatomic.so.1` 等 | wechat deb 依赖声明不全,缺 7 个 `.so` | 显式装 `libatomic1 libpulse0 libxcb-image0 libxcb-render-util0 libnss3 libnspr4 libasound2t64`(noble 是 `libasound2t64`),Dockerfile 末尾 `ldd` 自检 |
| 3 | xpra `No module named 'dbus'` | 缺 `python3-dbus` | 装 `python3-dbus` |
| 4 | attach `Connection failed` + `get_encryption` 崩溃 | TCP 默认鉴权发 challenge,触发 Mac 客户端 6.5 的 `get_encryption` bug(SSH 传输不触发,故 VM 无事) | 服务端 `--tcp-auth=none` |
| 5 | `localhost:14500` 连到 VM 不是容器 | OrbStack VM 的 `xpra proxy :14500 --tcp-auth=sys` 占了 14500 | 容器改用 14501(TCP 方案时) |
| 6 | 输入法不通 | xpra 启动 `--start` 子进程时剥离 `DBUS_SESSION_BUS_ADDRESS`,fcitx5 与 wechat 不在同一 D-Bus | entrypoint 用固定地址 `dbus-daemon` + 把 DBUS 地址显式注入 `--start` env |
| 7 | 默认输入英文 | seed profile `DefaultIM=keyboard-us`;VM 是被 fcitx5 改写成 `DefaultIM=pinyin` 才默认中文 | seed 改 `DefaultIM=pinyin` |
| 8 | wechat 窗口过冲(1960×1420 而非 560×760) | xpra 默认 `start-env` 注入 `MWWM=allwm`、`QT_SCALE_FACTOR=1` 等变量,普通 `env` 只覆盖部分变量 | entrypoint 用 `env -i` 启动 fcitx5/wechat,只保留必要的 D-Bus、输入法和 Qt HiDPI 变量 |
| 9 | 容器里微信主窗口拖不动 | 微信主窗口是无边框自绘标题栏(`_KDEOVERRIDE` + Motif decorations=0)。第一层问题是 xpra 把 macOS 客户端 frame 回写成 `(0,0,64,0)`;去掉 frame 后仍不能拖,因为 Docker 里微信自绘标题栏没有成功发起窗口移动 | Dockerfile patch xpra: `seamless.py` 中 `"frame-extents": True` → `False`;`metadata.py` 对 `WM_CLASS=wechat` 强制上报 `decorations=1`;entrypoint 额外 `XPRA_FRAME_EXTENTS=0`。最终通过 macOS 外层标题栏拖动 |

---

## 9. 已知限制 / 文件状态

- **窗口拖动修复需要重建镜像**:修复点包含 Dockerfile 内的 xpra 源码 patch,已有容器不会自动生效。执行 `docker rm -f wechat-xpra && docker rmi wechat-xpra && ./scripts/start-docker-wechat.sh` 后再验证。当前方案不优雅,但实测可以通过 macOS 外层标题栏拖动。
- **fcitx5 候选窗偏小**:与 VM 方案同一限制(2x 屏 fcitx5 classic UI 不随微信放大),见 VM 文档第 9 节。
- **新消息通知**:与 VM 方案同一限制(WeChat 走 SNI attention 闪烁,macOS 菜单栏不支持),见 VM 文档第 9 节。
- **音频/通话**:xpra 客户端 adhoc 签名 + Hardened Runtime 限制,与传输方式无关,不可用。
- **attach 客户端长跑崩溃**:macOS 客户端 GPU 着色器超限 SIGSEGV;容器会话因 `--exit-with-client=no` 仍在,重跑脚本即重连。
- **微信数据目录**:挂载 `/home/wechat` 整个家目录是稳妥兜底;微信 4.x 实际数据多在 `~/xwechat_files`,如需更细粒度可只挂该目录。

---

## 10. 替代传输:SSH(忠实现状)

若要和 VM 方案完全一致(SSH 加密、复用现有 attach 命令形态):

- 容器内装 `openssh-server`,entrypoint 额外起 sshd。
- 把 OrbStack 公钥(`~/.orbstack/ssh/id_ed25519.pub`)注入容器 `/home/wechat/.ssh/authorized_keys`(可用 `docker run -v` 挂载或 build arg)。
- xpra 不再 `--bind-tcp`,改默认 socket;Mac 侧 `ssh://wechat@<container>.orb.local/10`。

代价:容器多一层 sshd 维护。本地 OrbStack 场景下 TCP 已够,SSH 主要适合跨网络或需要加密时。
