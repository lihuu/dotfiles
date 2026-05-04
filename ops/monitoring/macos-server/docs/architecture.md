# Mac mini LAN Central Monitoring

本方案将 Mac mini (192.168.2.8) 打造为局域网内的中央监控节点，汇聚多台主机的系统指标，统一告警通知。

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        macmini (192.168.2.8)                                  │
│                                                                              │
│  ┌─ Native / Homebrew brew services ────────────────────────────────────┐  │
│  │  node_exporter :9100 (0.0.0.0)                                         │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                    ▲                                         │
│                        host.docker.internal:9100                             │
│  ┌─ Docker (OrbStack) ───────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  ┌──────────────┐      ┌────────────────┐      ┌──────────────────┐   │  │
│  │  │  Prometheus  │─────►│  Alertmanager  │─────►│   bark-bridge    │   │  │
│  │  │  127.0.0.1  │      │   127.0.0.1    │      │  Python :18080   │   │  │
│  │  │    :9090    │      │     :9093      │      └────────┬─────────┘   │  │
│  │  └──────┬───────┘      └────────────────┘               │ HTTP push   │  │
│  │         │                                              │             │  │
│  │  ┌──────▼───────┐                             ┌────────▼─────────┐   │  │
│  │  │    Grafana   │                             │  Bark Server    │   │  │
│  │  │   0.0.0.0    │                             │  api.day.app    │   │  │
│  │  │    :3000    │                             │  → iPhone 推送  │   │  │
│  │  └──────────────┘                             └──────────────────┘   │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
        ▲                           ▲
        │                           │
   192.168.2.21:9100         192.168.2.7:9100
┌──────────────┐            ┌──────────────┐
│ubuntu-vm    │            │  macbook-pro │
│linux-server  │            │  macbook-pro │
└──────────────┘            └──────────────┘
```

---

## 部署模式

**当前模式：Docker（OrbStack）**

两种模式可切换，由 `.install-mode` 文件记录当前安装模式：

| 模式 | Prometheus/Alertmanager/Grafana | node_exporter | 配置渲染 |
|------|----------------------------------|---------------|---------|
| **Docker**（当前） | Docker 容器（OrbStack 提供运行时） | Homebrew native | `.rendered/docker/` |
| **Native** | Homebrew + `brew services` | Homebrew native | `.rendered/native/` |

切换方式：修改 `.env` 后运行 `./install.sh`，脚本自动检测 Docker 可用性。

---

## 各组件现状

| 组件 | 版本 | 运行方式 | 端口 | 绑定地址 | 容器名 | 运行时长 |
|------|------|---------|------|---------|--------|---------|
| **node_exporter** | latest | Homebrew native | 9100 | `0.0.0.0` | — | brew services |
| **Prometheus** | v3.10.0 | Docker | 9090 | `127.0.0.1` | `macos-monitoring-prometheus-1` | ~26h |
| **Alertmanager** | v0.31.1 | Docker | 9093 | `127.0.0.1` | `macos-monitoring-alertmanager-1` | ~47h |
| **Grafana** | 12.4.0 | Docker | 3000 | `0.0.0.0` | `macos-monitoring-grafana-1` | ~26h |
| **bark-bridge** | — | Docker (python:3.12-alpine) | 18080 | 容器内部 | `macos-monitoring-bark-bridge-1` | ~47h |

**端口规划**：

| 端口 | 用途 | 绑定地址 | 说明 |
|------|------|---------|------|
| 9090 | Prometheus Web UI、Targets、Rules、API | `127.0.0.1` | 仅本机访问 |
| 9093 | Alertmanager Web UI、Silences、Receivers、API | `127.0.0.1` | 仅本机访问 |
| 9100 | node_exporter 指标暴露 | `0.0.0.0` | 对局域网开放，兼容 Docker 抓取宿主机 |
| 3000 | Grafana Web UI 与 API | `0.0.0.0` | 对局域网开放 |

---

## 监控覆盖范围

Prometheus 通过 `file_sd_configs` 动态发现 node_exporter targets，配置文件为 `targets/node_exporters.yml`，渲染时自动替换本机 target 地址。

**当前监控目标**：

| 主机别名 | 地址 | 角色标签 | 说明 |
|---------|------|---------|------|
| macmini（本地） | `host.docker.internal:9100` | `central-monitor-host` | Docker 模式自动替换 |
| `li-ubuntu-vm-server` | `192.168.2.21:9100` | `linux-server` | 局域网 Linux 虚拟机 |
| `macbook-pro` | `192.168.2.7:9100` | `macbook-pro` | 局域网 MacBook |

**添加新主机**：编辑 `targets/node_exporters.yml`，取消注释示例配置或新增条目，重启 Prometheus 容器即可。

---

## 告警规则

| 告警名称 | 触发条件 | 持续时间 | 级别 | 说明 |
|---------|---------|---------|------|------|
| `HighCPUUsage` | 使用率 > 80% | 5 分钟 | ⚠️ warning | 基于 `node_cpu_seconds_total{mode="idle"}` 计算 |
| `HighMemoryUsage` | 使用率 > 80% | 5 分钟 | ⚠️ warning | 兼容 Linux (MemAvailable) 和 macOS (active+wired+compressed) |
| `DiskSpaceWarning` | 剩余空间 < 10% | 5 分钟 | ⚠️ warning | 兼容 APFS 多挂载点（`/`、`/System/Volumes/Data`） |
| `DiskSpaceCritical` | 剩余空间 < 5% | 2 分钟 | 🔴 critical | 同上，但阈值更严、响应更快 |
| `HostExporterDown` | target 抓取失败 | 2 分钟 | 🔴 critical | node_exporter 不可达 |
| `PrometheusDown` | prometheus target 不可用 | 2 分钟 | 🔴 critical | 规则引擎自身异常（无法监控进程完全退出的情况） |

---

## 告警链路

```
告警触发
    │
    ▼
