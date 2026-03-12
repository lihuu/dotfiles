# macOS LAN Central Monitoring

这套方案把当前这台 Mac 改造成局域网中的“中央监控节点”：

- 当前这台 Mac 继续通过 `node_exporter` 采集本机指标
- 局域网其他设备也可以各自部署 `node_exporter`
- 指标统一由这台 Mac 上的 `Prometheus` 汇总
- `Prometheus`、`Alertmanager`、`Grafana` 改为 `docker compose` 部署
- 宿主机上的旧 Homebrew 版 `Prometheus` / `Alertmanager` / `Grafana` 会被移除
- 通过 `retention time + retention size + docker log rotation` 控制磁盘增长

## 目录结构

```text
ops/monitoring/macos-server/
├── README.md
├── QUICKSTART.md
├── env.example
├── docker-compose.yml
├── install.sh
├── start.sh
├── stop.sh
├── status.sh
├── render-configs.sh
├── lib/common.sh
├── prometheus.yml
├── alert.rules.yml
├── alertmanager.yml
├── templates/
│   └── node_exporter.args
├── grafana-provisioning/
│   ├── datasources/prometheus.yml
│   └── dashboards/dashboards.yml
├── targets/
│   └── node_exporters.yml
└── dashboards/
    ├── README.md
    └── macos-self-monitoring.json
```

## 架构说明

- `node_exporter` 运行在宿主机，仍由 Homebrew + `brew services` 管理。
- `Prometheus`、`Alertmanager`、`Grafana` 运行在 Docker 容器中，由 `docker compose` 管理。
- 宿主机 `node_exporter` 默认监听 `0.0.0.0:9100`，让容器内 Prometheus 能通过 `host.docker.internal:9100` 抓到这台 Mac。
- 局域网其他设备只要暴露自己的 `node_exporter:9100`，就能被中央 Prometheus 统一抓取。
- 目标列表通过 `targets/node_exporters.yml` 管理，后续加机器只需要改这个文件并重启栈。
- 实际运行配置由 `render-configs.sh` 渲染到 `.rendered/`；这些运行产物和数据目录都不会进入 git。

## 端口规划

- `9090`: Prometheus Web UI、Targets、Rules、API
- `9100`: 宿主机 node_exporter 指标暴露端口
- `9093`: Alertmanager Web UI、Silences、Receivers、API
- `3000`: Grafana Web UI 与 API
- `9094`: Alertmanager cluster 端口，本方案显式关闭

## 首次部署步骤

1. 进入目录：

```bash
cd /path/to/your/dotfiles/ops/monitoring/macos-server
```

2. 准备环境变量：

```bash
cp env.example .env
```

3. 编辑 `.env`：

- 如果你只想本机验证，保留默认端口即可。
- 如果你已经有 Telegram webhook bridge，填 `ALERT_WEBHOOK_URL`。
- 如果没有 Telegram 配置，先留空，Alertmanager 会使用空接收器模板启动，不会因为未配置告警通道而失败。
- 强烈建议修改 `GRAFANA_ADMIN_PASSWORD`。

4. 安装宿主机 node_exporter，并清理旧的 Homebrew 三件套：

```bash
./install.sh
```

5. 按需修改局域网目标文件：

```bash
vi targets/node_exporters.yml
```

6. 启动中央监控栈：

```bash
./start.sh
```

7. 检查状态：

```bash
./status.sh
```

7. 打开页面：

