# AI Install Instructions: Docker Scheme

本文面向接手执行的 AI agent。目标是在 Docker 容器里运行 Linux 微信,再通过 xpra
TCP rootless 模式把窗口转发到 macOS 桌面。

当前 Docker 方案可用,但不是体验基线:微信主窗口拖动依赖 `decorations=1` 的外层
macOS 标题栏 workaround。日常优先 VM 方案;Docker 方案适合继续优化可重建、多实例和
容器化交付。

## 1. 目标状态

完成后应满足:

- macOS 已安装 `/Applications/Xpra.app/Contents/MacOS/Xpra`。
- Docker 可用,可构建 arm64 Ubuntu 24.04 镜像。
- `wechat-remote/docker/image/wechat.deb` 存在,但被 `.gitignore` 忽略。
- 镜像 `wechat-xpra` 构建成功。
- 容器 `wechat-xpra` 后台运行,本机 `127.0.0.1:14501` 转发到容器 xpra TCP 端口。
- 运行 `./wechat-remote/docker/start.sh` 可以构建、启动容器并 attach 到微信窗口。

## 2. AI 执行约束

- 不要提交 `wechat.deb`、Docker volume、微信账号数据或 app bundle。
- 不要使用 `--privileged`。本方案不需要宿主 X11/GPU 权限。
- `--tcp-auth=none` 只允许绑定本机 `127.0.0.1`;不要改成 `0.0.0.0` 暴露到局域网或公网。
- 删除容器、镜像或 volume 前先说明影响。删除 volume 会清掉微信登录态和数据。
- 如果 Docker 方案的窗口行为不理想,不要反向破坏 VM 方案;VM 是当前体验基线。

## 3. 变量约定

以下命令默认从仓库根目录执行。如果已经在仓库内,可用 Git 解析根目录:

```bash
cd "$(git rev-parse --show-toplevel)"
```

可按实际环境覆盖:

```bash
export WECHAT_DOCKER_IMAGE="${WECHAT_DOCKER_IMAGE:-wechat-xpra}"
export WECHAT_DOCKER_CONTAINER="${WECHAT_DOCKER_CONTAINER:-wechat-xpra}"
export WECHAT_DOCKER_PORT="${WECHAT_DOCKER_PORT:-14501}"
export WECHAT_DOCKER_DATA="${WECHAT_DOCKER_DATA:-wechat-xpra-data}"
export WECHAT_DEB="${WECHAT_DEB:-$HOME/Downloads/WeChatLinux_arm64.deb}"
```

## 4. macOS 前置检查

```bash
command -v docker
command -v brew
docker info >/dev/null
test -f "$WECHAT_DEB"
```

安装或修复 macOS xpra 客户端:

```bash
brew install --cask xpra
xattr -dr com.apple.quarantine /Applications/Xpra.app
test -x /Applications/Xpra.app/Contents/MacOS/Xpra
```

说明:

- 必须使用 `/Applications/Xpra.app/Contents/MacOS/Xpra`。
- 不要使用 `/opt/homebrew/bin/xpra` 作为 macOS 客户端入口。

## 5. 放置微信 deb

```bash
cp "$WECHAT_DEB" wechat-remote/docker/image/wechat.deb
test -f wechat-remote/docker/image/wechat.deb
```

确认该文件被忽略:

```bash
git check-ignore -v wechat-remote/docker/image/wechat.deb
```

如果没有被忽略,先修 `.gitignore`,不要继续构建或提交。

## 6. 构建镜像

可以让启动脚本自动构建;如果要单独构建,执行:

```bash
docker build -t "$WECHAT_DOCKER_IMAGE" wechat-remote/docker/image
```

验证:

```bash
docker image inspect "$WECHAT_DOCKER_IMAGE" >/dev/null
docker run --rm --entrypoint bash "$WECHAT_DOCKER_IMAGE" -lc 'test -x /opt/wechat/wechat && xpra --version'
```

注意:

- Dockerfile 会从 xpra.org 安装 xpra 6.x,不能退回 Ubuntu 默认 xpra 3.x。
- Dockerfile 会 patch xpra 的 `frame-extents` 和 `decorations` 行为,用于窗口拖动 workaround。
- 如果 Dockerfile 或 `entrypoint.sh` 有修改,必须重建镜像。