┌─────────────────┐
│    Prometheus   │  规则引擎执行 alert.rules.yml
│   (容器 :9090)  │
└────────┬────────┘
         │ 推送告警
         ▼
┌─────────────────┐
│   Alertmanager  │  group_wait=30s, repeat_interval=4h
│  (容器 :9093)   │  按 alertname / instance / severity 分组
└────────┬────────┘
         │ webhook / telegram_configs
         ▼
    ┌────┴────┐
    │         │
┌───▼───┐ ┌───▼────────┐
│Bark   │ │ Telegram    │
│bridge │ │ (未配置)    │
│推送   │ │            │
└───┬───┘ └────────────┘
    │
    ▼
┌──────────────┐
│  Bark Server │
│ api.day.app  │
└──────┬───────┘
       │ 推送
       ▼
  iPhone 收到通知
```

**告警路由**（`alertmanager.yml`）：

- 默认 receiver 为 `ops-default`（当 `BARK_DEVICE_KEY` 或 Telegram token 至少一个已配置时）
- 未配置任何通知渠道时，receiver 为 `default-null`（空接收器，Alertmanager 仍可正常启动）
- `group_by` 维度：`alertname`、`instance`、`severity`
- `group_wait`：30 秒（新告警等待聚合时间）
- `repeat_interval`：4 小时（相同告警重复通知间隔）

---

## 通知渠道

### Bark 推送（已配置）

Alertmanager 发送 webhook 到 bark-bridge（Python 容器），bridge 转换格式后转发至 Bark Server，最终推送至 iPhone。

- **Bark Server**：`https://bark.silentstormic.top`（可配置 `BARK_SERVER_URL`）
- **设备 Key**：`htYXALRxH862TfL3NKLcyT`（可配置 `BARK_DEVICE_KEY`）
- **推送分组**：`Prometheus Alerts`（可配置 `BARK_GROUP`）
- **归档设置**：`BARK_IS_ARCHIVE=1`（消息归档）

### Telegram（未配置）

Alertmanager 原生支持 `telegram_configs`，需在 `.env` 中配置：

```
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
```

配置后 Alertmanager 会自动追加 receiver 并路由告警。

---

## 数据保留策略

三层磁盘控制，避免长期运行导致磁盘暴涨：

| 层级 | 策略 | 默认值 |
|------|------|--------|
| Prometheus retention time | 数据保留时长 | 7 天 |
| Prometheus retention size | 数据目录最大体积 | 8 GB |
| Docker 容器日志轮转 | 单个容器日志大小 × 文件数 | 10 MB × 3 |

---

## 已知约束

1. **Prometheus 自监控盲区**：进程完全崩溃时，`PrometheusDown` 规则本身也失效。需要外部 watcher 或第二套 Prometheus 补位。
2. **单点故障**：macmini 睡眠/重启会导致整个 LAN 监控中断。建议在系统设置中关闭自动睡眠。
3. **宿主机 node_exporter 由用户级 launchd 驱动**：无人登录时是否拉起取决于系统设置。如需更强可靠性，可考虑改为 root 级 LaunchDaemon。

---

## 快速运维

```bash
# 进入配置目录
cd /Users/lihu/git/dotfiles/ops/monitoring/macos-server

# 查看服务状态
./status.sh

# 重启整个栈（Docker 模式）
docker compose down && docker compose up -d

# 热重载 Prometheus 规则（无需重启容器）
curl -X POST http://127.0.0.1:9090/-/reload

# 查看 Prometheus 告警规则状态
curl -sS http://127.0.0.1:9090/api/v1/rules | python3 -m json.tool

# 查看 Alertmanager 状态
curl -sS http://127.0.0.1:9093/api/v2/status | python3 -m json.tool

# 查看 Prometheus 日志
docker logs macos-monitoring-prometheus-1 --tail 50 -f

# 查看告警容器日志
docker logs macos-monitoring-alertmanager-1 --tail 50 -f

# 重新渲染配置（修改 .env 或配置后必须执行）
./render-configs.sh
```

---

## 配置变更流程

任何配置变更（`.env`、`alert.rules.yml`、`targets/` 等）遵循以下流程：

```
1. 修改源配置文件
       ↓
2. ./render-configs.sh  →  渲染到 .rendered/docker/ 和 .rendered/native/
       ↓
3. curl -X POST http://127.0.0.1:9090/-/reload  →  Prometheus 热重载
       ↓
4. docker logs macos-monitoring-prometheus-1 --tail 10  →  确认无 ERROR
       ↓
5. curl -sS http://127.0.0.1:9090/api/v1/rules  →  确认规则 health=ok
```

---

*文档更新于 2026-04-17*
