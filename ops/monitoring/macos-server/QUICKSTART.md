# QUICKSTART

目标：5 分钟内把当前这台 Mac 的本机监控跑起来。

## 最短路径

```bash
cd /path/to/your/dotfiles/ops/monitoring/macos-server
cp env.example .env
```

编辑 `.env`，至少改这两个值：

```bash
GRAFANA_ADMIN_PASSWORD=改成你自己的密码
ALERT_WEBHOOK_URL=你的 Telegram webhook bridge；没有就先留空
```

执行：

```bash
./install.sh
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

如果 `ALERT_WEBHOOK_URL` 没填：

- 监控和仪表盘仍然可用
- 告警规则也会生效
- 但 Alertmanager 不会真正发送通知

如果要停掉：

```bash
./stop.sh
```
