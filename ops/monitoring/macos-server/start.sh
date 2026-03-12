#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
apply_defaults

require_command brew
require_command curl

log_info "渲染并同步配置"
sync_rendered_configs

log_info "通过 brew services 启动服务"
brew services restart prometheus
brew services restart node_exporter
brew services restart alertmanager
brew services restart grafana

log_success "启动命令已执行，开始输出状态"
"${SCRIPT_DIR}/status.sh"
