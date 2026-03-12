# macOS Server Self Monitoring

这套方案用于把当前这台 Mac 当作长期运行的服务器进行“本机自监控”。技术栈固定为 `node_exporter + Prometheus + Alertmanager + Grafana`，安装与服务管理基于 Homebrew，服务常驻依赖 `brew services` 调用的 `launchd`。

## 目录结构

```text
ops/monitoring/macos-server/
├── README.md
├── QUICKSTART.md
├── env.example
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
│   ├── prometheus.args
│   ├── node_exporter.args
│   ├── alertmanager.args
│   └── grafana.ini
├── grafana-provisioning/
│   ├── datasources/prometheus.yml
│   └── dashboards/dashboards.yml
└── dashboards/
    ├── README.md
    └── macos-self-monitoring.json
```

## 设计说明

- 仓库中的 `*.yml` / `templates/*` 是可版本管理的模板源文件。
- 实际运行配置由 `render-configs.sh` 渲染到本目录 `.rendered/`，再同步到 Homebrew 的 `etc` / `var` 目录。
- 默认全部监听在 `127.0.0.1`，更符合“本机自监控”的安全边界；如果你要远程访问，再改 `.env` 里的监听地址。
- `brew services` 会把服务注册到当前用户的 `launchd`，用户登录后自动拉起；如果你要系统级常驻，可改成 `sudo brew services ...`，但本方案默认不这么做。

## 端口规划

- `9090`: Prometheus Web UI、Targets、Rules、API
- `9100`: node_exporter 指标暴露端口
- `9093`: Alertmanager Web UI、Silences、Receivers、API
- `3000`: Grafana Web UI 与 API
- `9094`: Alertmanager cluster 端口，本方案通过 `--cluster.listen-address=` 显式关闭，避免单机部署多开额外端口

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

4. 安装软件并同步配置：

```bash
./install.sh
```

5. 启动服务：

```bash
./start.sh
```

6. 检查状态：

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

- 检查 Homebrew 是否存在
- 安装 `prometheus`、`node_exporter`、`grafana`
- 优先尝试 `brew install alertmanager`
- 如果当前 Homebrew 没有 core 版 `alertmanager`，自动 fallback 到 `prometheus/prometheus` tap
- 创建 Prometheus / Alertmanager / Grafana / textfile collector 目录
- 渲染模板配置并同步到 Homebrew 目录
- 覆盖已有配置前自动做时间戳备份

### 启动

```bash
./start.sh
```

脚本会重新渲染配置，然后执行：

```bash
brew services restart prometheus
brew services restart node_exporter
brew services restart alertmanager
brew services restart grafana
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

- `brew services list` 中相关服务的状态
- 关键端口监听情况
- 关键健康检查 URL 的 HTTP 状态码

## 关键配置说明

### Prometheus

- 主配置文件模板：`prometheus.yml`
- 实际部署位置：`${HOMEBREW_PREFIX}/etc/prometheus.yml`
- 告警规则文件：`${HOMEBREW_PREFIX}/etc/alert.rules.yml`
- 服务参数文件：`${HOMEBREW_PREFIX}/etc/prometheus.args`

抓取目标：

- Prometheus 自身
- 当前机器上的 `node_exporter`
- 当前机器上的 `alertmanager`

### Alert Rules

规则模板：`alert.rules.yml`

包含以下告警：

1. `HighCPUUsage`
   `expr` 含义：最近 5 分钟 CPU idle 比例的平均值，用 `100 - idle%` 算总使用率，持续超过阈值触发。

2. `HighMemoryUsage`
   `expr` 含义：macOS 没有 Linux 常见的 `MemAvailable`，因此使用 `free + inactive + purgeable + speculative` 近似“可回收内存”，再用 `1 - reclaimable/total` 估算内存压力。

3. `DiskSpaceLow`
   `expr` 含义：同时检查 `/` 和 `/System/Volumes/Data`，取最小剩余空间百分比。这样兼容新版本 macOS 的 APFS 系统卷 / 数据卷拆分。

4. `HostExporterDown`
   `expr` 含义：`up{job="node_exporter"} == 0`，表示 Prometheus 抓不到 node_exporter。

5. `PrometheusDown`
   `expr` 含义：`up{job="prometheus"} == 0`，表示 Prometheus 自抓取失败。
   注意：如果 Prometheus 进程完全退出，这条规则也无法执行，这是单机自监控的固有限制。

### Alertmanager

- 配置模板：`alertmanager.yml`
- 实际部署位置：`${HOMEBREW_PREFIX}/etc/alertmanager.yml`
- 服务参数文件：`${HOMEBREW_PREFIX}/etc/alertmanager.args`

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

- 配置模板：`templates/grafana.ini`
- 数据源 provisioning：`grafana-provisioning/datasources/prometheus.yml`
- dashboard provisioning：`grafana-provisioning/dashboards/dashboards.yml`
- 默认 dashboard：`dashboards/macos-self-monitoring.json`

Grafana 会自动：

- 添加 Prometheus 数据源
- 自动加载本目录提供的默认 dashboard

## 验证方式

### 验证 brew services

```bash
brew services list | egrep 'prometheus|node_exporter|alertmanager|grafana'
```

### 验证 node_exporter

```bash
curl http://127.0.0.1:9100/metrics
```

### 验证 Prometheus targets

```bash
curl http://127.0.0.1:9090/api/v1/targets
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

