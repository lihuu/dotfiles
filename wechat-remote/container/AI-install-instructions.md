# AI Install Instructions: Apple container Scheme

本文面向接手执行的 AI agent。目标是用 macOS 的 Apple `container` 工具运行
Linux 微信容器,再通过 xpra TCP rootless 模式把窗口转发到 macOS 桌面。

这个方案是独立部署方案,不是 Docker 方案的附属启动命令。它复用
`wechat-remote/docker/image` 作为镜像构建上下文,但运行时由 Apple container 管理。
从架构上看,它更接近"一个微信实例 = 一个轻量 VM + 一个容器"的隔离单元,适合未来按
微信账号做独立实例。

## 1. 目标状态

完成后应满足:

- Apple container system 已启动。
- 使用的是 `container CLI version 1.x`,不要使用旧的 `/usr/local/bin/container 0.6.0`。
- `wechat-remote/docker/image/wechat.deb` 存在,且被 git ignore。
- Apple container 镜像 `wechat-xpra:latest` 构建成功。
- Apple container volume `wechat-container-data` 存在,并可被容器内 `wechat` 用户写入。
- 容器 `wechat-container-xpra` 运行中,端口 `127.0.0.1:14503` 转发到容器 `14500`。
- macOS Xpra 可 attach 到 `tcp:localhost:14503` 并显示微信窗口。

## 2. AI 执行约束

- 不要提交 `wechat.deb`、Apple container volume、微信账号数据或 app bundle。
- 不要直接暴露 xpra TCP 端口到 `0.0.0.0`;必须绑定 `127.0.0.1`。
- 删除容器可以执行;删除 volume 会清空微信登录态和数据,必须先确认。
- 如果发现 PATH 中的 `container` 是 0.x,不要继续使用它。必须显式选择 Homebrew 1.x CLI。
- 不要反向修改 VM 方案或 Docker 方案来适配 Apple container。三者应保持独立入口。

## 3. CLI 版本检查

先定位可用的 1.x CLI:

```bash
command -v container || true
container --version || true

ls -1d /opt/homebrew/Cellar/container/*/bin/container 2>/dev/null
/opt/homebrew/Cellar/container/1.0.0_1/bin/container --version
```

如果 `/usr/local/bin/container` 输出类似:

```text
container CLI version 0.6.0
```

不要使用它。设置:

```bash
export CONTAINER_BIN=/opt/homebrew/Cellar/container/1.0.0_1/bin/container
```

如 Homebrew 版本路径不同,使用实际的 `/opt/homebrew/Cellar/container/<version>/bin/container`。

## 4. macOS 前置检查

从仓库根目录执行:

```bash
cd "$(git rev-parse --show-toplevel)"
test -x "$CONTAINER_BIN"
test -x /Applications/Xpra.app/Contents/MacOS/Xpra
test -f wechat-remote/docker/image/wechat.deb
git check-ignore -v wechat-remote/docker/image/wechat.deb
```

如果 Xpra 不存在:

```bash
brew install --cask xpra
xattr -dr com.apple.quarantine /Applications/Xpra.app
```

## 5. 启动 Apple container system

```bash
"$CONTAINER_BIN" system start
"$CONTAINER_BIN" system status
"$CONTAINER_BIN" network list
```

期望 `network list` 至少包含:

```text
default  192.168.64.0/24
```

如果网络列表异常,先确认是否误用了旧 CLI。旧 CLI 和 1.x apiserver 混用时会出现
`network default not found`、`network default already exists` 或 JSON decode 错误。

## 6. 构建镜像

可以让启动脚本自动构建,也可以手动构建:

```bash
"$CONTAINER_BIN" builder start
"$CONTAINER_BIN" build --platform linux/arm64 -t wechat-xpra wechat-remote/docker/image
```

验证:

```bash
"$CONTAINER_BIN" image inspect wechat-xpra:latest
```

镜像应为 linux/arm64,入口应为 `/entrypoint.sh`。

## 7. 创建并修正 volume

Apple container 的 volume 初始权限和 Docker named volume 不同。首次挂载到
`/home/wechat` 后可能是 root 权限,会导致容器启动失败:

