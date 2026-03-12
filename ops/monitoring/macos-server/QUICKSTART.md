# QUICKSTART

目标：5 分钟内把当前这台 Mac 变成局域网中央监控节点。

## 最短路径

```bash
cd /path/to/your/dotfiles/ops/monitoring/macos-server
cp env.example .env
```

编辑 `.env`，至少改这两个值：

```bash
GRAFANA_ADMIN_PASSWORD=改成你自己的密码
BARK_DEVICE_KEY=你的 Bark key；没有就先留空
```

默认绑定策略是：

- `Grafana` 对局域网开放
- `Prometheus` 和 `Alertmanager` 只绑定本机
- 如果你只想本机访问 Grafana，把 `GRAFANA_BIND_ADDRESS=127.0.0.1`

安装模式默认是：

- Docker 可用时走 `docker`
- Docker 不可用时 fallback 到 `native`

如果你要强制指定，可以在 `.env` 里加：

```bash
INSTALL_MODE=docker
# 或
INSTALL_MODE=native
```

执行：

```bash
./install.sh
vi targets/node_exporters.yml
./start.sh
./status.sh
```

打开：

- Grafana: [http://127.0.0.1:3000](http://127.0.0.1:3000)
- Prometheus: [http://127.0.0.1:9090](http://127.0.0.1:9090)
- Alertmanager: [http://127.0.0.1:9093](http://127.0.0.1:9093)

快速验证：

```bash
curl http://127.0.0.1:9100/metrics
curl http://127.0.0.1:9090/api/v1/targets
curl http://127.0.0.1:3000/api/health
```

默认已经包含当前这台 Mac：

- Docker 模式下会自动变成 `host.docker.internal:9100`
- native 模式下会自动变成 `127.0.0.1:9100`

如果你要加其他局域网设备，只需要继续改 `targets/node_exporters.yml`。

如果你之前已经是 native 安装，后面想迁移到 Docker：

```bash
./migrate.sh
```

如果要停掉：

```bash
./stop.sh
```
