#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew
require_command docker

log_info "安装并保留宿主机 node_exporter"
brew install node_exporter

log_info "迁移前清理本机 Homebrew 版 Prometheus / Alertmanager / Grafana"
remove_legacy_brew_stack

log_info "渲染中央监控配置并同步 node_exporter 参数"
sync_node_exporter_config

log_info "预拉取 docker 镜像"
docker_compose pull

log_success "中央监控模式的安装准备完成"
log_info "下一步运行: ${SCRIPT_DIR}/start.sh"