## 7. 启动容器并 attach

从仓库根目录执行:

```bash
./wechat-remote/docker/start.sh
```

脚本会做这些事:

1. 探测 macOS 主显示器 backing scale。
2. 镜像不存在时执行 `docker build`。
3. 容器不存在或未运行时执行 `docker run -d`。
4. 将容器端口 `14500` 绑定到 macOS 本机 `127.0.0.1:${WECHAT_DOCKER_PORT}`。
5. 用 macOS Xpra 客户端 attach 到 `tcp:localhost:${WECHAT_DOCKER_PORT}`。

期望结果:

- macOS 出现微信窗口。
- 容器后台保持运行。
- 微信登录态保存在 Docker named volume 中。

## 8. 验证命令

容器状态:

```bash
docker ps --filter "name=$WECHAT_DOCKER_CONTAINER"
docker exec "$WECHAT_DOCKER_CONTAINER" xpra list
docker exec "$WECHAT_DOCKER_CONTAINER" pgrep -af 'wechat|fcitx5|xpra|dbus-daemon'
```

端口绑定必须是本机:

```bash
docker port "$WECHAT_DOCKER_CONTAINER"
```

期望看到类似:

```text
14500/tcp -> 127.0.0.1:14501
```

输入法配置:

```bash
docker exec "$WECHAT_DOCKER_CONTAINER" bash -lc 'cat ~/.config/fcitx5/profile; cat ~/.config/fcitx5/config'
```

## 9. 重建与升级

如果只是断开 macOS 客户端,不要删除容器:

```bash
pkill -f "MacOS/Xpra attach"
```

如果修改了 Dockerfile、entrypoint、fcitx5 seed 或微信 deb,需要重建镜像和容器:

```bash
docker rm -f "$WECHAT_DOCKER_CONTAINER"
docker rmi "$WECHAT_DOCKER_IMAGE"
./wechat-remote/docker/start.sh
```

这不会删除 named volume,微信登录态通常保留。

如果明确要清空微信数据,才删除 volume:

```bash
docker rm -f "$WECHAT_DOCKER_CONTAINER"
docker volume rm "$WECHAT_DOCKER_DATA"
```

删除 volume 前必须让用户确认。

## 10. 多实例模板

Docker 方案天然支持多实例,但每个实例必须隔离 container、port 和 volume:

```bash
WECHAT_DOCKER_IMAGE=wechat-xpra \
WECHAT_DOCKER_CONTAINER=wechat-xpra-alt \
WECHAT_DOCKER_PORT=14502 \
WECHAT_DOCKER_DATA=wechat-xpra-data-alt \
./wechat-remote/docker/start.sh
```

不要让两个容器复用同一个 volume,否则会混用微信数据。

## 11. 常见失败点

| 现象 | 优先检查 |
|---|---|
| 构建时提示找不到 `wechat.deb` | 是否已复制到 `wechat-remote/docker/image/wechat.deb` |
| `install xpra-x11 to use seamless` | 镜像是否按当前 Dockerfile 重建,是否安装了 `xpra-x11` |
| attach `Connection failed` 或 `get_encryption` | 服务端是否带 `--tcp-auth=none`,客户端是否连到了正确端口 |
| `localhost:14500` 连到 VM | Docker 默认使用 `14501`;不要和 OrbStack VM xpra proxy 抢 `14500` |
| 中文不能输入 | 容器内 `dbus-daemon`、`fcitx5`、`wechat` 是否同在一个 session bus |
| 窗口拖不动 | 当前 workaround 依赖外层 macOS 标题栏;若不生效,确认镜像已重建并包含 xpra patch |
| 窗口模糊 | attach 是否使用 `--opengl=yes --desktop-scaling=1/S --encoding=rgb` |
| 换显示器后缩放不对 | `QT_SCALE_FACTOR` 在容器创建时固定;需要 `docker rm -f` 后重跑 |

## 12. 关键安全边界

- 本地 TCP 方案只适合本机连接。
- 如果要跨网络访问,不要直接暴露 `--tcp-auth=none` 的 xpra 端口。
- 跨网络应改成 SSH 传输、VPN 内访问,或增加明确的 xpra 认证和加密方案。