- Grafana: [http://127.0.0.1:3000](http://127.0.0.1:3000)
- Prometheus: [http://127.0.0.1:9090](http://127.0.0.1:9090)
- Alertmanager: [http://127.0.0.1:9093](http://127.0.0.1:9093)

## 运行方式

### 安装

```bash
./install.sh
```

脚本会做这些事：

- 检查 Homebrew、Docker、Docker Compose
- 安装或保留宿主机 `node_exporter`
- 停止并卸载旧的 Homebrew 版 `prometheus`、`alertmanager`、`grafana`
- 删除上一步落地的旧配置文件和历史数据目录
- 渲染新的中央监控配置
- 同步宿主机 `node_exporter.args`
- 预拉取 Docker 镜像

### 启动

```bash
./start.sh
```

脚本会重新渲染配置，然后执行：

```bash
brew services restart node_exporter
docker compose up -d
```

### 停止

```bash
./stop.sh
```

### 查看状态

```bash
./status.sh
```

会输出：

- 宿主机 `node_exporter` 的 `brew services` 状态
- `docker compose ps`
- 关键端口监听情况
- 关键健康检查 URL 的 HTTP 状态码

## 关键配置说明

### Prometheus

- 主配置模板：`prometheus.yml`
- 告警规则模板：`alert.rules.yml`
- 目标清单：`targets/node_exporters.yml`

抓取目标：

- Prometheus 容器自身
- Alertmanager 容器自身
- 当前这台 Mac 的 `host.docker.internal:9100`
- `targets/node_exporters.yml` 中定义的其他局域网设备

### Alert Rules

规则模板：`alert.rules.yml`

包含以下告警：

1. `HighCPUUsage`
   `expr` 含义：最近 5 分钟 CPU idle 比例的平均值，用 `100 - idle%` 算总使用率，持续超过阈值触发。

2. `HighMemoryUsage`
   `expr` 含义：Linux 优先走 `MemAvailable / MemTotal`；macOS 走 `free + inactive + purgeable + speculative` 的 reclaimable 近似计算。

3. `DiskSpaceLow`
   `expr` 含义：同时检查 `/` 和 `/System/Volumes/Data`，取最小剩余空间百分比。这样兼容新版本 macOS 的 APFS 系统卷 / 数据卷拆分。

4. `HostExporterDown`
   `expr` 含义：`up{job="node_exporter"} == 0`，表示 Prometheus 抓不到 node_exporter。

5. `PrometheusDown`
   `expr` 含义：`up{job="prometheus"} == 0`，表示 Prometheus 自抓取失败。
   注意：如果 Prometheus 进程完全退出，这条规则也无法执行，这是单机自监控的固有限制。

### Alertmanager

- 配置模板：`alertmanager.yml`
- 实际运行配置：`.rendered/alertmanager.yml`

支持两种思路：

- 优先：`ALERT_WEBHOOK_URL`
  这要求你已经有一个把 Alertmanager webhook 转成 Telegram 消息的桥接服务。

- 备用：原生 `telegram_configs`
  方案目录里已经保留了 `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` 模板变量；如果 webhook 未配置，但这两个变量已填，脚本会自动切到原生 Telegram 发送。

默认行为：

- 如果配置了 `ALERT_WEBHOOK_URL`，`route.receiver` 会指向 `telegram-webhook`
- 如果 webhook 为空，但 `TELEGRAM_BOT_TOKEN` 和 `TELEGRAM_CHAT_ID` 都已配置，`route.receiver` 会指向 `telegram-direct`
- 如果以上都没配，`route.receiver` 会指向空接收器 `default-null`
- 这样能保证 Alertmanager 正常启动
- 但不会实际发出通知，直到你补上接收器配置

### Grafana

- 数据源 provisioning：`grafana-provisioning/datasources/prometheus.yml`
- dashboard provisioning：`grafana-provisioning/dashboards/dashboards.yml`
- 默认 dashboard：`dashboards/macos-self-monitoring.json`

Grafana 会自动：

- 添加 Prometheus 数据源
- 自动加载本目录提供的默认 dashboard

## 验证方式

### 验证宿主机 node_exporter

```bash
brew services list | egrep 'node_exporter'
```

### 验证 node_exporter

```bash
curl http://127.0.0.1:9100/metrics
```

### 验证 Prometheus targets

```bash
curl http://127.0.0.1:9090/api/v1/targets
```

### 验证 docker compose

```bash
docker compose ps
```

### 验证 Prometheus 健康状态

```bash
curl http://127.0.0.1:9090/-/healthy
curl http://127.0.0.1:9090/-/ready
```

### 验证 Alertmanager

```bash
curl http://127.0.0.1:9093/-/healthy
curl http://127.0.0.1:9093/api/v2/status
```

### 验证 Grafana

```bash
curl http://127.0.0.1:3000/api/health
```

### 打开 Grafana 页面

```bash
open http://127.0.0.1:3000
```

## 升级步骤

1. 停止服务：

```bash
./stop.sh
```

2. 更新宿主机 node_exporter 与镜像：

```bash
brew update
brew upgrade node_exporter
docker compose pull
```

3. 重新同步配置：

```bash
./install.sh
```

4. 重新启动：

```bash
./start.sh
```

5. 验证版本与健康状态：

```bash
./status.sh
```

## 回滚 / 卸载步骤

### 回滚配置

每次同步宿主机 `node_exporter.args` 时，旧文件都会备份到：

```text
ops/monitoring/macos-server/backups/<timestamp>/
```

回滚方法：

1. 先停止服务
2. 从最近一次备份目录把对应文件拷回 Homebrew 的 `etc` 目录
3. 再执行 `./start.sh`

### 卸载

```bash
./stop.sh
brew uninstall node_exporter
```

如需彻底清理数据目录，再手动删除：

- `ops/monitoring/macos-server/data/`
- `${HOMEBREW_PREFIX}/var/lib/node_exporter/textfile_collector`

这一步是删除历史数据的破坏性操作，所以没有放进脚本里。

## 常见问题排查

### 1. `docker compose` 容器没起来

先查 compose：

```bash
docker compose ps
docker compose logs --tail=100 prometheus alertmanager grafana
```

### 2. Prometheus 抓不到宿主机 node_exporter

- 确认宿主机 `node_exporter` 是否监听在 `0.0.0.0:9100`
- 确认 `curl http://127.0.0.1:9100/metrics` 可用
- 确认容器内目标文件包含 `host.docker.internal:9100`
- 确认 `curl http://127.0.0.1:9090/api/v1/targets` 中该目标是 `up`

### 3. Grafana 页面打开了但没有数据

- 确认 `Prometheus` datasource 已被 provisioning
- 确认 `docker compose ps` 中 `prometheus` 正常运行
- 确认 `curl http://127.0.0.1:9090/api/v1/query?query=up` 能返回数据

### 4. 添加了局域网目标但始终是 down

- 先在这台 Mac 上直接测试网络：

```bash
curl http://192.168.1.10:9100/metrics
```

- 确认对端机器的防火墙开放了 `9100`
- 确认对端 `node_exporter` 监听的不是 `127.0.0.1`

### 5. Alertmanager 没有发 Telegram 告警

- 如果 `ALERT_WEBHOOK_URL` 为空，默认就是空接收器，不会出通知
- 如果你使用 webhook bridge，确认 bridge 本身能接收 Alertmanager 的 JSON
- 进入 Alertmanager UI 看 `Status`、`Receivers`、`Alerts`

### 6. PrometheusDown 规则为什么不一定可靠

因为这是“本机自监控”：

- Prometheus 全挂了，规则引擎也就没了
- Alertmanager 也收不到这台机新的本地告警
- 真正想监控 “Prometheus 自己是否彻底死掉”，需要另一台外部监控源或一个额外的 launchd 健康探针

## Apple Silicon 与 Intel Mac 的差异

- Apple Silicon 默认 Homebrew 前缀是 `/opt/homebrew`
- Intel Mac 默认 Homebrew 前缀是 `/usr/local`
- 脚本会优先读取 `brew --prefix`，找不到时才按架构做默认猜测
- 配置与服务管理逻辑相同，不依赖 Rosetta
- Docker Desktop / OrbStack 的 `host.docker.internal` 都可作为容器访问宿主机的入口

## 如何扩展为 Slack / 企业微信 / 邮件告警

### Slack

- Alertmanager 原生支持 `slack_configs`
- 你可以在 `alertmanager.yml` 增加新的 receiver，并把 route 指过去
- 若已经有统一 webhook 中间层，也可继续沿用 `webhook_configs`

### 企业微信

- 常见做法是接企业微信机器人 webhook
- Alertmanager 原生没有专门的企业微信接收器时，可直接使用 `webhook_configs` 对接自建 bridge

### 邮件

- Alertmanager 原生支持 `email_configs`
- 你只需要补 SMTP 参数和 receiver 即可

建议做法：

- 保持 `default-null` 作为安全默认值
- 为不同通道单独定义 receiver
- 用 route 和 `matchers` 区分严重级别或业务类型

## 磁盘占用控制

为了避免这台 Mac 因为长期采集导致磁盘暴涨，本方案默认启用了三层控制：

1. Prometheus `retention time`
   默认 `7d`

2. Prometheus `retention size`
   默认 `8GB`

3. Docker 容器日志轮转
   每个容器 `max-size=10m`，`max-file=3`

如果你的局域网节点很多，再继续加机器前，建议先评估：

- `targets/node_exporters.yml` 中目标数量
- `scrape_interval`
- `retention size`
- `ops/monitoring/macos-server/data/prometheus` 的实际增长速度

## macOS 作为服务器做监控时的限制与注意事项

1. 这台 Mac 仍然是中央监控单点
   即使容器化了，机器睡眠、重启、磁盘损坏、Docker 异常，都会影响整个局域网监控。

2. Prometheus 无法对“自己完全死亡”做可靠自告警
   这不是配置问题，而是架构约束。真正需要高可靠告警时，应增加外部 watcher 或第二套 Prometheus。

3. macOS 会睡眠
   如果这台 Mac 要长期跑服务，需要在系统设置里关闭自动睡眠，至少保证电源接入时不睡眠。

4. APFS 系统卷与数据卷是分离的
   新版 macOS 的 `/` 往往是只读系统卷，真正可写数据常在 `/System/Volumes/Data`。磁盘告警表达式已经兼容这一点，但排障时要理解这个差异。

5. node_exporter 的内存指标在 macOS 和 Linux 上不同
   规则里已经兼容两种表达式，但排障时你仍然要知道不同平台暴露的指标不完全一致。

6. 宿主机 `node_exporter` 仍然由 `brew services` 驱动
   它默认是用户级 launchd。对“无人登录也必须拉起”的场景，要评估是否改为 root 级 `brew services` 或 LaunchDaemon。

7. 中央监控默认对局域网开放端口
   因为它的目标就是 LAN 中央节点。你需要自己决定是否配合 macOS 防火墙、内网 ACL、反向代理或认证做进一步收口。

## 推荐后续动作

1. 把 `env.example` 复制成 `.env`
2. 修改 `GRAFANA_ADMIN_PASSWORD`
3. 如果你已有 Telegram bridge，填 `ALERT_WEBHOOK_URL`
4. 运行 `./install.sh && ./start.sh`
5. 运行 `./status.sh`