2. 更新 Homebrew 与软件：

```bash
brew update
brew upgrade prometheus node_exporter grafana
brew upgrade alertmanager || brew upgrade prometheus/prometheus/alertmanager
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

每次 `install.sh` / `start.sh` 同步配置时，都会把被覆盖的旧文件备份到：

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
brew uninstall grafana
brew uninstall prometheus
brew uninstall node_exporter
brew uninstall alertmanager || brew uninstall prometheus/prometheus/alertmanager
```

如需彻底清理数据目录，再手动删除：

- `${HOMEBREW_PREFIX}/var/prometheus`
- `${HOMEBREW_PREFIX}/var/lib/alertmanager`
- `${HOMEBREW_PREFIX}/var/lib/grafana`
- `${HOMEBREW_PREFIX}/var/log/grafana`
- `${HOMEBREW_PREFIX}/var/lib/node_exporter/textfile_collector`

这一步是删除历史数据的破坏性操作，所以没有放进脚本里。

## 常见问题排查

### 1. `brew services` 显示 started，但接口打不开

先查端口：

```bash
lsof -nP -iTCP:9090 -sTCP:LISTEN
lsof -nP -iTCP:9100 -sTCP:LISTEN
lsof -nP -iTCP:9093 -sTCP:LISTEN
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

再查服务状态：

```bash
brew services list | egrep 'prometheus|node_exporter|alertmanager|grafana'
```

### 2. Prometheus 抓不到 node_exporter

先看 exporter 自己是否可访问：

```bash
curl http://127.0.0.1:9100/metrics
```

再看 Prometheus targets：

```bash
curl http://127.0.0.1:9090/api/v1/targets
```

### 3. Grafana 页面打开了但没有数据

- 确认 `Prometheus` datasource 是否被自动 provisioning
- 确认 `http://127.0.0.1:9090/api/v1/query?query=up` 能返回数据
- 重新执行 `./start.sh`，确保 provisioning 文件已同步

### 4. Alertmanager 没有发 Telegram 告警

- 如果 `ALERT_WEBHOOK_URL` 为空，默认就是空接收器，不会出通知
- 如果你使用 webhook bridge，确认 bridge 本身能接收 Alertmanager 的 JSON
- 进入 Alertmanager UI 看 `Status`、`Receivers`、`Alerts`

### 5. PrometheusDown 规则为什么不一定可靠

因为这是“本机自监控”：

- Prometheus 全挂了，规则引擎也就没了
- Alertmanager 也收不到这台机新的本地告警
- 真正想监控 “Prometheus 自己是否彻底死掉”，需要另一台外部监控源或一个额外的 launchd 健康探针

## Apple Silicon 与 Intel Mac 的差异

- Apple Silicon 默认 Homebrew 前缀是 `/opt/homebrew`
- Intel Mac 默认 Homebrew 前缀是 `/usr/local`
- 脚本会优先读取 `brew --prefix`，找不到时才按架构做默认猜测
- 配置与服务管理逻辑相同，不依赖 Rosetta

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

## macOS 作为服务器做监控时的限制与注意事项

1. 单机自监控存在单点问题
   Prometheus、Alertmanager、Grafana 都跑在本机；机器睡眠、重启、用户会话异常、磁盘损坏时，这套系统也会一起受影响。

2. Prometheus 无法对“自己完全死亡”做可靠自告警
   这不是配置问题，而是架构约束。真正需要高可靠告警时，应增加外部 watcher 或第二套 Prometheus。

3. macOS 会睡眠
   如果这台 Mac 要长期跑服务，需要在系统设置里关闭自动睡眠，至少保证电源接入时不睡眠。

4. APFS 系统卷与数据卷是分离的
   新版 macOS 的 `/` 往往是只读系统卷，真正可写数据常在 `/System/Volumes/Data`。磁盘告警表达式已经兼容这一点，但排障时要理解这个差异。

5. node_exporter 的内存指标与 Linux 不同
   Linux 常用 `node_memory_MemAvailable_bytes`，macOS 通常没有，所以内存告警只能使用近似估算，而不是直接照搬 Linux 表达式。

6. `brew services` 默认是用户级 launchd
   它会在当前用户登录后自动启动，并不是传统 Linux `systemd` 的系统级守护语义。对“无人登录也必须拉起”的场景，要评估是否改为 root 级 `brew services` 或独立 LaunchDaemon。

7. 本方案默认监听在 `127.0.0.1`
   这样更安全，但也意味着你不能直接从其它机器访问。如果要远程访问，请修改 `.env` 的 `*_LISTEN_ADDRESS` 并同时考虑防火墙和认证。

## 推荐后续动作

1. 把 `env.example` 复制成 `.env`
2. 修改 `GRAFANA_ADMIN_PASSWORD`
3. 如果你已有 Telegram bridge，填 `ALERT_WEBHOOK_URL`
4. 运行 `./install.sh && ./start.sh`
5. 运行 `./status.sh`
