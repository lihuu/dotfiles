# WeChat Remote

这个目录收纳 macOS 上运行第二个微信客户端的远程窗口方案。核心思路是把 Linux
微信运行在隔离环境中,再通过 xpra rootless 窗口转发到 macOS 桌面。

## 方案入口

| 目录 | 定位 | 入口 |
|---|---|---|
| `vm/` | 当前体验基线。OrbStack Ubuntu VM 运行 Linux 微信,xpra 通过 SSH 转发窗口。窗口拖动、输入、显示效果已验证较好。 | `./wechat-remote/vm/start.sh` |
| `docker/` | 长期更理想的可重建形态。Docker 容器运行 Linux 微信,xpra 通过 TCP 转发窗口。当前可用,但窗口拖动依赖外层标题栏 workaround。 | `./wechat-remote/docker/start.sh` |

## 推荐使用

当前日常使用优先选 VM 方案:

```bash
./wechat-remote/vm/start.sh
```

如果需要双击启动,生成项目内 applet:

```bash
./wechat-remote/vm/install-app.sh
```

Docker 方案用于后续继续优化可重建、多实例和容器化交付:

```bash
cp ~/Downloads/WeChatLinux_arm64.deb wechat-remote/docker/image/wechat.deb
./wechat-remote/docker/start.sh
```

详细安装步骤、踩坑记录和后续方向分别见:

- `vm/README.md`
- `vm/AI-install-instructions.md`
- `docker/README.md`
- `docker/AI-install-instructions.md`