```text
mkdir: cannot create directory '/home/wechat/.config': Permission denied
```

手动修复方式:

```bash
"$CONTAINER_BIN" volume create wechat-container-data || true

"$CONTAINER_BIN" run --rm \
  --user root \
  --entrypoint /bin/bash \
  -v wechat-container-data:/home/wechat \
  wechat-xpra:latest \
  -lc 'chown -R wechat:wechat /home/wechat && chmod 700 /home/wechat'
```

`wechat-remote/container/start.sh` 已内置这个检测和修复逻辑。

## 8. 启动

推荐直接使用脚本:

```bash
CONTAINER_BIN="$CONTAINER_BIN" ./wechat-remote/container/start.sh
```

默认参数:

| 变量 | 默认值 | 说明 |
|---|---|---|
| `CONTAINER_BIN` | 自动探测 | Apple container CLI 路径 |
| `WECHAT_CONTAINER_IMAGE` | `wechat-xpra` | 镜像名 |
| `WECHAT_CONTAINER_NAME` | `wechat-container-xpra` | 容器名 |
| `WECHAT_CONTAINER_PORT` | `14503` | xpra TCP 本机端口 |
| `WECHAT_CONTAINER_DATA` | `wechat-container-data` | 数据 volume |
| `WECHAT_SCALE` | 自动探测 | Retina backing scale |
| `WECHAT_OPENGL` | `yes` | Xpra 客户端 OpenGL |
| `WECHAT_ENCODING` | `rgb` | Xpra 编码 |
| `WECHAT_QT_FONT_DPI` | `96` | WeChat Qt 字体 DPI |

## 9. 验证

```bash
"$CONTAINER_BIN" list --all
"$CONTAINER_BIN" exec wechat-container-xpra xpra list
"$CONTAINER_BIN" exec wechat-container-xpra pgrep -af 'wechat|fcitx5|xpra|dbus-daemon'
nc -zv 127.0.0.1 14503
```

期望:

- 容器 `wechat-container-xpra` 为 `running`。
- `xpra list` 显示 `LIVE session at :10`。
- `pgrep` 能看到 `wechat`、`fcitx5`、`dbus-daemon`、`xpra`。
- `127.0.0.1:14503` 可连接。
- attach 后 `xpra info :10` 显示 `clients=1`。

可进一步检查窗口元数据:

```bash
"$CONTAINER_BIN" exec wechat-container-xpra xpra info :10 \
  | rg '^clients=|windows\\..*\\.(title|decorations|frame|shown|window-type|size)='
```

当前已知窗口仍使用 Docker 方案的 workaround:

```text
decorations=1
frame=None
window-type='_KDEOVERRIDE', 'NORMAL'
```

## 10. 停止与清理

断开 macOS Xpra 客户端:

```bash
pkill -f "MacOS/Xpra attach"
```

停止容器:

```bash
"$CONTAINER_BIN" stop wechat-container-xpra
```

删除容器但保留数据:

```bash
"$CONTAINER_BIN" delete wechat-container-xpra
```

删除 volume 会清空微信登录态和数据,不要在未确认时执行:

```bash
"$CONTAINER_BIN" volume delete wechat-container-data
```

## 11. 常见失败点

| 现象 | 优先检查 |
|---|---|
| `network default not found` / JSON decode | 是否误用了 `/usr/local/bin/container 0.6.0`;改用 Homebrew 1.x CLI |
| 构建找不到 `wechat.deb` | 是否已放到 `wechat-remote/docker/image/wechat.deb` |
| 启动后立刻退出且提示 `.config` 权限错误 | 先按第 7 节修正 volume 所有权 |
| 端口连不上 | `container inspect` 是否显示 `127.0.0.1:14503 -> 14500` |
| attach 后窗口不显示 | 容器内 `xpra list` 是否 live;`xpra info :10` 是否 `clients=1` |
| 窗口仍需外层标题栏拖动 | 这是当前镜像内 xpra workaround,不是 Apple container 已解决自然拖动 |
