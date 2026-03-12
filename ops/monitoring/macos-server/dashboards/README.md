# Dashboards

默认提供 `macos-self-monitoring.json`，`install.sh` / `start.sh` 会把它同步到 Grafana 的 dashboards 目录，并通过 provisioning 自动加载。

如果你要替换为自己导出的仪表盘：

1. 把新的 dashboard JSON 放到当前目录。
2. 保持 datasource UID 为 `prometheus-macos-self`，或者同时修改 provisioning 配置。
3. 重新执行 `./start.sh` 让 Grafana 读取最新文件。
