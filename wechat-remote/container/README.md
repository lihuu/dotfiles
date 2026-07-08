# Apple container 运行 Linux 微信(xpra + fcitx5)

这个方案使用 macOS 的 Apple `container` 工具运行和 Docker 方案同一套 Linux 微信镜像,
再通过 xpra TCP 转发到 macOS 桌面。

当前实测状态:

- 可用 `container build` 从 `wechat-remote/docker/image` 构建 `wechat-xpra:latest`。
- 可用 `container run` 启动容器,并通过 `tcp:localhost:14503` attach。
- xpra 服务端可正常启动,微信、fcitx5、D-Bus 都正常运行。
- 窗口拖动仍沿用 Docker 方案的 `decorations=1` 外层标题栏 workaround。

## 关键差异

1. **CLI 版本必须匹配**

   当前机器上 `/usr/local/bin/container` 是旧的 `0.6.0` CLI,会和 Homebrew 安装的
   `1.0.0` apiserver 不兼容,表现为网络列表异常、builder JSON 解码失败等。

   脚本会优先使用:

   ```text
   /opt/homebrew/bin/container
   /opt/homebrew/Cellar/container/*/bin/container
   ```

   必须确保实际使用的是 `container CLI version 1.x`。

2. **volume 权限和 Docker 不一样**

   Docker named volume 挂载到镜像已有目录时通常会复制目录内容/权限。Apple container
   的 volume 挂到 `/home/wechat` 后初始是 root 权限,会导致:

   ```text
   mkdir: cannot create directory '/home/wechat/.config': Permission denied
   ```

   `start.sh` 会用一次性 root 容器检测并修正 volume 所有权:

   ```bash
   chown -R wechat:wechat /home/wechat
   chmod 700 /home/wechat
   ```

## 使用

先确认微信 deb 已放好:

```bash
cp ~/Downloads/WeChatLinux_arm64.deb wechat-remote/docker/image/wechat.deb
```

启动:

```bash
./wechat-remote/container/start.sh
```

默认资源和名字:

| 变量 | 默认值 | 说明 |
|---|---|---|
| `CONTAINER_BIN` | 自动探测 | Apple container CLI 路径 |
| `WECHAT_CONTAINER_IMAGE` | `wechat-xpra` | 镜像名 |
| `WECHAT_CONTAINER_NAME` | `wechat-container-xpra` | 容器名 |
| `WECHAT_CONTAINER_PORT` | `14503` | xpra TCP 本机端口 |
| `WECHAT_CONTAINER_DATA` | `wechat-container-data` | Apple container volume |
| `WECHAT_SCALE` | 自动探测 | Retina backing scale |
| `WECHAT_OPENGL` | `yes` | Xpra 客户端 OpenGL |
| `WECHAT_ENCODING` | `rgb` | Xpra 编码 |
| `WECHAT_QT_FONT_DPI` | `96` | WeChat Qt 字体 DPI |

## 验证

```bash
CONTAINER_BIN=/opt/homebrew/Cellar/container/1.0.0_1/bin/container

$CONTAINER_BIN list --all
$CONTAINER_BIN exec wechat-container-xpra xpra list
$CONTAINER_BIN exec wechat-container-xpra pgrep -af 'wechat|fcitx5|xpra|dbus-daemon'
nc -zv 127.0.0.1 14503
```

期望:

- 容器 `wechat-container-xpra` 是 `running`。
- `xpra list` 显示 `LIVE session at :10`。
- 端口 `127.0.0.1:14503` 可连接。
- macOS Xpra attach 后 `xpra info :10` 显示 `clients=1`。

## 停止

断开 macOS Xpra 客户端:

```bash
pkill -f "MacOS/Xpra attach"
```

停止容器:

```bash
/opt/homebrew/Cellar/container/1.0.0_1/bin/container stop wechat-container-xpra
```

删除测试容器但保留微信数据:

```bash
/opt/homebrew/Cellar/container/1.0.0_1/bin/container delete wechat-container-xpra
```

删除 volume 会清空微信登录态和数据,不要在未确认时执行:

```bash
/opt/homebrew/Cellar/container/1.0.0_1/bin/container volume delete wechat-container-data
```
