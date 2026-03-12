#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew
require_command curl
require_command docker

log_info "渲染配置并同步宿主机 node_exporter 参数"
sync_node_exporter_config

log_info "通过 brew services 启动宿主机 node_exporter"
brew services restart node_exporter

log_info "通过 docker compose 启动 Prometheus / Alertmanager / Grafana"
docker_compose up -d

log_success "启动命令已执行，开始输出状态"
"${SCRIPT_DIR}/status.sh"
